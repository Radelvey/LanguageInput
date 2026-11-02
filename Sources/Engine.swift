import Foundation

/// 一个候选。
struct Candidate {
    enum Kind {
        case sentence      // 整句解码结果
        case word          // 词库中的词/字
        case abbreviation  // 简拼命中
        case raw           // 兜底：原样字母
    }

    var text: String
    /// 消耗的拼音字母数（不是原始按键数）。
    var consumed: Int
    var kind: Kind
    var gloss: String?
}

struct DecodeResult {
    var candidates: [Candidate] = []
    /// 最佳切分出的音节，用于预编辑区显示（例如 ["ni", "hao"]）。
    var syllables: [String] = []

    static let empty = DecodeResult()
}

/// 拼音引擎：基于一元模型的维特比整句解码 + 词库精确匹配 + 简拼。
/// 词频来自词库；用户确认过的词通过 UserModel 获得加分（本机习惯学习）。
final class Engine {
    static let shared = Engine()

    struct Options {
        var abbreviation: Bool
        var maxCandidates: Int = 80
    }

    private let lex = Lexicon.shared
    private let user = UserModel.shared

    private init() {}

    private struct Segment {
        let start: Int
        let end: Int
        let entry: LexEntry?   // nil = 未识别的原样字母
    }

    // MARK: - 对外接口

    func decode(_ conv: InputConversion, options: Options) -> DecodeResult {
        var letters = conv.letters
        let n = letters.count
        guard n > 0 else { return .empty }

        var path = viterbi(letters, forced: conv.forced)

        // 解码失败（含未识别字母）时，尝试修正常见的 gn ↔ ng 笔误
        if path.contains(where: { $0.entry == nil }),
           let fixed = trySwapFix(letters, forced: conv.forced) {
            letters = fixed
            path = viterbi(letters, forced: conv.forced)
        }

        let syllables = displaySyllables(letters, path: path)
        var out: [Candidate] = []
        var seen = Set<String>()

        func add(_ c: Candidate) {
            let key = "\(c.text)|\(c.consumed)"
            if seen.insert(key).inserted { out.append(c) }
        }

        // 1. 整句候选（≥2 个词、且全部被识别）
        if path.count >= 2, !path.contains(where: { $0.entry == nil }) {
            let text = path.compactMap { $0.entry?.word }.joined()
            add(Candidate(text: text, consumed: n, kind: .sentence))
        }

        // 2. 整个缓冲区作为一个词的候选
        for e in rankedEntries(letters, forced: conv.forced, start: 0, end: n, limit: 40) {
            add(Candidate(text: e.word, consumed: n, kind: .word))
        }

        // 3. 简拼
        if options.abbreviation, n >= 2, n <= 8,
           let list = lex.initials[String(decoding: letters, as: UTF8.self)] {
            for (e, _) in scored(list, limit: 10) {
                add(Candidate(text: e.word, consumed: n, kind: .abbreviation))
            }
        }

        // 4. 前缀候选：只在最佳路径的词边界/音节边界处截断，由长到短
        var ends = Set<Int>()
        for seg in path where seg.end < n { ends.insert(seg.end) }
        var acc = 0
        for s in syllables.dropLast() {
            acc += s.utf8.count
            if acc < n { ends.insert(acc) }
        }
        for j in ends.sorted(by: >) {
            for e in rankedEntries(letters, forced: conv.forced, start: 0, end: j, limit: 5) {
                add(Candidate(text: e.word, consumed: j, kind: .word))
            }
        }

        if out.isEmpty {
            add(Candidate(text: String(decoding: letters, as: UTF8.self), consumed: n, kind: .raw))
        }
        if out.count > options.maxCandidates {
            out.removeSubrange(options.maxCandidates...)
        }
        return DecodeResult(candidates: out, syllables: syllables)
    }

    // MARK: - 维特比

    private func viterbi(_ letters: [UInt8], forced: [Int]) -> [Segment] {
        let n = letters.count
        let negInf = -Float.infinity
        var best = [Float](repeating: negInf, count: n + 1)
        var backStart = [Int](repeating: -1, count: n + 1)
        var backEntry = [LexEntry?](repeating: nil, count: n + 1)
        best[0] = 0

        for i in 0..<n {
            guard best[i] > negInf else { continue }
            let maxLen = min(lex.maxKeyLength, n - i)
            var len = 1
            while len <= maxLen {
                let j = i + len
                let key = String(decoding: letters[i..<j], as: UTF8.self)
                if let list = lex.table[key],
                   let (entry, score) = bestCompatible(list, forced: forced, start: i, end: j) {
                    let total = best[i] + score
                    if total > best[j] {
                        best[j] = total
                        backStart[j] = i
                        backEntry[j] = entry
                    }
                }
                len += 1
            }
            // 兜底边：单个未识别字母，重罚
            let rawScore = best[i] - 25
            if rawScore > best[i + 1] {
                best[i + 1] = rawScore
                backStart[i + 1] = i
                backEntry[i + 1] = nil
            }
        }

        var segments: [Segment] = []
        var pos = n
        while pos > 0 {
            let start = backStart[pos]
            guard start >= 0 else { break }
            segments.append(Segment(start: start, end: pos, entry: backEntry[pos]))
            pos = start
        }
        segments.reverse()
        return segments
    }

    private func trySwapFix(_ letters: [UInt8], forced: [Int]) -> [UInt8]? {
        guard letters.count >= 2 else { return nil }
        for k in 0..<(letters.count - 1) where letters[k] == 103 && letters[k + 1] == 110 { // "gn"
            var copy = letters
            copy.swapAt(k, k + 1)
            if !viterbi(copy, forced: forced).contains(where: { $0.entry == nil }) {
                return copy
            }
        }
        return nil
    }

    // MARK: - 辅助

    @inline(__always)
    private func compatible(_ e: LexEntry, forced: [Int], start: Int, end: Int) -> Bool {
        for p in forced {
            if p <= start { continue }
            if p >= end { break }
            if e.mask & ((1 as UInt64) << UInt64(p - start)) == 0 { return false }
        }
        return true
    }

    /// 在已按词频降序的列表里取前若干个兼容条目，返回加上用户习惯加分后得分最高的。
    private func bestCompatible(_ list: [LexEntry], forced: [Int], start: Int, end: Int) -> (LexEntry, Float)? {
        var best: (LexEntry, Float)?
        var seen = 0
        for e in list {
            guard compatible(e, forced: forced, start: start, end: end) else { continue }
            let s = e.logp + user.boost(for: e.word)
            if best == nil || s > best!.1 { best = (e, s) }
            seen += 1
            if seen >= 12 { break }
        }
        return best
    }

    private func scored(_ list: [LexEntry], limit: Int) -> [(LexEntry, Float)] {
        var items = list.prefix(80).map { ($0, $0.logp + user.boost(for: $0.word)) }
        items.sort { $0.1 > $1.1 }
        return Array(items.prefix(limit))
    }

    private func rankedEntries(_ letters: [UInt8], forced: [Int], start: Int, end: Int, limit: Int) -> [LexEntry] {
        let key = String(decoding: letters[start..<end], as: UTF8.self)
        guard let list = lex.table[key] else { return [] }
        var items: [(LexEntry, Float)] = []
        for e in list where compatible(e, forced: forced, start: start, end: end) {
            items.append((e, e.logp + user.boost(for: e.word)))
            if items.count >= 120 { break }
        }
        items.sort { $0.1 > $1.1 }
        return items.prefix(limit).map { $0.0 }
    }

    /// 由最佳路径还原音节，供预编辑区显示。相邻的未识别字母合并成一段。
    private func displaySyllables(_ letters: [UInt8], path: [Segment]) -> [String] {
        var result: [String] = []
        var rawRun = ""
        func flushRaw() {
            if !rawRun.isEmpty { result.append(rawRun); rawRun = "" }
        }
        for seg in path {
            if let e = seg.entry {
                flushRaw()
                let length = seg.end - seg.start
                var from = seg.start
                if length > 1 {
                    for k in 1..<length where e.mask & ((1 as UInt64) << UInt64(k)) != 0 {
                        result.append(String(decoding: letters[from..<(seg.start + k)], as: UTF8.self))
                        from = seg.start + k
                    }
                }
                result.append(String(decoding: letters[from..<seg.end], as: UTF8.self))
            } else {
                rawRun += String(decoding: letters[seg.start..<seg.end], as: UTF8.self)
            }
        }
        flushRaw()
        return result
    }
}
