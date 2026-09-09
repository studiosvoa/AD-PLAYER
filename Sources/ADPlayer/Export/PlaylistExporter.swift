import AVFoundation

/// Batch-exports every paired (red-highlighted) video+audio entry of a playlist
/// into a single .mp4 file per entry, one at a time, into a chosen folder.
enum PlaylistExporter {
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
        progress: @escaping (_ name: String, _ completed: Int, _ total: Int, _ error: Error?) -> Void,
        completion: @escaping () -> Void
    ) {
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
            progress: progress,
            completion: completion
        )
    }

    private static func exportNext(
        _ items: [(name: String, videoURL: URL, audioURL: URL)],
        index: Int,
        folder: URL,
        loudnessNormalizationEnabled: Bool,
        targetLUFS: Double,
        progress: @escaping (String, Int, Int, Error?) -> Void,
        completion: @escaping () -> Void
    ) {
        guard index < items.count else {
            completion()
            return
        }
        let item = items[index]
        let outputURL = folder.appendingPathComponent(item.name).appendingPathExtension("mp4")
        try? FileManager.default.removeItem(at: outputURL)

        func proceedToNext() {
            exportNext(
                items,
                index: index + 1,
                folder: folder,
                loudnessNormalizationEnabled: loudnessNormalizationEnabled,
                targetLUFS: targetLUFS,
                progress: progress,
                completion: completion
            )
        }

        guard let composition = SyncedComposition.build(videoURL: item.videoURL, audioURL: item.audioURL) else {
            progress(item.name, index + 1, items.count, ExportError.compositionFailed)
            proceedToNext()
            return
        }
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            progress(item.name, index + 1, items.count, ExportError.sessionCreationFailed)
            proceedToNext()
            return
        }
        session.outputURL = outputURL
        session.outputFileType = .mp4

        if loudnessNormalizationEnabled, let audioTrack = composition.tracks(withMediaType: .audio).first {
            let gainDB = LoudnessCache.shared.gainDB(for: item.audioURL, targetLUFS: targetLUFS)
            session.audioMix = LoudnessAudioMix.make(for: audioTrack, gainDB: gainDB)
        }

        session.exportAsynchronously {
            let error: Error? = (session.status == .completed) ? nil : (session.error ?? ExportError.sessionCreationFailed)
            DispatchQueue.main.async {
                progress(item.name, index + 1, items.count, error)
                proceedToNext()
            }
        }
    }
}
