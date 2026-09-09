import Cocoa
import AVFoundation

/// A view whose backing layer is an AVPlayerLayer, used to render video.
final class VideoContainerView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func makeBackingLayer() -> CALayer {
        let layer = AVPlayerLayer()
        layer.videoGravity = .resizeAspect
        return layer
    }

    var playerLayer: AVPlayerLayer {
        // swiftlint:disable:next force_cast
        layer as! AVPlayerLayer
    }
}

/// Full-screen preview surface: black background, freeze-frame image, or video layer.
/// Only one of the three states is visible at a time.
final class PreviewView: NSView {
    let imageView = NSImageView()
    let videoView = VideoContainerView()
    private let titleLabel = NSTextField(labelWithString: "")

    /// Supplies the right-click menu (e.g. fullscreen/windowed toggle).
    var contextMenuProvider: (() -> NSMenu?)?

    override func menu(for event: NSEvent) -> NSMenu? {
        contextMenuProvider?()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        setupSubviews()
    }

    private func setupSubviews() {
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isHidden = true

        videoView.translatesAutoresizingMaskIntoConstraints = false
        videoView.isHidden = true

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.alignment = .center
        titleLabel.textColor = .white
        titleLabel.drawsBackground = false
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.isHidden = true

        addSubview(videoView)
        addSubview(imageView)
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            videoView.topAnchor.constraint(equalTo: topAnchor),
            videoView.bottomAnchor.constraint(equalTo: bottomAnchor),
            videoView.leadingAnchor.constraint(equalTo: leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: trailingAnchor),

            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),

            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20)
        ])
    }

    /// Centered filename card (Helvetica Bold, ~10% of the view's height) shown
    /// before playback starts, over a black background.
    func showTitleCard(_ text: String) {
        videoView.playerLayer.player = nil
        videoView.isHidden = true
        imageView.isHidden = true
        imageView.image = nil

        let fontSize = max(12, bounds.height * 0.10)
        titleLabel.font = NSFont(name: "Helvetica-Bold", size: fontSize) ?? NSFont.boldSystemFont(ofSize: fontSize)
        titleLabel.stringValue = text
        titleLabel.isHidden = false
    }

    func showImage(_ image: NSImage) {
        titleLabel.isHidden = true
        videoView.playerLayer.player = nil
        videoView.isHidden = true
        imageView.image = image
        imageView.isHidden = false
    }

    func showVideo(player: AVPlayer) {
        titleLabel.isHidden = true
        imageView.isHidden = true
        imageView.image = nil
        videoView.playerLayer.player = player
        videoView.isHidden = false
    }

    /// Blackout: end of playback / explicit stop.
    func showBlack() {
        titleLabel.isHidden = true
        imageView.isHidden = true
        imageView.image = nil
        videoView.playerLayer.player = nil
        videoView.isHidden = true
    }
}
