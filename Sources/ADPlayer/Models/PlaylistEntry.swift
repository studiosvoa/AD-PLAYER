import Foundation

/// A row in the playlist: either a single accepted media file, or a video+WAV
/// pair sharing the same base name, merged so the video plays with the WAV's
/// audio instead of its own soundtrack (in sync, on a single timeline).
enum PlaylistEntry {
    case single(MediaItem)
    case pairedVideoAudio(name: String, videoURL: URL, audioURL: URL)

    /// Paired entries show only the base name, without extension.
    var displayName: String {
        switch self {
        case .single(let item):
            return item.displayName
        case .pairedVideoAudio(let name, _, _):
            return name
        }
    }

    var isPaired: Bool {
        if case .pairedVideoAudio = self { return true }
        return false
    }

    /// Scans a folder, then merges any video (.mp4/.mov) with a .wav file
    /// sharing the same base name into a single paired entry.
    static func buildEntries(fromFolder folderURL: URL) -> [PlaylistEntry] {
        let items = MediaItem.loadFolder(folderURL)

        var groupsByBaseName: [String: [MediaItem]] = [:]
        for item in items {
            let base = item.url.deletingPathExtension().lastPathComponent.lowercased()
            groupsByBaseName[base, default: []].append(item)
        }

        var consumedURLs = Set<URL>()
        var entries: [PlaylistEntry] = []

        for item in items {
            if consumedURLs.contains(item.url) { continue }

            let base = item.url.deletingPathExtension().lastPathComponent.lowercased()
            let group = groupsByBaseName[base] ?? [item]
            let video = group.first { $0.type == .video }
            let wav = group.first { $0.url.pathExtension.lowercased() == "wav" }

            if let video = video, let wav = wav {
                entries.append(.pairedVideoAudio(
                    name: video.url.deletingPathExtension().lastPathComponent,
                    videoURL: video.url,
                    audioURL: wav.url
                ))
                consumedURLs.insert(video.url)
                consumedURLs.insert(wav.url)
            } else {
                entries.append(.single(item))
                consumedURLs.insert(item.url)
            }
        }

        return entries.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }
}
