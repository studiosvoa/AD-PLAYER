import Cocoa

/// Draws a highlight ring around the row that is the current selection
/// ("actif" = playing or ready to play). Paired video+WAV entries get a red
/// ring instead of the normal blue one. A fill grows left-to-right (0...1)
/// as the loaded item plays, in the same color as the ring.
final class HighlightRowView: NSTableRowView {
    var isCurrent: Bool = false {
        didSet { needsDisplay = true }
    }
    var isPairedEntry: Bool = false {
        didSet { needsDisplay = true }
    }
    var progress: CGFloat = 0 {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let accent = isPairedEntry ? NSColor.systemRed : NSColor.systemBlue

        if progress > 0 {
            let fillRect = NSRect(x: bounds.minX, y: bounds.minY, width: bounds.width * progress, height: bounds.height)
            accent.withAlphaComponent(0.18).setFill()
            fillRect.fill()
        }

        guard isCurrent else { return }
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 1), xRadius: 4, yRadius: 4)
        path.lineWidth = 2
        accent.setStroke()
        path.stroke()
    }
}
