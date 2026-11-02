import Cocoa
import SwiftUI

/// 候选窗的数据模型。
final class CandidateViewModel: ObservableObject {
    struct Row: Identifiable {
        let id: Int          // 全局候选下标
        let number: Int      // 页内序号（1…）
        let text: String
        let gloss: String?
        let selected: Bool
    }

    @Published var preedit = ""
    @Published var rows: [Row] = []
    @Published var pageText = ""
    @Published var toast: String?
    @Published var fontSize: CGFloat = 18

    var onPick: ((Int) -> Void)?
}

/// 候选窗视图：每个候选后面跟着一条小号的译词。
struct CandidateView: View {
    @ObservedObject var model: CandidateViewModel

    var body: some View {
        Group {
            if let toast = model.toast, model.rows.isEmpty, model.preedit.isEmpty {
                Text(toast)
                    .font(.system(size: 20, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            } else {
                content
            }
        }
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
        .fixedSize()
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !model.preedit.isEmpty {
                Text(model.preedit)
                    .font(.system(size: max(12, model.fontSize * 0.72), design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 2)
            }
            ForEach(model.rows) { row in
                rowView(row)
            }
            if !model.pageText.isEmpty {
                Text(model.pageText)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 8)
            }
        }
        .padding(6)
    }

    private func rowView(_ row: CandidateViewModel.Row) -> some View {
        HStack(spacing: 8) {
            Text("\(row.number)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(row.selected ? Color.white.opacity(0.9) : Color.secondary)
                .frame(width: 16)
            Text(row.text)
                .font(.system(size: model.fontSize))
                .foregroundColor(row.selected ? Color.white : Color.primary)
            if let gloss = row.gloss, !gloss.isEmpty {
                Text(gloss)
                    .font(.system(size: max(11, model.fontSize * 0.66)))
                    .foregroundColor(row.selected ? Color.white.opacity(0.85) : Color.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(row.selected ? Color.accentColor : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { model.onPick?(row.id) }
    }
}

/// 浮在光标附近的非激活面板，不会抢走文本框的键盘焦点。
final class CandidatePanel {
    static let shared = CandidatePanel()

    let model: CandidateViewModel
    private let panel: NSPanel
    private let hosting: NSHostingView<CandidateView>
    private var toastWork: DispatchWorkItem?

    private init() {
        let model = CandidateViewModel()
        self.model = model
        let hosting = NSHostingView(rootView: CandidateView(model: model))
        self.hosting = hosting

        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 60),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: true)
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = hosting
        self.panel = panel
    }

    func show(near anchor: NSRect) {
        toastWork?.cancel()
        model.toast = nil
        layout(near: anchor)
        panel.orderFrontRegardless()
        // SwiftUI 在下一个 runloop 才会应用模型变化，再量一次尺寸
        DispatchQueue.main.async { [weak self] in
            self?.layout(near: anchor)
        }
    }

    func hide() {
        toastWork?.cancel()
        panel.orderOut(nil)
        if !model.rows.isEmpty { model.rows = [] }
        if !model.preedit.isEmpty { model.preedit = "" }
        model.pageText = ""
    }

    /// 短暂显示"中 / En"之类的提示。
    func showToast(_ text: String, near anchor: NSRect) {
        toastWork?.cancel()
        model.rows = []
        model.preedit = ""
        model.pageText = ""
        model.toast = text
        layout(near: anchor)
        panel.orderFrontRegardless()
        DispatchQueue.main.async { [weak self] in
            self?.layout(near: anchor)
        }
        let work = DispatchWorkItem { [weak self] in
            self?.model.toast = nil
            self?.panel.orderOut(nil)
        }
        toastWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    private func layout(near anchor: NSRect) {
        hosting.layoutSubtreeIfNeeded()
        var size = hosting.fittingSize
        size.width = max(size.width, 40)
        size.height = max(size.height, 30)

        let center = NSPoint(x: anchor.midX, y: anchor.midY)
        let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        var x = anchor.minX
        var y = anchor.minY - size.height - 4          // 默认显示在光标下方
        if y < visible.minY { y = anchor.maxY + 4 }    // 下方放不下就翻到上方
        x = min(max(x, visible.minX + 4), visible.maxX - size.width - 4)
        panel.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: true)
    }
}
