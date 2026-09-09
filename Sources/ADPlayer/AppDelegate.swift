import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController!
    private var previewWindowController: PreviewWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let engine = PlaybackEngine()

        previewWindowController = PreviewWindowController()
        engine.previewView = previewWindowController.previewView

        mainWindowController = MainWindowController(engine: engine)

        previewWindowController.placeOnSecondaryScreenOrFallback()
        mainWindowController.showWindow(nil)
        mainWindowController.window?.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screenParametersChanged() {
        previewWindowController.placeOnSecondaryScreenOrFallback()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
