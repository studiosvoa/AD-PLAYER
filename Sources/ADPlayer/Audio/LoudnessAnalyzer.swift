import AVFoundation

/// Simplified ITU-R BS.1770 integrated loudness measurement (K-weighting
/// pre-filter + absolute/relative gating), sufficient for mono/stereo audio
/// files used as ad soundtracks.
enum LoudnessAnalyzer {
    private static let sampleRate = 48000.0
    private static let blockSize = 19200 // 400ms @ 48kHz
    private static let hopSize = 4800    // 100ms @ 48kHz (75% overlap)

    static func integratedLUFS(of url: URL) -> Double? {
        guard let channels = readSamples48k(url: url) else { return nil }
        return integratedLoudness(channels: channels)
    }

    // MARK: - Decode + resample to 48kHz Float32 non-interleaved

    private static func readSamples48k(url: URL) -> [[Float]]? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let sourceFormat = file.processingFormat
        guard let targetFormat = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: min(sourceFormat.channelCount, 2)
        ) else { return nil }
        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else { return nil }

        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let inputBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount) else { return nil }
        guard (try? file.read(into: inputBuffer)) != nil else { return nil }

        let ratio = sampleRate / sourceFormat.sampleRate
        let outputCapacity = AVAudioFrameCount(Double(frameCount) * ratio) + 4096
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputCapacity) else { return nil }

        var suppliedInput = false
        var conversionError: NSError?
        let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            if suppliedInput {
                outStatus.pointee = .endOfStream
                return nil
            }
            suppliedInput = true
            outStatus.pointee = .haveData
            return inputBuffer
        }
        guard status != .error, conversionError == nil,
              let channelData = outputBuffer.floatChannelData else { return nil }

        let frameLength = Int(outputBuffer.frameLength)
        guard frameLength > 0 else { return nil }

        return (0..<Int(targetFormat.channelCount)).map { channel in
            Array(UnsafeBufferPointer(start: channelData[channel], count: frameLength))
        }
    }

    // MARK: - K-weighting (BS.1770 stage 1 + stage 2 biquads, 48kHz coefficients)

    private struct Biquad {
        let b0: Double, b1: Double, b2: Double, a1: Double, a2: Double
        var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

        mutating func process(_ x: Double) -> Double {
            let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1; x1 = x
            y2 = y1; y1 = y
            return y
        }
    }

    private static func kWeighted(_ samples: [Float]) -> [Double] {
        var stage1 = Biquad(b0: 1.53512485958697, b1: -2.69169618940638, b2: 1.19839281085285,
                             a1: -1.69065929318241, a2: 0.73248077421585)
        var stage2 = Biquad(b0: 1.0, b1: -2.0, b2: 1.0,
                             a1: -1.99004745483398, a2: 0.99007225036621)
        return samples.map { stage2.process(stage1.process(Double($0))) }
    }

    // MARK: - Gated integrated loudness (ITU-R BS.1770-4)

    private static func integratedLoudness(channels: [[Float]]) -> Double? {
        guard let frameCount = channels.first?.count, frameCount >= blockSize else { return nil }
        let weighted = channels.map(kWeighted)

        var blockLoudness: [Double] = []
        var blockMeanSquare: [Double] = []

        var start = 0
        while start + blockSize <= frameCount {
            var sumSquares = 0.0
            for channel in weighted {
                var sum = 0.0
                for i in start..<(start + blockSize) { sum += channel[i] * channel[i] }
                sumSquares += sum / Double(blockSize)
            }
            if sumSquares > 0 {
                blockLoudness.append(-0.691 + 10 * log10(sumSquares))
                blockMeanSquare.append(sumSquares)
            }
            start += hopSize
        }
        guard !blockMeanSquare.isEmpty else { return nil }

        let absoluteGated = zip(blockLoudness, blockMeanSquare).filter { $0.0 > -70 }
        guard !absoluteGated.isEmpty else { return nil }

        let ungatedMeanSquare = absoluteGated.map(\.1).reduce(0, +) / Double(absoluteGated.count)
        let relativeThreshold = -0.691 + 10 * log10(ungatedMeanSquare) - 10

        let relativeGated = absoluteGated.filter { $0.0 > relativeThreshold }
        guard !relativeGated.isEmpty else { return nil }

        let gatedMeanSquare = relativeGated.map(\.1).reduce(0, +) / Double(relativeGated.count)
        return -0.691 + 10 * log10(gatedMeanSquare)
    }
}
