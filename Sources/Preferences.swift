import Foundation

/// 正在学习的语言（候选词旁显示该语言的译词）。
enum LearningLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case japanese = "ja"
    case spanish = "es"
    case vietnamese = "vi"
    case german = "de"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .japanese: return "日本語"
        case .spanish: return "Español"
        case .vietnamese: return "Tiếng Việt"
        case .german: return "Deutsch"
        }
    }

    /// 用于给 AI 提示词的英文名。
    var englishName: String {
        switch self {
        case .english: return "English"
        case .japanese: return "Japanese"
        case .spanish: return "Spanish"
        case .vietnamese: return "Vietnamese"
        case .german: return "German"
        }
    }
}

/// 输入方案。
enum InputScheme: String, CaseIterable, Identifiable {
    case fullPinyin
    case doublePinyinXiaohe

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fullPinyin: return "全拼（支持简拼）"
        case .doublePinyinXiaohe: return "小鹤双拼"
        }
    }
}

/// UserDefaults 键名。SwiftUI 的 @AppStorage 与引擎共用同一组键。
enum PrefKey {
    static let glossEnabled = "glossEnabled"
    static let learningLanguage = "learningLanguage"
    static let inputScheme = "inputScheme"
    static let pageSize = "pageSize"
    static let abbreviationEnabled = "abbreviationEnabled"
    static let chinesePunctuation = "chinesePunctuation"
    static let startInChinese = "startInChinese"
    static let candidateFontSize = "candidateFontSize"
    static let recordVocabulary = "recordVocabulary"
    static let inputLogEnabled = "inputLogEnabled"
    static let aiEnabled = "aiEnabled"
    static let aiEndpoint = "aiEndpoint"
    static let aiModel = "aiModel"
}

enum Prefs {
    static let defaultAIEndpoint = "https://api.openai.com/v1/chat/completions"
    static let defaultAIModel = "gpt-4o-mini"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            PrefKey.glossEnabled: true,
            PrefKey.learningLanguage: LearningLanguage.english.rawValue,
            PrefKey.inputScheme: InputScheme.fullPinyin.rawValue,
            PrefKey.pageSize: 7,
            PrefKey.abbreviationEnabled: true,
            PrefKey.chinesePunctuation: true,
            PrefKey.startInChinese: true,
            PrefKey.candidateFontSize: 18.0,
            PrefKey.recordVocabulary: true,
            PrefKey.inputLogEnabled: false,
            PrefKey.aiEnabled: false,
            PrefKey.aiEndpoint: defaultAIEndpoint,
            PrefKey.aiModel: defaultAIModel,
        ])
    }

    private static var d: UserDefaults { UserDefaults.standard }

    static var glossEnabled: Bool { d.bool(forKey: PrefKey.glossEnabled) }
    static var learningLanguage: LearningLanguage {
        LearningLanguage(rawValue: d.string(forKey: PrefKey.learningLanguage) ?? "") ?? .english
    }
    static var inputScheme: InputScheme {
        InputScheme(rawValue: d.string(forKey: PrefKey.inputScheme) ?? "") ?? .fullPinyin
    }
    static var pageSize: Int { min(9, max(3, d.integer(forKey: PrefKey.pageSize))) }
    static var abbreviationEnabled: Bool { d.bool(forKey: PrefKey.abbreviationEnabled) }
    static var chinesePunctuation: Bool { d.bool(forKey: PrefKey.chinesePunctuation) }
    static var startInChinese: Bool { d.bool(forKey: PrefKey.startInChinese) }
    static var candidateFontSize: CGFloat { CGFloat(min(32, max(12, d.double(forKey: PrefKey.candidateFontSize)))) }
    static var recordVocabulary: Bool { d.bool(forKey: PrefKey.recordVocabulary) }
    static var inputLogEnabled: Bool { d.bool(forKey: PrefKey.inputLogEnabled) }
    static var aiEnabled: Bool { d.bool(forKey: PrefKey.aiEnabled) }
    static var aiEndpoint: String { d.string(forKey: PrefKey.aiEndpoint) ?? defaultAIEndpoint }
    static var aiModel: String { d.string(forKey: PrefKey.aiModel) ?? defaultAIModel }
}

/// 进程内共享状态。
enum AppState {
    /// true = 中文模式，false = 英文直通模式（Shift 单击切换）。
    static var chineseMode = true
}
