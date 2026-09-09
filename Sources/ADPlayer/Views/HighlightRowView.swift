import Cocoa

/// Draws a highlight ring around the row that is the current selection
/// ("actif" = playing or ready to play).
final class HighlightRowView: NSTableRowView {
    var isCurrent: Bool = false {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard isCurrent else { return }
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 1), xRadius: 4, yRadius: 4)
        path.lineWidth = 2
        NSColor.controlAccentColor.setStroke()
        path.stroke()
    }
}
