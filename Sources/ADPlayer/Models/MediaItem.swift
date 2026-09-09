import Foundation

enum MediaType {
    case video
    case audio
    case image
}

struct MediaItem: Equatable {
    let url: URL
    let type: MediaType

    var displayName: String { url.lastPathComponent }

    /// Extensions accepted by the player.
    static let allowedExtensions: Set<String> = ["mp4", "mov", "wav", "mp3", "jpg", "jpeg", "png"]

    init?(url: URL) {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "mp4", "mov":
            type = .video
        case "wav", "mp3":
            type = .audio
        case "jpg", "jpeg", "png":
            type = .image
        default:
            return nil
        }
        self.url = url
    }

    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool {
        lhs.url == rhs.url
    }

    /// Scans a folder (non-recursive) for accepted media, sorted alphabetically by file name.
    static func loadFolder(_ folderURL: URL) -> [MediaItem] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return contents
            .compactMap(MediaItem.init(url:))
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }
}
