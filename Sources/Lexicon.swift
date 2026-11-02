import Foundation

/// 词库条目。`mask` 的第 k 位为 1 表示该词在第 k 个字母后有音节边界（k ≥ 1）。
struct LexEntry {
    let word: String
    let logp: Float
    let mask: UInt64
    let syllableCount: Int
}

/// 拼音词库。首次访问时同步加载（static let 保证线程安全），
/// AppDelegate 会在启动时于后台线程预热，所以首次按键通常不会等待。
final class Lexicon {
    static let shared = Lexicon()

    /// 键：音节连写（如 "nihao"）。
    private(set) var table: [String: [LexEntry]] = [:]
    /// 键：各音节首字母（如 "nh"），仅收录 2 个及以上音节的词，用于简拼。
    private(set) var initials: [String: [LexEntry]] = [:]
    private(set) var syllables: Set<String> = []
    private(set) var maxKeyLength = 1
    private(set) var entryCount = 0

    private struct Row {
        let key: String
        let mask: UInt64
        let word: String
        let freq: Double
        let syllableCount: Int
        let initials: String
    }

    private init() {
        load()
    }

    func isValidSyllable(_ s: String) -> Bool {
        syllables.contains(s)
    }

    // MARK: - 加载

    /// 主词库：用户目录里的 lexicon.tsv 优先于随包附带的；另可放 lexicon.user.tsv 追加自定义词。
    private static func sourceURLs() -> [URL] {
        var urls: [URL] = []
        if Storage.exists("lexicon.tsv") {
            urls.append(Storage.url("lexicon.tsv"))
        } else if let bundled = Bundle.main.url(forResource: "lexicon", withExtension: "tsv") {
            urls.append(bundled)
        }
        if Storage.exists("lexicon.user.tsv") {
            urls.append(Storage.url("lexicon.user.tsv"))
        }
        return urls
    }

    private func load() {
        var rows: [Row] = []
        rows.reserveCapacity(150_000)
        var total = 0.0

        for url in Lexicon.sourceURLs() {
            guard let data = try? Data(contentsOf: url) else { continue }
            let text = String(decoding: data, as: UTF8.self)
            for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
                if line.hasPrefix("#") { continue }
                let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
                guard fields.count >= 3 else { continue }
                let parts = fields[0].split(separator: " ", omittingEmptySubsequences: true)
                guard !parts.isEmpty else { continue }
                let word = String(fields[1])
                guard !word.isEmpty else { continue }
                let freq = Double(fields[2].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1

                var mask: UInt64 = 0
                var acc = 0
                var valid = true
                var initialChars = ""
                for (index, part) in parts.enumerated() {
                    for byte in part.utf8 where byte < 97 || byte > 122 { valid = false }
                    acc += part.utf8.count
                    if index < parts.count - 1 {
                        guard acc < 63 else { valid = false; break }
                        mask |= (1 as UInt64) << UInt64(acc)
                    }
                    if let first = part.first { initialChars.append(first) }
                }
                guard valid, acc < 63 else { continue }

                let key = parts.joined()
                rows.append(Row(key: key, mask: mask, word: word, freq: max(freq, 1),
                                syllableCount: parts.count, initials: initialChars))
                total += max(freq, 1)
                if key.utf8.count > maxKeyLength { maxKeyLength = key.utf8.count }
            }
        }

        guard total > 0 else { return }
        let logTotal = log(total)
        table.reserveCapacity(rows.count)
        for row in rows {
            let entry = LexEntry(word: row.word,
                                 logp: Float(log(row.freq) - logTotal),
                                 mask: row.mask,
                                 syllableCount: row.syllableCount)
            table[row.key, default: []].append(entry)
            if row.syllableCount == 1 {
                syllables.insert(row.key)
            } else {
                initials[row.initials, default: []].append(entry)
            }
        }
        for key in table.keys {
            table[key]?.sort { $0.logp > $1.logp }
        }
        for key in initials.keys {
            initials[key]?.sort { $0.logp > $1.logp }
        }
        entryCount = rows.count
    }
}
