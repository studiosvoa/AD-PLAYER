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
}
