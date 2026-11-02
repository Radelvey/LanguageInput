#!/usr/bin/env python3
"""生成完整拼音词库与英文译词（仅依赖 Python 标准库，需要联网）。

数据来源（均为公开数据，请遵守各自许可）：
  * jieba 词频表 dict.txt        (MIT)           https://github.com/fxsjy/jieba
  * CC-CEDICT 汉英词典           (CC BY-SA 4.0)  https://www.mdbg.net/chinese/dictionary?page=cedict

输出（默认写到 ./data/）：
  lexicon.full.tsv   pinyin<TAB>word<TAB>freq
  gloss_en.full.tsv  word<TAB>english gloss

用法：
  python3 tools/build_lexicon.py                    # 自动下载
  python3 tools/build_lexicon.py --jieba dict.txt --cedict cedict_ts.u8   # 使用本地文件
  python3 tools/build_lexicon.py --max-words 120000
"""
import argparse, collections, io, os, re, sys, urllib.request, zipfile

JIEBA_URL = "https://raw.githubusercontent.com/fxsjy/jieba/master/jieba/dict.txt"
CEDICT_URL = "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip"
CJK = re.compile(r"^[一-鿿]+$")
ENTRY = re.compile(r"^(\S+) (\S+) \[([^\]]+)\] /(.+)/\s*$")


def fetch(url, timeout=60):
    print("downloading", url, file=sys.stderr)
    req = urllib.request.Request(url, headers={"User-Agent": "LanguageInput-lexicon-builder/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def norm_syllable(s):
    """CC-CEDICT 拼音音节 -> 无声调小写、ü 写作 v。返回 None 表示不可用。"""
    s = s.lower().replace("u:", "v").replace("ü", "v")
    s = re.sub(r"[1-5]$", "", s)
    return s if re.fullmatch(r"[a-z]{1,6}", s) else None


def parse_cedict(text):
    """返回 (readings, glosses)。readings[word] = [(syllables_tuple, 条目序号)]；glosses[word] = [释义...]"""
    readings = collections.defaultdict(list)
    glosses = collections.defaultdict(list)
    for n, line in enumerate(text.splitlines()):
        if not line or line.startswith("#"):
            continue
        m = ENTRY.match(line)
        if not m:
            continue
        _trad, simp, py, defs = m.groups()
        if not CJK.match(simp):
            continue
        syl = [norm_syllable(x) for x in py.split()]
        if any(x is None for x in syl) or len(syl) != len(simp):
            continue
        readings[simp].append((tuple(syl), n))
        glosses[simp].append(defs)
    return readings, glosses


BAD_SENSE = re.compile(r"^(CL:|see |see also|variant of|old variant|erhua variant|abbr\. for|surname|used in|"
                       r"also pr\.|Taiwan pr\.|\(Tw\)|archaic|classifier)", re.I)


def compact_gloss(defs_list):
    """从 CEDICT 释义里挑出简短、适合放在候选词旁边的译词。"""
    senses = []
    for defs in defs_list:
        for s in defs.split("/"):
            s = re.sub(r"\([^)]*\)", "", s).strip(" ;,")
            if not s or BAD_SENSE.match(s) or len(s) > 40:
                continue
            if re.search(r"[一-鿿]", s):
                continue
            senses.append(s)
    if not senses:
        return None
    pick = []
    total = 0
    for s in senses:
        if s in pick:
            continue
        if total + len(s) > 28 and pick:
            break
        pick.append(s)
        total += len(s) + 2
        if len(pick) == 2:
            break
    return "; ".join(pick)


def build(jieba_text, cedict_text, max_words):
    readings, glosses = parse_cedict(cedict_text)

    # 单字读音统计：用多字词中每个字对应的读音投票，决定主读音
    char_votes = collections.defaultdict(collections.Counter)
    for word, lst in readings.items():
        if len(word) < 2:
            continue
        for syl, _ in lst:
            for ch, s in zip(word, syl):
                char_votes[ch][s] += 1
    char_readings = collections.defaultdict(list)
    for word, lst in readings.items():
        if len(word) == 1:
            for syl, _ in lst:
                if syl[0] not in char_readings[word]:
                    char_readings[word].append(syl[0])
    for ch, c in char_votes.items():
        for s in c:
            if s not in char_readings[ch]:
                char_readings[ch].append(s)

    def ranked_readings(ch):
        votes = char_votes.get(ch, collections.Counter())
        rs = char_readings.get(ch, [])
        return sorted(rs, key=lambda s: -votes.get(s, 0))

    words = []
    for line in jieba_text.splitlines():
        parts = line.split()
        if len(parts) < 2 or not CJK.match(parts[0]):
            continue
        try:
            freq = int(parts[1])
        except ValueError:
            continue
        words.append((parts[0], freq))
    words.sort(key=lambda x: -x[1])
    words = words[:max_words]
    jieba_freq = dict(words)

    out = []
    seen = set()

    def emit(py, w, f):
        key = (py, w)
        if key in seen:
            return
        seen.add(key)
        out.append((py, w, max(1, int(f))))

    for w, f in words:
        if len(w) == 1:
            rs = ranked_readings(w)
            if not rs:
                continue
            for rank, s in enumerate(rs):
                emit(s, w, f / (1 + 2 * rank))
            continue
        lst = readings.get(w)
        if lst:
            # CEDICT 给出的读音（可能多个）
            for rank, (syl, _) in enumerate(lst[:3]):
                emit(" ".join(syl), w, f / (1 + rank))
        else:
            # 退而求其次：逐字取主读音
            syl = []
            for ch in w:
                rs = ranked_readings(ch)
                if not rs:
                    syl = None
                    break
                syl.append(rs[0])
            if syl:
                emit(" ".join(syl), w, f)

    # 补齐：jieba 里没有的单字，但 CEDICT 里有的（保证任何字都能打出来）
    for ch, rs in char_readings.items():
        if len(ch) == 1 and ch not in jieba_freq:
            for rank, s in enumerate(ranked_readings(ch)):
                emit(s, ch, 1 / (1 + rank) + 1)

    # 为 lve / nve 增加 lue / nue 别名（用户常按 lue / nue 输入）
    alias = []
    for py, w, f in out:
        if "lve" in py or "nve" in py:
            alias.append((py.replace("lve", "lue").replace("nve", "nue"), w, f))
    out.extend(alias)

    gl = {}
    wanted = {w for _, w, _ in out}
    for w in wanted:
        if w in glosses:
            g = compact_gloss(glosses[w])
            if g:
                gl[w] = g
    return out, gl


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--jieba")
    ap.add_argument("--cedict")
    ap.add_argument("--out", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data"))
    ap.add_argument("--max-words", type=int, default=100000)
    a = ap.parse_args()

    if a.jieba:
        jieba_text = open(a.jieba, encoding="utf-8").read()
    else:
        jieba_text = fetch(JIEBA_URL).decode("utf-8")
    if a.cedict:
        raw = open(a.cedict, "rb").read()
        cedict_text = raw.decode("utf-8")
    else:
        z = zipfile.ZipFile(io.BytesIO(fetch(CEDICT_URL)))
        name = [n for n in z.namelist() if n.endswith(".u8") or n.endswith(".txt")][0]
        cedict_text = z.read(name).decode("utf-8")

    rows, gl = build(jieba_text, cedict_text, a.max_words)
    os.makedirs(a.out, exist_ok=True)
    with open(os.path.join(a.out, "lexicon.full.tsv"), "w", encoding="utf-8") as f:
        f.write("# pinyin\tword\tfreq   (generated by tools/build_lexicon.py from jieba + CC-CEDICT)\n")
        for py, w, fr in rows:
            f.write(f"{py}\t{w}\t{fr}\n")
    with open(os.path.join(a.out, "gloss_en.full.tsv"), "w", encoding="utf-8") as f:
        f.write("# word\tgloss   (derived from CC-CEDICT, CC BY-SA 4.0)\n")
        for w, g in sorted(gl.items()):
            f.write(f"{w}\t{g}\n")
    print(f"lexicon rows: {len(rows)}; glosses: {len(gl)}; written to {os.path.abspath(a.out)}")


if __name__ == "__main__":
    main()
