import Foundation

/// 候选词译词服务。
///
/// - 英文：使用随包附带的 CC-CEDICT 精简译词（完全离线）。
/// - 日/西/越/德：词库里没有对应数据，需要用户在设置里配置自己的 AI 服务（OpenAI 兼容接口，默认关闭）。
///   发送内容仅为当前页候选词本身，不包含上下文；结果缓存在本机。
final class GlossService {
    static let shared = GlossService()

    private var english: [String: String] = [:]
    private var cache: [String: String]
    private var inFlight = Set<String>()
    private var saveWork: DispatchWorkItem?

    private static let cacheFile = "gloss-cache.json"

    private init() {
        cache = Storage.load([String: String].self, from: GlossService.cacheFile) ?? [:]
        loadEnglish()
    }

    /// 后台预热。
    func warmUp() {}

    private func loadEnglish() {
        let url: URL?
        if Storage.exists("gloss_en.tsv") {
            url = Storage.url("gloss_en.tsv")
        } else {
            url = Bundle.main.url(forResource: "gloss_en", withExtension: "tsv")
        }
        guard let url, let data = try? Data(contentsOf: url) else { return }
        let text = String(decoding: data, as: UTF8.self)
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            if line.hasPrefix("#") { continue }
            let f = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            if f.count == 2 {
                english[String(f[0])] = f[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }

    // MARK: - 查询

    func gloss(for word: String) -> String? {
        guard Prefs.glossEnabled else { return nil }
        let lang = Prefs.learningLanguage
        if lang == .english, let g = english[word] { return g }
        return cache[lang.rawValue + "|" + word]
    }

    /// 需要联网补全的词：当前语言下没有译词，且用户启用了 AI。
    func needsRemote(_ words: [String]) -> [String] {
        guard Prefs.glossEnabled, Prefs.aiEnabled, Keychain.get() != nil else { return [] }
        let lang = Prefs.learningLanguage.rawValue
        return words.filter { w in
            gloss(for: w) == nil && !inFlight.contains(lang + "|" + w)
        }
    }

    /// 异步获取译词；完成后在主线程回调。
    func fetch(words: [String], completion: @escaping () -> Void) {
        let lang = Prefs.learningLanguage
        let todo = Array(needsRemote(words).prefix(12))
        guard !todo.isEmpty, let apiKey = Keychain.get(), !apiKey.isEmpty,
              let endpoint = URL(string: Prefs.aiEndpoint) else { return }
        for w in todo { inFlight.insert(lang.rawValue + "|" + w) }

        let system = "You are a concise bilingual dictionary. For each Chinese word given, reply with a short "
            + "\(lang.englishName) gloss (at most 4 words). Respond with ONLY a JSON object mapping each "
            + "Chinese word to its gloss. No markdown, no commentary."
        let body: [String: Any] = [
            "model": Prefs.aiModel,
            "temperature": 0,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": (try? String(data: JSONSerialization.data(withJSONObject: todo), encoding: .utf8)) ?? "[]"],
            ],
        ]
        var request = URLRequest(url: endpoint, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            let parsed = data.flatMap { GlossService.parseGlosses($0) } ?? [:]
            DispatchQueue.main.async {
                guard let self else { return }
                for w in todo {
                    self.inFlight.remove(lang.rawValue + "|" + w)
                    if let g = parsed[w], !g.isEmpty {
                        self.cache[lang.rawValue + "|" + w] = g
                    }
                }
                if !parsed.isEmpty {
                    self.scheduleSave()
                    completion()
                }
            }
        }.resume()
    }

    /// 测试连接（设置页使用）。
    static func testConnection(completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiKey = Keychain.get(), !apiKey.isEmpty else {
            completion(.failure(NSError(domain: "LanguageInput", code: 1,
                                        userInfo: [NSLocalizedDescriptionKey: "尚未填写 API Key"])))
            return
        }
        guard let endpoint = URL(string: Prefs.aiEndpoint) else {
            completion(.failure(NSError(domain: "LanguageInput", code: 2,
                                        userInfo: [NSLocalizedDescriptionKey: "接口地址无效"])))
            return
        }
        let body: [String: Any] = [
            "model": Prefs.aiModel,
            "max_tokens": 8,
            "messages": [["role": "user", "content": "Reply with the single word: ok"]],
        ]
        var request = URLRequest(url: endpoint, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error { completion(.failure(error)); return }
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                if (200..<300).contains(code) {
                    completion(.success("连接成功（HTTP \(code)）"))
                } else {
                    let snippet = data.flatMap { String(data: $0, encoding: .utf8) }?.prefix(160) ?? ""
                    completion(.failure(NSError(domain: "LanguageInput", code: code,
                                                userInfo: [NSLocalizedDescriptionKey: "HTTP \(code) \(snippet)"])))
                }
            }
        }.resume()
    }

    func clearCache() {
        cache.removeAll()
        saveWork?.cancel()
        Storage.remove(GlossService.cacheFile)
    }

    func flush() {
        saveWork?.cancel()
        Storage.save(cache, to: GlossService.cacheFile)
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.flush() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    /// 解析聊天补全响应里的 JSON 对象（兼容被 ``` 包裹的情况）。
    private static func parseGlosses(_ data: Data) -> [String: String]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              var content = message["content"] as? String else { return nil }
        content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if content.hasPrefix("```") {
            content = content.replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let jsonData = content.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { return nil }
        var result: [String: String] = [:]
        for (k, v) in obj {
            if let s = v as? String { result[k] = s }
        }
        return result
    }
}
