import AVFoundation

/// Builds the AVAudioMix that applies a loudness-correction gain to one track,
/// shared by live playback and export so both hear/render the same correction.
enum LoudnessAudioMix {
    static func make(for track: AVAssetTrack, gainDB: Double) -> AVAudioMix? {
        guard gainDB != 0 else { return nil }
        let params = AVMutableAudioMixInputParameters(track: track)
        params.setVolume(Float(pow(10.0, gainDB / 20.0)), at: .zero)
        let mix = AVMutableAudioMix()
        mix.inputParameters = [params]
        return mix
    }

    static func make(for track: AVAssetTrack, gainDB: Double, fadeDuration: Double, assetDuration: Double) -> AVAudioMix? {
        let baseVolume = Float(pow(10.0, gainDB / 20.0))
        let params = AVMutableAudioMixInputParameters(track: track)
        let duration = max(0, assetDuration)
        let fade = min(max(0, fadeDuration), duration / 2)

        if fade > 0 {
            params.setVolumeRamp(fromStartVolume: 0, toEndVolume: baseVolume,
                                 timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: fade, preferredTimescale: 600)))
            if duration > 0 {
                let fadeStart = max(0, duration - fade)
                params.setVolumeRamp(fromStartVolume: baseVolume, toEndVolume: 0,
                                     timeRange: CMTimeRange(start: CMTime(seconds: fadeStart, preferredTimescale: 600),
                                                            duration: CMTime(seconds: fade, preferredTimescale: 600)))
            }
        } else {
            params.setVolume(baseVolume, at: .zero)
        }

        let mix = AVMutableAudioMix()
        mix.inputParameters = [params]
        return mix
    }
}
