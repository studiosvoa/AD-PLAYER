import Cocoa

/// NSTableCellView ignores selection-driven background style changes, so the
/// filename text field never gets flipped to white (invisible against our
/// custom row highlight, which no longer draws the native blue selection).
final class MediaCellView: NSTableCellView {
    override var backgroundStyle: NSView.BackgroundStyle {
        get { .normal }
        set { /* ignored on purpose */ }
    }
}
