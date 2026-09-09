import Cocoa

/// Draws the row highlight for the current selection ("actif" = playing or
/// ready to play). The ring stays fully opaque in its original color (blue
/// normal, red for paired video+audio entries). The native full-row selection
/// background is replaced by a single lighter fill that grows left-to-right
/// (0...1) as the loaded item plays, instead of always filling the whole row.
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

    override func drawSelection(in dirtyRect: NSRect) {
        // Suppressed: replaced by the growing progress fill below.
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let vividColor = isPairedEntry ? NSColor.systemRed : NSColor.systemBlue

        let fullRingRect = bounds.insetBy(dx: 2, dy: 1)
        let controlsInset: CGFloat = 40
        let ringRect = NSRect(
            x: fullRingRect.minX,
            y: fullRingRect.minY,
            width: max(0, fullRingRect.width - controlsInset),
            height: fullRingRect.height
        )
        let path = NSBezierPath(roundedRect: ringRect, xRadius: 4, yRadius: 4)

        if progress > 0 {
            let lightColor = vividColor.blended(withFraction: 0.65, of: .white) ?? vividColor
            let fillRect = NSRect(
                x: ringRect.minX,
                y: ringRect.minY,
                width: ringRect.width * progress,
                height: ringRect.height
            )
            let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 4, yRadius: 4)
            path.addClip()
            lightColor.setFill()
            fillPath.fill()
        }

        guard isCurrent else { return }
        path.lineWidth = 2
        vividColor.setStroke()
        path.stroke()
    }
}
