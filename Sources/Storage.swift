import Foundation
import Security

/// 本地存储：所有数据只保存在 ~/Library/Application Support/LanguageInput/。
enum Storage {
    static let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("LanguageInput", isDirectory: true)
        // 旧版本（项目曾名为 QingjianSwift）的数据目录：首次运行时迁移过来
        let legacy = base.appendingPathComponent("QingjianSwift", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path),
           FileManager.default.fileExists(atPath: legacy.path) {
            try? FileManager.default.moveItem(at: legacy, to: dir)
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static let ioQueue = DispatchQueue(label: "LanguageInput.io", qos: .utility)

    static func url(_ name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    static func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: url(name).path)
    }

    static func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        guard let data = try? Data(contentsOf: url(name)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }

    /// 异步原子写入（编码在调用线程完成，写盘在后台队列）。
    static func save<T: Encodable>(_ value: T, to name: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value) else { return }
        let target = url(name)
        ioQueue.async {
            try? data.write(to: target, options: .atomic)
        }
    }

    static func appendLine(_ line: String, to name: String) {
        let target = url(name)
        let data = Data((line + "\n").utf8)
        ioQueue.async {
            if let handle = try? FileHandle(forWritingTo: target) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: target, options: .atomic)
            }
        }
    }

    static func remove(_ name: String) {
        let target = url(name)
        ioQueue.async {
            try? FileManager.default.removeItem(at: target)
        }
    }

    /// 等待所有已排队的写入完成（退出前调用）。
    static func drain() {
        ioQueue.sync {}
    }
}

/// 最小化的钥匙串封装，用来保存用户自己的 AI 服务密钥。
enum Keychain {
    private static let service = "LanguageInput.ai"
    private static let account = "api-key"

    static func get() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func set(_ value: String) {
        delete()
        guard !value.isEmpty else { return }
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8),
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
