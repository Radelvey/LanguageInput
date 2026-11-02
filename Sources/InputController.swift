import Cocoa
import InputMethodKit

/// 每个获得输入焦点的客户端（文本框所在应用）对应一个控制器实例。
/// Info.plist 的 InputMethodServerControllerClass 通过 @objc 名称找到这个类。
@objc(LanguageInputController)
final class LanguageInputController: IMKInputController {

    // MARK: - 状态

    /// 用户敲下的原始按键（全拼：字母与隔音符；双拼：键位）。
    private var raw: [UInt8] = []
    private var conversion = InputConversion.empty
    private var result = DecodeResult.empty
    /// 当前高亮的候选（全局下标）。
    private var selected = 0

    // Shift 单击切换中英文
    private var shiftDown = false
    private var shiftClean = false
    private var shiftDownAt = Date.distantPast

    private static var doubleQuoteOpen = false
    private static var singleQuoteOpen = false

    private var isComposing: Bool { !raw.isEmpty }
    private let notFound = NSRange(location: NSNotFound, length: NSNotFound)

    // MARK: - IMK 生命周期

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask([.keyDown, .flagsChanged]).rawValue)
    }

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        clearState(touchClient: false)
        bindPanelCallbacks()
    }

    override func deactivateServer(_ sender: Any!) {
        commitRaw()
        CandidatePanel.shared.hide()
        super.deactivateServer(sender)
    }

    override func commitComposition(_ sender: Any!) {
        commitRaw()
    }

    override func menu() -> NSMenu! {
        let menu = NSMenu()
        let modeTitle = AppState.chineseMode ? "切换到英文模式" : "切换到中文模式"
        let modeItem = NSMenuItem(title: modeTitle, action: #selector(toggleModeFromMenu(_:)), keyEquivalent: "")
        modeItem.target = self
        menu.addItem(modeItem)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "语言输入法 设置…", action: #selector(openSettings(_:)), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)
        return menu
    }

    @objc func toggleModeFromMenu(_ sender: Any?) {
        toggleMode()
    }

    @objc func openSettings(_ sender: Any?) {
        SettingsWindowController.shared.show()
    }

    // MARK: - 按键入口

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event else { return false }
        switch event.type {
        case .flagsChanged:
            return handleFlagsChanged(event)
        case .keyDown:
            shiftClean = false
            return handleKeyDown(event)
        default:
            return false
        }
    }

    /// 单击 Shift（按下后未按其它键就松开）切换中/英文。
    private func handleFlagsChanged(_ event: NSEvent) -> Bool {
        let relevant: NSEvent.ModifierFlags = [.shift, .control, .option, .command]
        let flags = event.modifierFlags.intersection(relevant)
        if flags == [.shift] {
            if !shiftDown {
                shiftDown = true
                shiftClean = true
                shiftDownAt = Date()
            }
        } else if flags.isEmpty {
            if shiftDown, shiftClean, Date().timeIntervalSince(shiftDownAt) < 0.6 {
                toggleMode()
            }
            shiftDown = false
            shiftClean = false
        } else {
            shiftClean = false
            if !flags.contains(.shift) { shiftDown = false }
        }
        return false
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // ⌘ / ⌃ / ⌥ 组合键：先把正在输入的字母原样上屏，再放行
        if flags.contains(.command) || flags.contains(.control) || flags.contains(.option) {
            if isComposing { commitRaw() }
            return false
        }
        guard AppState.chineseMode else { return false }

        let keyCode = event.keyCode
        if isComposing {
            switch keyCode {
            case 36, 76: // Return / Enter：原样字母上屏
                commitRaw()
                return true
            case 49: // Space：上屏高亮候选
                commit(at: selected)
                return true
            case 51: // Delete
                raw.removeLast()
                if raw.isEmpty { clearState() } else { refresh() }
                return true
            case 117: // Forward delete：忽略
                return true
            case 53: // Esc
                clearState()
                return true
            case 123, 126: // ← ↑
                moveSelection(-1)
                return true
            case 124, 125: // → ↓
                moveSelection(1)
                return true
            case 116: // Page Up
                changePage(-1)
                return true
            case 121, 48: // Page Down / Tab
                changePage(1)
                return true
            default:
                break
            }
        }

        guard let chars = event.characters, chars.unicodeScalars.count == 1,
              let scalar = chars.unicodeScalars.first else {
            return isComposing // 组合中吞掉无法识别的按键，避免污染预编辑
        }
        let v = scalar.value

        // 小写字母：进入/继续输入
        if v >= 97 && v <= 122 {
            if flags.contains(.capsLock) && !isComposing { return false }
            appendKey(UInt8(v))
            return true
        }
        // 大写字母：视为想直接输入英文
        if v >= 65 && v <= 90 {
            if isComposing { commitRaw() }
            return false
        }
        // 隔音符
        if v == 39, isComposing, Prefs.inputScheme == .fullPinyin {
            if raw.last != 39 { appendKey(39) }
            return true
        }
        // 数字：选词
        if v >= 48 && v <= 57 {
            guard isComposing else { return false }
            if v == 48 { return true }
            let size = Prefs.pageSize
            let digit = Int(v) - 48
            if digit <= size {
                let index = (selected / size) * size + digit - 1
                if index < result.candidates.count { commit(at: index) }
            }
            return true
        }

        // 翻页键 - = , .（仅在有多页时生效）
        if isComposing, pageCount > 1 {
            switch v {
            case 45, 44: changePage(-1); return true   // - ,
            case 61, 46: changePage(1); return true    // = .
            default: break
            }
        }

        // 标点
        let ch = Character(scalar)
        if isComposing {
            commitGreedily()
            insert(mappedPunctuation(ch) ?? String(ch))
            return true
        }
        if let mapped = mappedPunctuation(ch) {
            insert(mapped)
            return true
        }
        return false
    }

    private func mappedPunctuation(_ ch: Character) -> String? {
        guard Prefs.chinesePunctuation else { return nil }
        switch ch {
        case ",": return "，"
        case ".": return "。"
        case "?": return "？"
        case "!": return "！"
        case ";": return "；"
        case ":": return "："
        case "\\": return "、"
        case "(": return "（"
        case ")": return "）"
        case "<": return "《"
        case ">": return "》"
        case "[": return "【"
        case "]": return "】"
        case "\"":
            LanguageInputController.doubleQuoteOpen.toggle()
            return LanguageInputController.doubleQuoteOpen ? "“" : "”"
        case "'":
            LanguageInputController.singleQuoteOpen.toggle()
            return LanguageInputController.singleQuoteOpen ? "‘" : "’"
        default: return nil
        }
    }

    // MARK: - 输入状态

    private func appendKey(_ byte: UInt8) {
        guard raw.count < 40 else { return }
        raw.append(byte)
        refresh()
    }

    private func toggleMode() {
        if isComposing { commitRaw() }
        AppState.chineseMode.toggle()
        CandidatePanel.shared.showToast(AppState.chineseMode ? "中" : "En", near: caretRect())
    }

    /// 重新解码并刷新界面。
    private func refresh() {
        guard !raw.isEmpty else { clearState(); return }
        conversion = InputConversion.make(raw: raw, scheme: Prefs.inputScheme)
        var decoded = Engine.shared.decode(conversion, options: .init(abbreviation: Prefs.abbreviationEnabled))
        attachGlosses(&decoded)
        result = decoded
        selected = 0
        updateMarkedText()
        updatePanel()
        prefetchGlosses()
    }

    private func attachGlosses(_ decoded: inout DecodeResult) {
        guard Prefs.glossEnabled else { return }
        for i in decoded.candidates.indices {
            let kind = decoded.candidates[i].kind
            if kind == .word || kind == .abbreviation {
                decoded.candidates[i].gloss = GlossService.shared.gloss(for: decoded.candidates[i].text)
            }
        }
    }

    /// 当前页上还没有译词的候选，向用户配置的 AI 服务（如已启用）补全。
    private func prefetchGlosses() {
        guard Prefs.glossEnabled, Prefs.aiEnabled else { return }
        let words = currentPageRange().map { result.candidates[$0] }
            .filter { $0.kind == .word || $0.kind == .abbreviation }
            .map { $0.text }
        guard !GlossService.shared.needsRemote(words).isEmpty else { return }
        GlossService.shared.fetch(words: words) { [weak self] in
            guard let self, self.isComposing else { return }
            var decoded = self.result
            self.attachGlosses(&decoded)
            self.result = decoded
            self.updatePanel()
        }
    }

    private var preeditText: String {
        let base = result.syllables.joined(separator: " ")
        let pending = conversion.pending
        if pending.isEmpty { return base }
        return base.isEmpty ? pending : base + " " + pending
    }

    private func updateMarkedText() {
        guard let client = client() else { return }
        let display = preeditText
        let attributes: [NSAttributedString.Key: Any] = [
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]
        let text = NSAttributedString(string: display, attributes: attributes)
        client.setMarkedText(text,
                             selectionRange: NSRange(location: (display as NSString).length, length: 0),
                             replacementRange: notFound)
    }

    // MARK: - 候选窗

    private var pageCount: Int {
        let size = Prefs.pageSize
        return max(1, (result.candidates.count + size - 1) / size)
    }

    private func currentPageRange() -> Range<Int> {
        let size = Prefs.pageSize
        let start = (selected / size) * size
        let end = min(start + size, result.candidates.count)
        return start..<max(start, end)
    }

    private func bindPanelCallbacks() {
        CandidatePanel.shared.model.onPick = { [weak self] index in
            self?.commit(at: index)
        }
    }

    private func updatePanel() {
        let range = currentPageRange()
        var rows: [CandidateViewModel.Row] = []
        for i in range {
            let c = result.candidates[i]
            rows.append(CandidateViewModel.Row(id: i, number: i - range.lowerBound + 1, text: c.text,
                                               gloss: c.gloss, selected: i == selected))
        }
        let model = CandidatePanel.shared.model
        bindPanelCallbacks()
        model.fontSize = Prefs.candidateFontSize
        model.preedit = preeditText
        model.rows = rows
        model.pageText = pageCount > 1 ? "\(selected / Prefs.pageSize + 1)/\(pageCount)" : ""
        CandidatePanel.shared.show(near: caretRect())
    }

    private func moveSelection(_ delta: Int) {
        guard !result.candidates.isEmpty else { return }
        selected = min(max(selected + delta, 0), result.candidates.count - 1)
        updatePanel()
        prefetchGlosses()
    }

    private func changePage(_ delta: Int) {
        guard !result.candidates.isEmpty else { return }
        let size = Prefs.pageSize
        let page = min(max(selected / size + delta, 0), pageCount - 1)
        selected = page * size
        updatePanel()
        prefetchGlosses()
    }

    /// 光标所在行的屏幕矩形，用来摆放候选窗。
    private func caretRect() -> NSRect {
        guard let client = client() else { return mouseFallbackRect() }
        var rect = NSRect.zero
        let sel = client.selectedRange()
        let index = sel.location == NSNotFound ? 0 : sel.location
        _ = client.attributes(forCharacterIndex: index, lineHeightRectangle: &rect)
        if rect.height == 0 {
            _ = client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
        }
        return rect.height == 0 ? mouseFallbackRect() : rect
    }

    private func mouseFallbackRect() -> NSRect {
        let p = NSEvent.mouseLocation
        return NSRect(x: p.x, y: p.y - 20, width: 1, height: 20)
    }

    // MARK: - 上屏

    private func insert(_ text: String) {
        client()?.insertText(text, replacementRange: notFound)
    }

    /// 选中第 index 个候选并上屏；只消耗它覆盖的那部分拼音，剩余部分继续输入。
    private func commit(at index: Int) {
        guard index >= 0, index < result.candidates.count else { return }
        let candidate = result.candidates[index]
        insert(candidate.text)
        record(candidate)

        let consumedLetters = min(candidate.consumed, conversion.rawEnd.count - 1)
        let consumedRaw = min(conversion.rawEnd[consumedLetters], raw.count)
        raw.removeFirst(consumedRaw)
        if raw.isEmpty {
            clearState()
        } else {
            refresh()
        }
    }

    /// 连续上屏第一候选直到缓冲区清空（输入标点前使用）。
    private func commitGreedily() {
        var guardCount = 0
        while isComposing, guardCount < 60 {
            guardCount += 1
            let before = raw.count
            commit(at: selected)
            if raw.count >= before { // 保险：没有前进就直接原样上屏
                commitRaw()
                break
            }
            selected = 0
        }
    }

    /// 把原始按键原样作为英文上屏。
    private func commitRaw() {
        guard !raw.isEmpty else { return }
        insert(String(decoding: raw, as: UTF8.self))
        clearState(touchClient: false)
    }

    private func record(_ candidate: Candidate) {
        StatsStore.shared.recordInput(text: candidate.text)
        InputLog.append(candidate.text)
        switch candidate.kind {
        case .word, .abbreviation:
            UserModel.shared.learn(candidate.text)
            // 词汇本只收两个字以上、并且当时确实显示了译词的词
            if Prefs.recordVocabulary, candidate.text.count >= 2, let gloss = candidate.gloss {
                StatsStore.shared.recordWord(candidate.text, gloss: gloss, language: Prefs.learningLanguage)
            }
        case .sentence, .raw:
            break
        }
    }

    private func clearState(touchClient: Bool = true) {
        let wasComposing = isComposing
        raw.removeAll()
        conversion = .empty
        result = .empty
        selected = 0
        CandidatePanel.shared.hide()
        if touchClient, wasComposing, let client = client() {
            client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0), replacementRange: notFound)
        }
    }
}
