import Cocoa
import Carbon

/// 把本应用注册、启用并选中为输入源（install.sh 通过 `--register` 调用）。
/// 若系统没有立刻列出它，请注销并重新登录一次，再到
/// 系统设置 ▸ 键盘 ▸ 输入法 ▸ 编辑… ▸ 添加 ▸ 简体中文 ▸ 语言输入法。
enum InputSourceRegistration {
    static func registerEnableSelect() {
        let status = TISRegisterInputSource(Bundle.main.bundleURL as CFURL)
        if status != noErr {
            fputs("TISRegisterInputSource 返回 \(status)\n", stderr)
        }

        let bundleID = Bundle.main.bundleIdentifier ?? ""
        guard let unmanaged = TISCreateInputSourceList(nil, true) else { return }
        let all = unmanaged.takeRetainedValue() as? [TISInputSource] ?? []
        let mine = all.filter { stringProperty($0, kTISPropertyBundleID) == bundleID }

        if mine.isEmpty {
            fputs("未找到已注册的输入源，请注销并重新登录后再试。\n", stderr)
            return
        }
        for source in mine {
            TISEnableInputSource(source)
        }
        // 优先选中输入模式（而不是输入法本体）
        let mode = mine.first { stringProperty($0, kTISPropertyInputSourceType) == ((kTISTypeKeyboardInputMode as CFString) as String) }
        if let target = mode ?? mine.first {
            TISSelectInputSource(target)
        }
        print("已注册并启用 \(mine.count) 个输入源。")
    }

    private static func stringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }
}
