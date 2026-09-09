import Foundation

/// Caches the integrated-LUFS-derived gain per audio file so repeated
/// playback/export doesn't re-analyze the same file every time.
final class LoudnessCache {
    static let shared = LoudnessCache()
    private static let maxCorrectionDB = 36.0

    private var cache: [String: Double] = [:]
    private let queue = DispatchQueue(label: "ad-player.loudness-cache")

    /// Gain in dB required to reach the selected LUFS target.
    func gainDB(for url: URL, targetLUFS: Double) -> Double {
        queue.sync {
            let cacheKey = "\(url.absoluteString)|\(targetLUFS)"
            if let cached = cache[cacheKey] { return cached }
            let gain: Double
            if let lufs = LoudnessAnalyzer.integratedLUFS(of: url) {
                let rawGain = targetLUFS - lufs
                gain = max(-Self.maxCorrectionDB, min(Self.maxCorrectionDB, rawGain))
            } else {
                gain = 0
            }
            cache[cacheKey] = gain
            return gain
        }
    }
}
