import Foundation

/// A row in the playlist: either a single accepted media file, or a video+audio
/// pair sharing the same base name, merged so the video plays with the .wav/.mp3's
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

    /// Stable identity used to re-locate this entry after a playlist refresh.
    var identityKey: String {
        switch self {
        case .single(let item):
            return "single:\(item.url.path)"
        case .pairedVideoAudio(_, let videoURL, let audioURL):
            return "paired:\(videoURL.path)|\(audioURL.path)"
        }
    }

    /// Scans a folder, then merges any video (.mp4/.mov) with a .wav or .mp3 file
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
            let audio = group.first {
                let ext = $0.url.pathExtension.lowercased()
                return ext == "wav" || ext == "mp3"
            }

            if let video = video, let audio = audio {
                entries.append(.pairedVideoAudio(
                    name: video.url.deletingPathExtension().lastPathComponent,
                    videoURL: video.url,
                    audioURL: audio.url
                ))
                consumedURLs.insert(video.url)
                consumedURLs.insert(audio.url)
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
