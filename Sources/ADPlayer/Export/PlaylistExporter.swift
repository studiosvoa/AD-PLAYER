import AVFoundation

/// Batch-exports every paired (red-highlighted) video+audio entry of a playlist
/// into a single .mp4 file per entry, one at a time, into a chosen folder.
enum PlaylistExporter {
    final class CancellationToken {
        private let lock = NSLock()
        private var cancelled = false
        private weak var session: AVAssetExportSession?

        var isCancelled: Bool {
            lock.lock()
            defer { lock.unlock() }
            return cancelled
        }

        func setSession(_ session: AVAssetExportSession) {
            lock.lock()
            self.session = session
            let shouldCancel = cancelled
            lock.unlock()
            if shouldCancel { session.cancelExport() }
        }

        func cancel() {
            lock.lock()
            cancelled = true
            let session = self.session
            lock.unlock()
            session?.cancelExport()
        }
    }

    enum ExportError: LocalizedError {
        case compositionFailed
        case sessionCreationFailed

        var errorDescription: String? {
            switch self {
            case .compositionFailed: return "Impossible de composer la vidéo et l'audio."
            case .sessionCreationFailed: return "Impossible de créer la session d'export."
            }
        }
    }

    static func exportPairedEntries(
        _ entries: [PlaylistEntry],
        to folder: URL,
        loudnessNormalizationEnabled: Bool,
        targetLUFS: Double,
        progress: @escaping (_ name: String, _ completed: Int, _ total: Int, _ fraction: Double, _ error: Error?) -> Void,
        completion: @escaping () -> Void
    ) -> CancellationToken {
        let cancellationToken = CancellationToken()
        let paired: [(name: String, videoURL: URL, audioURL: URL)] = entries.compactMap {
            if case .pairedVideoAudio(let name, let videoURL, let audioURL) = $0 {
                return (name, videoURL, audioURL)
            }
            return nil
        }
        exportNext(
            paired,
            index: 0,
            folder: folder,
            loudnessNormalizationEnabled: loudnessNormalizationEnabled,
            targetLUFS: targetLUFS,
            cancellationToken: cancellationToken,
            progress: progress,
            completion: completion
        )
        return cancellationToken
    }

    private static func exportNext(
        _ items: [(name: String, videoURL: URL, audioURL: URL)],
        index: Int,
        folder: URL,
        loudnessNormalizationEnabled: Bool,
        targetLUFS: Double,
        cancellationToken: CancellationToken,
        progress: @escaping (String, Int, Int, Double, Error?) -> Void,
        completion: @escaping () -> Void
    ) {
        if cancellationToken.isCancelled {
            completion()
            return
        }
        guard index < items.count else {
            completion()
            return
        }
        let item = items[index]
        let outputURL = folder.appendingPathComponent(item.name).appendingPathExtension("mp4")
        func proceedToNext() {
            exportNext(
                items,
                index: index + 1,
                folder: folder,
                loudnessNormalizationEnabled: loudnessNormalizationEnabled,
                targetLUFS: targetLUFS,
                cancellationToken: cancellationToken,
                progress: progress,
                completion: completion
            )
        }

        guard let composition = SyncedComposition.build(videoURL: item.videoURL, audioURL: item.audioURL) else {
            progress(item.name, index, items.count, 1, ExportError.compositionFailed)
            proceedToNext()
            return
        }
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            progress(item.name, index, items.count, 1, ExportError.sessionCreationFailed)
            proceedToNext()
            return
        }
        session.outputURL = outputURL
        session.outputFileType = .mp4
        session.videoComposition = make25FPSVideoComposition(for: composition)
        cancellationToken.setSession(session)

        if loudnessNormalizationEnabled, let audioTrack = composition.tracks(withMediaType: .audio).first {
            let gainDB = LoudnessCache.shared.gainDB(for: item.audioURL, targetLUFS: targetLUFS)
            session.audioMix = LoudnessAudioMix.make(for: audioTrack, gainDB: gainDB)
        }

        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            progress(item.name, index, items.count, Double(session.progress), nil)
        }

        session.exportAsynchronously {
            let error: Error? = (session.status == .completed) ? nil : (session.error ?? ExportError.sessionCreationFailed)
            DispatchQueue.main.async {
                progressTimer.invalidate()
                progress(item.name, index + 1, items.count, 1, error)
                proceedToNext()
            }
        }
    }

    private static func make25FPSVideoComposition(for composition: AVMutableComposition) -> AVMutableVideoComposition? {
        guard let videoTrack = composition.tracks(withMediaType: .video).first else { return nil }

        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = CMTime(value: 1, timescale: 25)

        var transform = videoTrack.preferredTransform
        let naturalSize = videoTrack.naturalSize
        let initialRect = CGRect(origin: .zero, size: naturalSize).applying(transform)
        transform.tx -= initialRect.minX
        transform.ty -= initialRect.minY
        let transformedRect = CGRect(origin: .zero, size: naturalSize).applying(transform)
        videoComposition.renderSize = CGSize(
            width: abs(transformedRect.width),
            height: abs(transformedRect.height)
        )

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(transform, at: .zero)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        return videoComposition
    }
}
