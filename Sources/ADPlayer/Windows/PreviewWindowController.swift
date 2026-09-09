import Cocoa

/// Borderless output window: fills the secondary display when one is connected
/// (main screen stays fully accessible), otherwise falls back to a normal
/// window on the main screen for single-display development/testing.
final class PreviewWindowController: NSWindowController {
    let previewView = PreviewView(frame: NSRect(x: 0, y: 0, width: 960, height: 540))

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
    }

    func placeOnSecondaryScreenOrFallback() {
        guard let window = window else { return }
        let secondary = NSScreen.screens.first { $0 != NSScreen.main }

        if let secondary = secondary {
            window.styleMask = [.borderless]
            window.setFrame(secondary.frame, display: true)
        } else if let main = NSScreen.main {
            let width = main.frame.width * 0.5
            let height = width * 9 / 16
            let rect = NSRect(
                x: main.frame.midX - width / 2,
                y: main.frame.midY - height / 2,
                width: width,
                height: height
            )
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setFrame(rect, display: true)
        }
        window.orderFront(nil)
    }
}
