import Cocoa
import AVFoundation

protocol PlaybackEngineDelegate: AnyObject {
    /// Fired whenever the playing/paused state of `index` changes (including becoming nil/stopped).
    func playbackEngine(_ engine: PlaybackEngine, didUpdateIndex index: Int?)
}

/// Single-stream playback state machine: only one media item can be
/// loaded/playing at a time. Video/audio end naturally into a blackout;
/// images and paused videos stay on a freeze frame until relaunched.
final class PlaybackEngine: NSObject {
    weak var previewView: PreviewView?
    weak var delegate: PlaybackEngineDelegate?

    private(set) var playingIndex: Int?
    private(set) var isPlaying = false

    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?

    /// Click on a row's PLAY/STOP button, or SPACE on the selected row.
    func toggle(item: MediaItem, at index: Int) {
        if playingIndex == index {
            if item.type == .image {
                stop()
            } else {
                togglePause()
            }
        } else {
            start(item: item, at: index)
        }
    }

    private func start(item: MediaItem, at index: Int) {
        stop()
        playingIndex = index

        switch item.type {
        case .image:
            guard let image = NSImage(contentsOf: item.url) else { return }
            previewView?.showImage(image)
            isPlaying = true

        case .video, .audio:
            let newPlayer = AVPlayer(url: item.url)
            player = newPlayer
            previewView?.showVideo(player: newPlayer)
            observeEnd(of: newPlayer, index: index)
            newPlayer.play()
            isPlaying = true
        }

        delegate?.playbackEngine(self, didUpdateIndex: index)
    }

    private func togglePause() {
        guard let player = player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
        delegate?.playbackEngine(self, didUpdateIndex: playingIndex)
    }

    /// Stops playback and blacks out the preview. Freeze frame (paused video) is
    /// preserved by AVPlayer.pause() naturally; this is the explicit stop/end path.
    func stop() {
        if let endObserver = endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        player?.pause()
        player = nil
        previewView?.showBlack()

        let previous = playingIndex
        playingIndex = nil
        isPlaying = false
        if previous != nil {
            delegate?.playbackEngine(self, didUpdateIndex: previous)
        }
    }

    private func observeEnd(of player: AVPlayer, index: Int) {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.stop()
        }
    }
}
