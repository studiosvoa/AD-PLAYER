import AVFoundation

/// Builds the single-timeline composition shared by live playback and export:
/// the video's picture track plus the paired audio file's track, with the
/// video's own audio track left out entirely.
enum SyncedComposition {
    static func build(videoURL: URL, audioURL: URL) -> AVMutableComposition? {
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

        return composition
    }
}
