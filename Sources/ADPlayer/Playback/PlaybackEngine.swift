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
    private static let titleFadeDuration = 0.5
    weak var previewView: PreviewView?
    weak var delegate: PlaybackEngineDelegate?
    let settings = PlaybackSettings()

    /// When true, a video's filename is shown centered for 2s, then 1s of
    /// black, before the video itself starts playing.
    var showsTitleCardBeforePlayback = false {
        didSet { UserDefaults.standard.set(showsTitleCardBeforePlayback, forKey: "ADPlayer.showsTitleCardBeforePlayback") }
    }

    /// When true, standalone audio files and paired entries' audio track are
    /// gain-corrected toward -18 LUFS (see LoudnessCache).
    var loudnessNormalizationEnabled = false {
        didSet { UserDefaults.standard.set(loudnessNormalizationEnabled, forKey: "ADPlayer.loudnessNormalizationEnabled") }
    }

    private(set) var playingIndex: Int?
    private(set) var isPlaying = false

    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var timeObserverToken: Any?
    private var pendingPrerollWorkItem: DispatchWorkItem?
    private var playbackGeneration = 0
    private var videoReadyObservation: NSKeyValueObservation?
    private var startRequestGeneration = 0

    override init() {
        showsTitleCardBeforePlayback = UserDefaults.standard.bool(forKey: "ADPlayer.showsTitleCardBeforePlayback")
        loudnessNormalizationEnabled = UserDefaults.standard.bool(forKey: "ADPlayer.loudnessNormalizationEnabled")
        super.init()
    }

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

    /// Starts an entry explicitly, without interpreting the request as pause/resume.
    func play(entry: PlaylistEntry, at index: Int) {
        start(entry: entry, at: index)
    }

    private func start(entry: PlaylistEntry, at index: Int) {
        startRequestGeneration += 1
        let requestGeneration = startRequestGeneration
        if playingIndex != nil || pendingPrerollWorkItem != nil {
            stop { [weak self] in
                guard let self = self, self.startRequestGeneration == requestGeneration else { return }
                self.beginStart(entry: entry, at: index)
            }
            return
        }
        guard startRequestGeneration == requestGeneration else { return }
        beginStart(entry: entry, at: index)
    }

    private func beginStart(entry: PlaylistEntry, at index: Int) {
        playingIndex = index
        delegate?.playbackEngine(self, didUpdateIndex: index)

        if shouldShowTitleBeforePlayback(for: entry) {
            isPlaying = true
            previewView?.showTitleCard(entry.displayName, fadeDuration: Self.titleFadeDuration)

            let afterBlack = DispatchWorkItem { [weak self] in
                self?.beginActualPlayback(entry: entry, index: index)
            }
            let blackDuration = settings.blackDuration
            let afterTitle = DispatchWorkItem { [weak self] in
                self?.previewView?.showBlack(animatedDuration: Self.titleFadeDuration)
                self?.pendingPrerollWorkItem = afterBlack
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + Self.titleFadeDuration + blackDuration,
                    execute: afterBlack
                )
            }
            pendingPrerollWorkItem = afterTitle
            DispatchQueue.main.asyncAfter(deadline: .now() + settings.titleDuration, execute: afterTitle)
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

    private func shouldShowTitleBeforePlayback(for entry: PlaylistEntry) -> Bool {
        if showsVideoTrack(entry) {
            return showsTitleCardBeforePlayback
        }
        if showsTitleCardBeforePlayback, case .single(let item) = entry, item.type == .audio {
            return settings.showAudioTitle
        }
        return false
    }

    private func beginActualPlayback(entry: PlaylistEntry, index: Int) {
        playbackGeneration += 1
        let generation = playbackGeneration
        switch entry {
        case .single(let item):
            switch item.type {
            case .image:
                guard let image = NSImage(contentsOf: item.url) else { return }
                previewView?.showImage(image, fadeDuration: settings.fadeDuration)
                isPlaying = true

            case .audio:
                let asset = AVURLAsset(url: item.url)
                let playerItem = AVPlayerItem(asset: asset)
                applyLoudnessCorrection(to: playerItem, asset: asset, sourceURL: item.url)
                let newPlayer = AVPlayer(playerItem: playerItem)
                player = newPlayer
                previewView?.showAudio(name: item.displayName, fadeDuration: settings.fadeDuration)
                observeEnd(of: newPlayer, index: index)
                observeProgress(of: newPlayer, index: index)
                rampVolumeIn(newPlayer, generation: generation)
                newPlayer.play()
                isPlaying = true

            case .video:
                let asset = AVURLAsset(url: item.url)
                let playerItem = AVPlayerItem(asset: asset)
                applyLoudnessCorrection(to: playerItem, asset: asset, sourceURL: item.url)
                let newPlayer = AVPlayer(playerItem: playerItem)
                player = newPlayer
                observeEnd(of: newPlayer, index: index)
                observeProgress(of: newPlayer, index: index)
                showVideoWhenReady(newPlayer, generation: generation)
                isPlaying = true
            }

        case .pairedVideoAudio(_, let videoURL, let audioURL):
            guard let composition = SyncedComposition.build(videoURL: videoURL, audioURL: audioURL) else { return }
            let playerItem = AVPlayerItem(asset: composition)
            applyLoudnessCorrection(to: playerItem, asset: composition, sourceURL: audioURL)
            let newPlayer = AVPlayer(playerItem: playerItem)
            player = newPlayer
            observeEnd(of: newPlayer, index: index)
            observeProgress(of: newPlayer, index: index)
            showVideoWhenReady(newPlayer, generation: generation)
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
        guard let track = asset.tracks(withMediaType: .audio).first else { return }
        let gainDB = loudnessNormalizationEnabled
            ? LoudnessCache.shared.gainDB(for: sourceURL, targetLUFS: settings.targetLUFS)
            : 0
        let duration = asset.duration.seconds.isFinite ? asset.duration.seconds : 0
        playerItem.audioMix = LoudnessAudioMix.make(
            for: track,
            gainDB: gainDB,
            fadeDuration: settings.fadeDuration,
            assetDuration: duration
        )
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

    private func showVideoWhenReady(_ player: AVPlayer, generation: Int) {
        guard let item = player.currentItem else {
            previewView?.showVideo(player: player, fadeDuration: settings.fadeDuration)
            rampVolumeIn(player, generation: generation)
            player.play()
            return
        }

        videoReadyObservation?.invalidate()
        videoReadyObservation = item.observe(\.status, options: [.initial, .new]) { [weak self, weak player] item, _ in
            guard let self = self, let player = player, item.status == .readyToPlay else { return }
            DispatchQueue.main.async {
                self.previewView?.showVideo(player: player, fadeDuration: self.settings.fadeDuration)
                self.rampVolumeIn(player, generation: generation)
                player.play()
                self.videoReadyObservation?.invalidate()
                self.videoReadyObservation = nil
            }
        }
    }

    /// Stops playback and blacks out the preview. Freeze frame (paused video) is
    /// preserved by AVPlayer.pause() naturally; this is the explicit stop/end path.
    func stop() {
        stop(completion: nil)
    }

    private func stop(completion: (() -> Void)?) {
        playbackGeneration += 1
        pendingPrerollWorkItem?.cancel()
        pendingPrerollWorkItem = nil
        videoReadyObservation?.invalidate()
        videoReadyObservation = nil

        if let endObserver = endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        if let oldPlayer = player {
            fadeOutAndPause(oldPlayer)
        }
        player = nil
        previewView?.showBlack(animatedDuration: settings.fadeDuration)

        let previous = playingIndex
        playingIndex = nil
        isPlaying = false
        if let previous = previous {
            delegate?.playbackEngine(self, didUpdateIndex: previous)
            delegate?.playbackEngine(self, didUpdateProgress: 0, for: previous)
        }

        guard let completion = completion else { return }
        let delay = settings.fadeDuration
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: completion)
        } else {
            completion()
        }
    }

    private func fadeOutAndPause(_ player: AVPlayer) {
        let fade = settings.fadeDuration
        guard fade > 0, player.timeControlStatus == .playing else {
            player.pause()
            return
        }

        if let item = player.currentItem,
           let track = item.asset.tracks(withMediaType: .audio).first {
            let start = item.currentTime().seconds
            let params = AVMutableAudioMixInputParameters(track: track)
            params.setVolumeRamp(
                fromStartVolume: 1,
                toEndVolume: 0,
                timeRange: CMTimeRange(
                    start: CMTime(seconds: max(0, start), preferredTimescale: 600),
                    duration: CMTime(seconds: fade, preferredTimescale: 600)
                )
            )
            let mix = AVMutableAudioMix()
            mix.inputParameters = [params]
            item.audioMix = mix
        }

        // Keep the video advancing while the visual fade-out is running.
        DispatchQueue.main.asyncAfter(deadline: .now() + fade) {
            player.pause()
        }
    }

    private func rampVolumeIn(_ player: AVPlayer, generation: Int) {
        let duration = settings.fadeDuration
        guard duration > 0 else {
            player.volume = 1
            return
        }

        player.volume = 0
        let steps = max(1, Int(ceil(duration * 20)))
        let interval = duration / Double(steps)
        for step in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(step)) { [weak self, weak player] in
                guard let self = self, let player = player,
                      self.playbackGeneration == generation else { return }
                player.volume = Float(step) / Float(steps)
            }
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
