import Cocoa

/// NSTableView subclass that intercepts SPACE for PLAY/PAUSE.
/// Up/Down arrow keys are left to the default NSTableView behavior,
/// which already moves the row selection without starting playback.
final class PlaylistTableView: NSTableView {
    var onSpace: (() -> Void)?
    var onDelete: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 { // Space
            onSpace?()
            return
        }
        if event.keyCode == 51 || event.keyCode == 117 {
            onDelete?()
            return
        }
        super.keyDown(with: event)
    }
}
