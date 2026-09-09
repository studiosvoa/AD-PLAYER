import Foundation

/// Caches the integrated-LUFS-derived gain per audio file so repeated
/// playback/export doesn't re-analyze the same file every time.
final class LoudnessCache {
    static let shared = LoudnessCache()
    static let targetLUFS = -18.0
    private static let maxCorrectionDB = 12.0

    private var cache: [URL: Double] = [:]
    private let queue = DispatchQueue(label: "ad-player.loudness-cache")

    /// Gain in dB to reach -18 LUFS, rounded to the nearest whole dB
    /// (e.g. a -19 LUFS file gets +1 dB, a -17 LUFS file gets -1 dB).
    func gainDB(for url: URL) -> Double {
        queue.sync {
            if let cached = cache[url] { return cached }
            let gain: Double
            if let lufs = LoudnessAnalyzer.integratedLUFS(of: url) {
                let rawGain = (Self.targetLUFS - lufs).rounded()
                gain = max(-Self.maxCorrectionDB, min(Self.maxCorrectionDB, rawGain))
            } else {
                gain = 0
            }
            cache[url] = gain
            return gain
        }
    }
}
