import Cocoa

/// Draws a highlight ring around the row that is the current selection
/// ("actif" = playing or ready to play). Paired video+WAV entries get a red
/// ring instead of the normal blue one. The ring itself is a light tint;
/// the progress fill (0...1, growing as the item plays) uses the vivid color.
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

        let vividColor = isPairedEntry ? NSColor.systemRed : NSColor.systemBlue
        let lightColor = vividColor.blended(withFraction: 0.65, of: .white) ?? vividColor

        if progress > 0 {
            let fillRect = NSRect(x: bounds.minX, y: bounds.minY, width: bounds.width * progress, height: bounds.height)
            vividColor.withAlphaComponent(0.35).setFill()
            fillRect.fill()
        }

        guard isCurrent else { return }
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 1), xRadius: 4, yRadius: 4)
        path.lineWidth = 2
        lightColor.setStroke()
        path.stroke()
    }
}
