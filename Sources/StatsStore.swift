import Foundation
import Combine

struct VocabEntry: Codable, Identifiable, Hashable {
    var word: String
    var gloss: String
    var language: String
    var count: Int
    var firstSeen: Date
    var lastSeen: Date
    var known: Bool

    var id: String { language + "|" + word }
}

struct DayCount: Identifiable {
    let date: Date
    let count: Int
    var id: Date { date }
}

struct StatsData: Codable {
    /// "yyyy-MM-dd" → 当天提交的汉字数。
    var daily: [String: Int] = [:]
    var lifetime: Int = 0
    /// VocabEntry.id → 记录。
    var vocab: [String: VocabEntry] = [:]
}

/// 本地统计与词汇本。所有数据只写入本机，不会上传。
final class StatsStore: ObservableObject {
    static let shared = StatsStore()

    @Published private(set) var data: StatsData

    private static let fileName = "stats.json"
    private var saveWork: DispatchWorkItem?

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private init() {
        data = Storage.load(StatsData.self, from: StatsStore.fileName) ?? StatsData()
    }

    // MARK: - 记录

    static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        (0x4E00...0x9FFF).contains(scalar.value) || (0x3400...0x4DBF).contains(scalar.value)
    }

    func recordInput(text: String) {
        let count = text.unicodeScalars.filter(StatsStore.isCJK).count
        guard count > 0 else { return }
        onMain {
            let key = StatsStore.dayFormatter.string(from: Date())
            self.data.daily[key, default: 0] += count
            self.data.lifetime += count
            self.scheduleSave()
        }
    }

    func recordWord(_ word: String, gloss: String, language: LearningLanguage) {
        guard !word.isEmpty, !gloss.isEmpty else { return }
        onMain {
            let id = language.rawValue + "|" + word
            let now = Date()
            if var entry = self.data.vocab[id] {
                entry.count += 1
                entry.lastSeen = now
                entry.gloss = gloss
                self.data.vocab[id] = entry
            } else {
                self.data.vocab[id] = VocabEntry(word: word, gloss: gloss, language: language.rawValue,
                                                 count: 1, firstSeen: now, lastSeen: now, known: false)
            }
            self.scheduleSave()
        }
    }

    // MARK: - 查询

    var today: Int { data.daily[StatsStore.dayFormatter.string(from: Date())] ?? 0 }

    var lastSevenDaysTotal: Int { lastSevenDays().reduce(0) { $0 + $1.count } }

    /// 最近 7 天（含今天），按日期升序。
    func lastSevenDays() -> [DayCount] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let key = StatsStore.dayFormatter.string(from: day)
            return DayCount(date: day, count: data.daily[key] ?? 0)
        }
    }

    func vocabulary(language: LearningLanguage) -> [VocabEntry] {
        data.vocab.values.filter { $0.language == language.rawValue }
    }

    // MARK: - 编辑

    func setKnown(_ id: String, known: Bool) {
        onMain {
            self.data.vocab[id]?.known = known
            self.scheduleSave()
        }
    }

    func deleteVocab(_ id: String) {
        onMain {
            self.data.vocab.removeValue(forKey: id)
            self.scheduleSave()
        }
    }

    func clearVocabulary() {
        onMain {
            self.data.vocab.removeAll()
            self.scheduleSave()
        }
    }

    func clearAll() {
        onMain {
            self.data = StatsData()
            self.scheduleSave()
        }
    }

    /// 导出为 CSV（可导入 Anki 等）：word,gloss,count,firstSeen,known
    func exportCSV(language: LearningLanguage) -> String {
        let iso = ISO8601DateFormatter()
        func esc(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        var lines = ["word,gloss,count,first_seen,known"]
        for e in vocabulary(language: language).sorted(by: { $0.firstSeen < $1.firstSeen }) {
            lines.append([esc(e.word), esc(e.gloss), String(e.count), iso.string(from: e.firstSeen),
                          e.known ? "1" : "0"].joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - 持久化

    func flush() {
        saveWork?.cancel()
        Storage.save(data, to: StatsStore.fileName)
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.flush() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    private func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread { block() } else { DispatchQueue.main.async(execute: block) }
    }
}

/// 可选的输入记录（默认关闭）。与统计分开存放，可单独关闭或清除。
enum InputLog {
    private static let fileName = "input-log.jsonl"

    static func append(_ text: String) {
        guard Prefs.inputLogEnabled, !text.isEmpty else { return }
        let entry: [String: String] = ["t": ISO8601DateFormatter().string(from: Date()), "text": text]
        guard let data = try? JSONSerialization.data(withJSONObject: entry, options: []),
              let line = String(data: data, encoding: .utf8) else { return }
        Storage.appendLine(line, to: fileName)
    }

    static func clear() {
        Storage.remove(fileName)
    }
}
