import Cocoa
import AVFoundation

protocol PlaybackEngineDelegate: AnyObject {
    /// Fired whenever the playing/paused state of `index` changes (including becoming nil/stopped).
    func playbackEngine(_ engine: PlaybackEngine, didUpdateIndex index: Int?)
    /// Fired as playback advances; `progress` is 0...1 (fraction of duration elapsed).
    func playbackEngine(_ engine: PlaybackEngine, didUpdateProgress progress: Double, for index: Int)
}

/// Single-stream playback state machine: only one media item can be
/// loaded/playing at a time. Video/audio end naturally into a blackout;
/// images and paused videos stay on a freeze frame until relaunched.
final class PlaybackEngine: NSObject {
    weak var previewView: PreviewView?
    weak var delegate: PlaybackEngineDelegate?

    /// When true, a video's filename is shown centered for 2s, then 1s of
    /// black, before the video itself starts playing.
    var showsTitleCardBeforePlayback = false

    /// When true, standalone audio files and paired entries' audio track are
    /// gain-corrected toward -18 LUFS (see LoudnessCache).
    var loudnessNormalizationEnabled = false

    private(set) var playingIndex: Int?
    private(set) var isPlaying = false

    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var timeObserverToken: Any?
    private var pendingPrerollWorkItem: DispatchWorkItem?

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
        delegate?.playbackEngine(self, didUpdateIndex: index)

        if showsTitleCardBeforePlayback && showsVideoTrack(entry) {
            isPlaying = true
            previewView?.showTitleCard(entry.displayName)

            let afterBlack = DispatchWorkItem { [weak self] in
                self?.beginActualPlayback(entry: entry, index: index)
            }
            let afterTitle = DispatchWorkItem { [weak self] in
                self?.previewView?.showBlack()
                self?.pendingPrerollWorkItem = afterBlack
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: afterBlack)
            }
            pendingPrerollWorkItem = afterTitle
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: afterTitle)
        } else {
            beginActualPlayback(entry: entry, index: index)
        }
    }

    private func showsVideoTrack(_ entry: PlaylistEntry) -> Bool {
        switch entry {
        case .single(let item): return item.type == .video
        case .pairedVideoAudio: return true
        }
    }

    private func beginActualPlayback(entry: PlaylistEntry, index: Int) {
        switch entry {
        case .single(let item):
            switch item.type {
            case .image:
                guard let image = NSImage(contentsOf: item.url) else { return }
                previewView?.showImage(image)
                isPlaying = true

            case .audio:
                let asset = AVURLAsset(url: item.url)
                let playerItem = AVPlayerItem(asset: asset)
                applyLoudnessCorrection(to: playerItem, asset: asset, sourceURL: item.url)
                let newPlayer = AVPlayer(playerItem: playerItem)
                player = newPlayer
                previewView?.showVideo(player: newPlayer)
                observeEnd(of: newPlayer, index: index)
                observeProgress(of: newPlayer, index: index)
                newPlayer.play()
                isPlaying = true

            case .video:
                let newPlayer = AVPlayer(url: item.url)
                player = newPlayer
                previewView?.showVideo(player: newPlayer)
                observeEnd(of: newPlayer, index: index)
                observeProgress(of: newPlayer, index: index)
                newPlayer.play()
                isPlaying = true
            }

        case .pairedVideoAudio(_, let videoURL, let audioURL):
            guard let composition = SyncedComposition.build(videoURL: videoURL, audioURL: audioURL) else { return }
            let playerItem = AVPlayerItem(asset: composition)
            applyLoudnessCorrection(to: playerItem, asset: composition, sourceURL: audioURL)
            let newPlayer = AVPlayer(playerItem: playerItem)
            player = newPlayer
            previewView?.showVideo(player: newPlayer)
            observeEnd(of: newPlayer, index: index)
            observeProgress(of: newPlayer, index: index)
            newPlayer.play()
            isPlaying = true
        }

        delegate?.playbackEngine(self, didUpdateIndex: index)
    }

    /// Re-associates the currently loaded item with its new row index after the
    /// playlist has been refreshed, without touching the player or its state.
    func remapPlayingIndex(to newIndex: Int?) {
        playingIndex = newIndex
    }

    /// Analyzes `sourceURL` (the .wav/.mp3 file) and, if normalization is on
    /// and a correction is needed, attaches the gain to the item's audio track.
    private func applyLoudnessCorrection(to playerItem: AVPlayerItem, asset: AVAsset, sourceURL: URL) {
        guard loudnessNormalizationEnabled, let track = asset.tracks(withMediaType: .audio).first else { return }
        let gainDB = LoudnessCache.shared.gainDB(for: sourceURL)
        playerItem.audioMix = LoudnessAudioMix.make(for: track, gainDB: gainDB)
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
        pendingPrerollWorkItem?.cancel()
        pendingPrerollWorkItem = nil

        if let endObserver = endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        player?.pause()
        player = nil
        previewView?.showBlack()

        let previous = playingIndex
        playingIndex = nil
        isPlaying = false
        if let previous = previous {
            delegate?.playbackEngine(self, didUpdateIndex: previous)
            delegate?.playbackEngine(self, didUpdateProgress: 0, for: previous)
        }
    }

    private func observeProgress(of player: AVPlayer, index: Int) {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, let duration = player.currentItem?.duration, duration.seconds > 0 else { return }
            let fraction = max(0, min(1, time.seconds / duration.seconds))
            self.delegate?.playbackEngine(self, didUpdateProgress: fraction, for: index)
        }
    }

    private func observeEnd(of player: AVPlayer, index: Int) {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.playbackEngine(self, didUpdateProgress: 1.0, for: index)
            self.stop()
        }
    }
}
