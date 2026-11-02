import Cocoa
import InputMethodKit

// 命令行辅助：install.sh 使用 `--register` 把输入法登记到系统。
if CommandLine.arguments.contains("--register") {
    InputSourceRegistration.registerEnableSelect()
    exit(0)
}

let appDelegate = AppDelegate()
NSApplication.shared.delegate = appDelegate
NSApplication.shared.setActivationPolicy(.accessory)

// 连接名必须与 Info.plist 的 InputMethodConnectionName 一致。
let connectionName = Bundle.main.object(forInfoDictionaryKey: "InputMethodConnectionName") as? String
    ?? "LanguageInput_Connection"
let imkServer = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
_ = imkServer

NSApplication.shared.run()

