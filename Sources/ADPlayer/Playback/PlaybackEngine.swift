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
    func toggle(entry: PlaylistEntry, at index: Int) {
        if playingIndex == index {
            if case .single(let item) = entry, item.type == .image {
                stop()
            } else {
                togglePause()
            }
        } else {
            start(entry: entry, at: index)
        }
    }

    private func start(entry: PlaylistEntry, at index: Int) {
        stop()
        playingIndex = index

        switch entry {
        case .single(let item):
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

        case .pairedVideoAudio(_, let videoURL, let audioURL):
            guard let newPlayer = Self.makeSyncedPlayer(videoURL: videoURL, audioURL: audioURL) else { return }
            player = newPlayer
            previewView?.showVideo(player: newPlayer)
            observeEnd(of: newPlayer, index: index)
            newPlayer.play()
            isPlaying = true
        }

        delegate?.playbackEngine(self, didUpdateIndex: index)
    }

    /// Builds a single-timeline player combining the video's picture track with
    /// the paired audio file's track (the video's own audio track is left out
    /// entirely), so the two are frame-accurately in sync from one play() call.
    private static func makeSyncedPlayer(videoURL: URL, audioURL: URL) -> AVPlayer? {
        let videoAsset = AVURLAsset(url: videoURL)
        let audioAsset = AVURLAsset(url: audioURL)
        guard let videoTrack = videoAsset.tracks(withMediaType: .video).first,
              let audioTrack = audioAsset.tracks(withMediaType: .audio).first else { return nil }

        let composition = AVMutableComposition()
        guard let compVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let compAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { return nil }

        let duration = min(videoAsset.duration, audioAsset.duration)
        let range = CMTimeRange(start: .zero, duration: duration)

        do {
            try compVideoTrack.insertTimeRange(range, of: videoTrack, at: .zero)
            try compAudioTrack.insertTimeRange(range, of: audioTrack, at: .zero)
        } catch {
            return nil
        }
        compVideoTrack.preferredTransform = videoTrack.preferredTransform

        return AVPlayer(playerItem: AVPlayerItem(asset: composition))
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
