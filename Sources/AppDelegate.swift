import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Prefs.registerDefaults()
        AppState.chineseMode = Prefs.startInChinese

        // 后台预热词库与译词，避免第一次按键卡顿
        DispatchQueue.global(qos: .userInitiated).async {
            _ = Lexicon.shared
            _ = GlossService.shared
            _ = UserModel.shared
        }

        if CommandLine.arguments.contains("--settings") {
            SettingsWindowController.shared.show()
        }
    }

    /// 再次 `open` 本应用（或在"输入法"文件夹里双击）时打开设置窗口。
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowController.shared.show()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        StatsStore.shared.flush()
        UserModel.shared.flush()
        GlossService.shared.flush()
        Storage.drain()
    }
}
