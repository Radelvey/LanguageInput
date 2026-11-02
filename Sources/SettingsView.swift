import SwiftUI
import Charts
import AppKit
import UniformTypeIdentifiers

// MARK: - 窗口

final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let w = NSWindow(contentViewController: hosting)
            w.title = "语言输入法 设置"
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.setContentSize(NSSize(width: 680, height: 540))
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private func confirm(_ message: String, detail: String = "", action: () -> Void) {
    let alert = NSAlert()
    alert.messageText = message
    alert.informativeText = detail
    alert.alertStyle = .warning
    alert.addButton(withTitle: "确定")
    alert.addButton(withTitle: "取消")
    if alert.runModal() == .alertFirstButtonReturn { action() }
}

// MARK: - 根视图

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("通用", systemImage: "keyboard") }
            LearningTab()
                .tabItem { Label("学习", systemImage: "character.book.closed") }
            StatsTab()
                .tabItem { Label("统计", systemImage: "chart.bar") }
            VocabTab()
                .tabItem { Label("词汇本", systemImage: "list.bullet.rectangle") }
            PrivacyTab()
                .tabItem { Label("隐私与关于", systemImage: "lock.shield") }
        }
        .frame(minWidth: 640, minHeight: 500)
    }
}

// MARK: - 通用

struct GeneralTab: View {
    @AppStorage(PrefKey.inputScheme) private var scheme = InputScheme.fullPinyin.rawValue
    @AppStorage(PrefKey.pageSize) private var pageSize = 7
    @AppStorage(PrefKey.abbreviationEnabled) private var abbreviation = true
    @AppStorage(PrefKey.chinesePunctuation) private var punctuation = true
    @AppStorage(PrefKey.startInChinese) private var startInChinese = true
    @AppStorage(PrefKey.candidateFontSize) private var fontSize: Double = 18

    var body: some View {
        Form {
            Section("输入") {
                Picker("输入方案", selection: $scheme) {
                    ForEach(InputScheme.allCases) { s in
                        Text(s.displayName).tag(s.rawValue)
                    }
                }
                Toggle("启用简拼（例如 nh → 你好）", isOn: $abbreviation)
                Toggle("输入中文标点", isOn: $punctuation)
                Toggle("切换到本输入法时默认使用中文模式", isOn: $startInChinese)
            }
            Section("候选窗") {
                Stepper(value: $pageSize, in: 3...9) {
                    Text("每页候选数：\(pageSize)")
                }
                HStack {
                    Text("候选字号：\(Int(fontSize))")
                    Slider(value: $fontSize, in: 14...30, step: 1)
                }
            }
            Section("按键") {
                Text("单击 Shift：中/英文切换　·　空格：上屏高亮候选　·　1–9：选词")
                Text("- = 或 , .：翻页　·　↑↓←→：移动高亮　·　Esc：取消　·　Return：原样字母上屏")
                Text("' ：手动隔音，例如 xi'an（西安）与 xian（先）")
            }
            .font(.callout)
            .foregroundColor(.secondary)
        }
        .formStyle(.grouped)
    }
}

// MARK: - 学习

struct LearningTab: View {
    @AppStorage(PrefKey.glossEnabled) private var glossEnabled = true
    @AppStorage(PrefKey.learningLanguage) private var language = LearningLanguage.english.rawValue
    @AppStorage(PrefKey.recordVocabulary) private var recordVocabulary = true
    @AppStorage(PrefKey.aiEnabled) private var aiEnabled = false
    @AppStorage(PrefKey.aiEndpoint) private var endpoint = Prefs.defaultAIEndpoint
    @AppStorage(PrefKey.aiModel) private var model = Prefs.defaultAIModel
    @State private var apiKey = Keychain.get() ?? ""
    @State private var testMessage = ""
    @State private var testing = false

    var body: some View {
        Form {
            Section("候选词译词") {
                Toggle("在候选词旁边显示译词", isOn: $glossEnabled)
                Picker("正在学习的语言", selection: $language) {
                    ForEach(LearningLanguage.allCases) { l in
                        Text(l.displayName).tag(l.rawValue)
                    }
                }
                .disabled(!glossEnabled)
                Toggle("把出现过译词的词记入词汇本", isOn: $recordVocabulary)
                Text("英文译词来自随包附带的离线词典；日语、西班牙语、越南语、德语需要在下方配置你自己的 AI 服务。译词只是辅助信息，不会替换你要输入的文字。")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            Section("AI 译词（可选，默认关闭）") {
                Toggle("启用 AI 译词", isOn: $aiEnabled)
                TextField("接口地址（OpenAI 兼容）", text: $endpoint)
                TextField("模型", text: $model)
                SecureField("API Key（保存在系统钥匙串）", text: $apiKey)
                HStack {
                    Button("保存密钥") {
                        Keychain.set(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
                        testMessage = "已保存"
                    }
                    Button(testing ? "测试中…" : "测试连接") {
                        Keychain.set(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
                        testing = true
                        testMessage = ""
                        GlossService.testConnection { result in
                            testing = false
                            switch result {
                            case .success(let message): testMessage = message
                            case .failure(let error): testMessage = "失败：\(error.localizedDescription)"
                            }
                        }
                    }
                    .disabled(testing)
                    Text(testMessage).font(.callout).foregroundColor(.secondary)
                }
                Text("启用后，仅会把当前页的候选词（不含上下文）发送到你配置的服务，用来获取译词；结果缓存在本机。")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - 统计

struct StatCard: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
            Text(title)
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.06)))
    }
}

struct StatsTab: View {
    @ObservedObject private var store = StatsStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                StatCard(title: "今天（字）", value: store.today)
                StatCard(title: "最近 7 天（字）", value: store.lastSevenDaysTotal)
                StatCard(title: "累计（字）", value: store.data.lifetime)
            }
            Text("最近 7 天").font(.headline)
            Chart(store.lastSevenDays()) { item in
                BarMark(x: .value("日期", item.date, unit: .day),
                        y: .value("字数", item.count))
                    .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .frame(minHeight: 200)
            Text("统计的是通过本输入法上屏的汉字数，仅保存在本机，不会上传。")
                .font(.callout)
                .foregroundColor(.secondary)
            Spacer(minLength: 0)
        }
        .padding(20)
    }
}

// MARK: - 词汇本

struct VocabTab: View {
    @ObservedObject private var store = StatsStore.shared
    @AppStorage(PrefKey.learningLanguage) private var languageRaw = LearningLanguage.english.rawValue
    @State private var query = ""
    @State private var hideKnown = false

    private var language: LearningLanguage { LearningLanguage(rawValue: languageRaw) ?? .english }

    private var items: [VocabEntry] {
        store.vocabulary(language: language)
            .filter { entry in
                if hideKnown && entry.known { return false }
                if query.isEmpty { return true }
                return entry.word.contains(query) || entry.gloss.localizedCaseInsensitiveContains(query)
            }
            .sorted { $0.lastSeen > $1.lastSeen }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("当前学习语言：\(language.displayName)").font(.headline)
                Spacer()
                TextField("搜索", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                Toggle("隐藏已掌握", isOn: $hideKnown)
            }
            if items.isEmpty {
                Spacer()
                Text("还没有记录。输入带有译词的词语并上屏后，会自动出现在这里。")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(items) { entry in
                        HStack(spacing: 10) {
                            Text(entry.word).font(.title3)
                            Text(entry.gloss).foregroundColor(.secondary).lineLimit(1)
                            Spacer()
                            Text("×\(entry.count)").foregroundColor(.secondary).monospacedDigit()
                            Button(entry.known ? "取消掌握" : "已掌握") {
                                store.setKnown(entry.id, known: !entry.known)
                            }
                            Button {
                                store.deleteVocab(entry.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .help("删除")
                        }
                        .buttonStyle(.borderless)
                        .opacity(entry.known ? 0.5 : 1)
                    }
                }
            }
            HStack {
                Text("共 \(items.count) 条").foregroundColor(.secondary)
                Spacer()
                Button("导出 CSV…") { exportCSV() }
                Button("清空词汇本") {
                    confirm("清空全部词汇本记录？", detail: "此操作无法撤销。") { store.clearVocabulary() }
                }
            }
        }
        .padding(20)
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "languageinput-vocabulary-\(language.rawValue).csv"
        if panel.runModal() == .OK, let url = panel.url {
            try? store.exportCSV(language: language).write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - 隐私与关于

struct PrivacyTab: View {
    @AppStorage(PrefKey.inputLogEnabled) private var inputLogEnabled = false

    var body: some View {
        Form {
            Section("本机数据") {
                Toggle("记录输入内容（默认关闭，独立于统计）", isOn: $inputLogEnabled)
                HStack {
                    Button("清除输入记录") {
                        confirm("清除输入记录？") { InputLog.clear() }
                    }
                    Button("清除统计与词汇本") {
                        confirm("清除统计与词汇本？", detail: "此操作无法撤销。") { StatsStore.shared.clearAll() }
                    }
                }
                HStack {
                    Button("清除输入习惯") {
                        confirm("清除输入习惯？", detail: "候选排序会恢复为词库默认顺序。") { UserModel.shared.reset() }
                    }
                    Button("清除译词缓存") { GlossService.shared.clearCache() }
                    Button("打开数据文件夹") { NSWorkspace.shared.open(Storage.directory) }
                }
                Text("词库放在数据文件夹里的 lexicon.tsv / gloss_en.tsv 会覆盖随包附带的版本；lexicon.user.tsv 可追加自定义词（每行：拼音<Tab>词<Tab>频次）。")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            Section("隐私") {
                Text("拼音转换、词库查询、译词（英文）、统计与输入习惯学习全部在本机完成。不需要账号，不会自动联网。只有当你主动启用 AI 译词时，才会把当前页的候选词发送到你自己配置的服务。")
                    .font(.callout)
            }
            Section("关于") {
                Text("语言输入法 0.1.0")
                Text("这是一个受开源项目「青简 Qingjian」启发、用 Swift / SwiftUI 独立编写的 macOS 输入法，与原项目及其作者无隶属关系，也未使用其源代码。")
                    .font(.callout)
                    .foregroundColor(.secondary)
                Link("原项目：github.com/qingjian-team/qingjian",
                     destination: URL(string: "https://github.com/qingjian-team/qingjian")!)
            }
        }
        .formStyle(.grouped)
    }
}
