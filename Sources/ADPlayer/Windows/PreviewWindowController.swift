import Cocoa

enum PreviewDisplayMode {
    case fullScreen
    case windowed
}

/// Output window. In `.fullScreen` mode it is borderless and fills the secondary
/// display (main screen stays fully accessible). In `.windowed` mode it is a normal
/// resizable window. Falls back to windowed when only one display is connected.
final class PreviewWindowController: NSWindowController {
    let previewView = PreviewView(frame: NSRect(x: 0, y: 0, width: 960, height: 540))

    private(set) var displayMode: PreviewDisplayMode = .fullScreen
    var onDisplayModeChanged: ((PreviewDisplayMode) -> Void)?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 540),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.title = "AD-PLAYER — Preview"
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        window.hasShadow = false
        window.level = .normal
        window.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
        self.init(window: window)
        window.contentView = previewView
        previewView.contextMenuProvider = { [weak self] in self?.buildContextMenu() }
    }

    func placeWindow() {
        guard let window = window else { return }
        let secondary = NSScreen.screens.first { $0 != NSScreen.main }

        switch displayMode {
        case .fullScreen:
            if let secondary = secondary {
                window.styleMask = [.borderless]
                window.setFrame(secondary.frame, display: true)
            } else {
                applyWindowedFrame(on: NSScreen.main, window: window)
            }
        case .windowed:
            applyWindowedFrame(on: secondary ?? NSScreen.main, window: window)
        }
        window.orderFront(nil)
    }

    func toggleDisplayMode() {
        displayMode = (displayMode == .fullScreen) ? .windowed : .fullScreen
        placeWindow()
        onDisplayModeChanged?(displayMode)
    }

    private func applyWindowedFrame(on screen: NSScreen?, window: NSWindow) {
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        guard let screen = screen else { return }
        let width = screen.frame.width * 0.5
        let height = width * 9 / 16
        let rect = NSRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.midY - height / 2,
            width: width,
            height: height
        )
        window.setFrame(rect, display: true)
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()
        let title = (displayMode == .fullScreen) ? "Basculer en mode fenêtré" : "Basculer en plein écran"
        let item = NSMenuItem(title: title, action: #selector(contextMenuToggle), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return menu
    }

    @objc private func contextMenuToggle() {
        toggleDisplayMode()
    }
}
