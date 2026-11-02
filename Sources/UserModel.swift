import Foundation

/// 本机输入习惯：记录用户确认过的词，用对数加分影响排序。数据只存在本机。
final class UserModel {
    static let shared = UserModel()

    private struct Store: Codable {
        var counts: [String: Int] = [:]
    }

    private static let fileName = "user-model.json"

    private var counts: [String: Int]
    private var saveWork: DispatchWorkItem?

    private init() {
        counts = Storage.load(Store.self, from: UserModel.fileName)?.counts ?? [:]
    }

    func boost(for word: String) -> Float {
        guard let c = counts[word], c > 0 else { return 0 }
        return min(Float(log(1 + Double(c))) * 0.9, 5)
    }

    func learn(_ word: String) {
        guard !word.isEmpty else { return }
        counts[word, default: 0] += 1
        scheduleSave()
    }

    func reset() {
        counts.removeAll()
        saveWork?.cancel()
        Storage.remove(UserModel.fileName)
    }

    func flush() {
        saveWork?.cancel()
        Storage.save(Store(counts: counts), to: UserModel.fileName)
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.flush() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }
}
