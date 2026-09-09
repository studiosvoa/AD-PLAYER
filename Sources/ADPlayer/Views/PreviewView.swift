import Cocoa
import AVFoundation
import QuartzCore

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
        layer.backgroundColor = NSColor.black.cgColor
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
    private let audioNameLabel = NSTextField(labelWithString: "")
    private let audioProgress = NSProgressIndicator()
    private var displayGeneration = 0

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
        titleLabel.lineBreakMode = .byClipping
        titleLabel.maximumNumberOfLines = 1
        titleLabel.isHidden = true

        audioNameLabel.translatesAutoresizingMaskIntoConstraints = false
        audioNameLabel.alignment = .center
        audioNameLabel.textColor = .white
        audioNameLabel.lineBreakMode = .byTruncatingMiddle
        audioNameLabel.isHidden = true

        audioProgress.translatesAutoresizingMaskIntoConstraints = false
        audioProgress.style = .bar
        audioProgress.isIndeterminate = false
        audioProgress.minValue = 0
        audioProgress.maxValue = 1
        audioProgress.isHidden = true

        addSubview(videoView)
        addSubview(imageView)
        addSubview(titleLabel)
        addSubview(audioNameLabel)
        addSubview(audioProgress)

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
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),
            audioNameLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            audioNameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            audioNameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 48),
            audioNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -48),
            audioProgress.centerXAnchor.constraint(equalTo: centerXAnchor),
            audioProgress.centerYAnchor.constraint(equalTo: centerYAnchor),
            audioProgress.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 48),
            audioProgress.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -48),
            audioProgress.heightAnchor.constraint(equalToConstant: 8)
        ])
    }

    /// Centered filename card (Helvetica Bold, ~10% of the view's height) shown
    /// before playback starts, over a black background.
    func showTitleCard(_ text: String, fadeDuration: Double = 0) {
        displayGeneration += 1
        videoView.playerLayer.player = nil
        videoView.isHidden = true
        audioNameLabel.isHidden = true
        audioProgress.isHidden = true
        imageView.isHidden = true
        imageView.image = nil

        titleLabel.font = fittingTitleFont(for: text)
        titleLabel.stringValue = text
        titleLabel.isHidden = false
        fadeInIfNeeded(duration: fadeDuration)
    }

    private func fittingTitleFont(for text: String) -> NSFont {
        let fontName = "Helvetica-Bold"
        let maximumSize = max(12, bounds.height * 0.10)
        let minimumSize: CGFloat = 8
        let horizontalSafetyMargin: CGFloat = 48
        let availableWidth = max(1, bounds.width - horizontalSafetyMargin * 2)

        var size = maximumSize
        while size > minimumSize {
            let font = NSFont(name: fontName, size: size) ?? NSFont.boldSystemFont(ofSize: size)
            let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
            if textWidth <= availableWidth {
                return font
            }
            size -= 1
        }

        return NSFont(name: fontName, size: minimumSize) ?? NSFont.boldSystemFont(ofSize: minimumSize)
    }

    func showImage(_ image: NSImage, fadeDuration: Double = 0) {
        displayGeneration += 1
        titleLabel.isHidden = true
        audioNameLabel.isHidden = true
        audioProgress.isHidden = true
        videoView.playerLayer.player = nil
        videoView.isHidden = true
        imageView.image = image
        imageView.isHidden = false
        fadeInIfNeeded(duration: fadeDuration)
    }

    func showVideo(player: AVPlayer, fadeDuration: Double = 0) {
        displayGeneration += 1
        titleLabel.isHidden = true
        audioNameLabel.isHidden = true
        audioProgress.isHidden = true
        imageView.isHidden = true
        imageView.image = nil
        videoView.playerLayer.player = player
        videoView.isHidden = false
        fadeInIfNeeded(duration: fadeDuration)
    }

    /// Keeps audio-only playback off the video layer so the next video starts
    /// from a stable black canvas with its own aspect ratio.
    func showAudio(fadeDuration: Double = 0) {
        displayGeneration += 1
        titleLabel.isHidden = true
        imageView.isHidden = true
        imageView.image = nil
        videoView.playerLayer.player = nil
        videoView.isHidden = true
        audioNameLabel.isHidden = true
        audioProgress.isHidden = true
        fadeInIfNeeded(duration: fadeDuration)
    }

    func showAudio(name: String, fadeDuration: Double = 0) {
        displayGeneration += 1
        titleLabel.isHidden = true
        imageView.isHidden = true
        imageView.image = nil
        videoView.playerLayer.player = nil
        videoView.isHidden = true
        audioNameLabel.stringValue = name
        audioNameLabel.isHidden = true
        audioProgress.doubleValue = 0
        audioProgress.isHidden = false
        fadeInIfNeeded(duration: fadeDuration)
    }

    func updateAudioProgress(_ progress: Double) {
        audioProgress.doubleValue = max(0, min(1, progress))
    }

    /// Blackout: end of playback / explicit stop.
    func showBlack() {
        showBlack(animatedDuration: 0)
    }

    func showBlack(animatedDuration duration: Double) {
        displayGeneration += 1
        let generation = displayGeneration
        guard duration > 0 else {
            titleLabel.isHidden = true
            audioNameLabel.isHidden = true
            audioProgress.isHidden = true
            imageView.isHidden = true
            imageView.image = nil
            videoView.playerLayer.player = nil
            videoView.isHidden = true
            layer?.removeAnimation(forKey: "mediaFadeOut")
            layer?.opacity = 1
            alphaValue = 1
            return
        }

        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1
        animation.toValue = 0
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer?.add(animation, forKey: "mediaFadeOut")
        layer?.opacity = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self = self else { return }
            guard self.displayGeneration == generation else { return }
            self.titleLabel.isHidden = true
            self.audioNameLabel.isHidden = true
            self.audioProgress.isHidden = true
            self.imageView.isHidden = true
            self.imageView.image = nil
            self.videoView.playerLayer.player = nil
            self.videoView.isHidden = true
            self.alphaValue = 1
                self.layer?.removeAnimation(forKey: "mediaFadeOut")
                self.layer?.opacity = 1
        }
    }

    private func fadeInIfNeeded(duration: Double) {
        guard duration > 0 else {
            layer?.removeAnimation(forKey: "mediaFadeIn")
            layer?.opacity = 1
            alphaValue = 1
            return
        }
        layer?.removeAnimation(forKey: "mediaFadeOut")
        layer?.opacity = 0
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 0
        animation.toValue = 1
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer?.add(animation, forKey: "mediaFadeIn")
        layer?.opacity = 1
        alphaValue = 1
    }
}
