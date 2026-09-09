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

        addSubview(videoView)
        addSubview(imageView)

        NSLayoutConstraint.activate([
            videoView.topAnchor.constraint(equalTo: topAnchor),
            videoView.bottomAnchor.constraint(equalTo: bottomAnchor),
            videoView.leadingAnchor.constraint(equalTo: leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: trailingAnchor),

            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    func showImage(_ image: NSImage) {
        videoView.playerLayer.player = nil
        videoView.isHidden = true
        imageView.image = image
        imageView.isHidden = false
    }

    func showVideo(player: AVPlayer) {
        imageView.isHidden = true
        imageView.image = nil
        videoView.playerLayer.player = player
        videoView.isHidden = false
    }

    /// Blackout: end of playback / explicit stop.
    func showBlack() {
        imageView.isHidden = true
        imageView.image = nil
        videoView.playerLayer.player = nil
        videoView.isHidden = true
    }
}
