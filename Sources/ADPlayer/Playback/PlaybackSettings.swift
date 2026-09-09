import Foundation

extension Notification.Name {
    static let titleCardSettingChanged = Notification.Name("ADPlayer.titleCardSettingChanged")
}

enum AppAppearance: String, CaseIterable {
    case light = "Clair"
    case dark = "Sombre"
    case system = "Système"
}

final class PlaybackSettings {
    private let defaults = UserDefaults.standard

    var titleDuration: Double = 2.0 {
        didSet { defaults.set(titleDuration, forKey: "ADPlayer.titleDuration") }
    }
    var blackDuration: Double = 1.0 {
        didSet { defaults.set(blackDuration, forKey: "ADPlayer.blackDuration") }
    }
    var fadeDuration: Double = 0.0 {
        didSet { defaults.set(fadeDuration, forKey: "ADPlayer.fadeDuration") }
    }
    var targetLUFS: Double = -18.0 {
        didSet { defaults.set(targetLUFS, forKey: "ADPlayer.targetLUFS") }
    }
    var appearance: AppAppearance = .system {
        didSet { defaults.set(appearance.rawValue, forKey: "ADPlayer.appearance") }
    }
    var autoAdvanceToUnread = false {
        didSet { defaults.set(autoAdvanceToUnread, forKey: "ADPlayer.autoAdvanceToUnread") }
    }
    var autoPlayContinuous = false {
        didSet { defaults.set(autoPlayContinuous, forKey: "ADPlayer.autoPlayContinuous") }
    }
    var continuousSkipPlayed = true {
        didSet { defaults.set(continuousSkipPlayed, forKey: "ADPlayer.continuousSkipPlayed") }
    }
    var showAudioTitle = false {
        didSet { defaults.set(showAudioTitle, forKey: "ADPlayer.showAudioTitle") }
    }

    init() {
        let storedTitleDuration = defaults.object(forKey: "ADPlayer.titleDuration") as? Double ?? 2.0
        titleDuration = Swift.min(5.0, Swift.max(0.3, storedTitleDuration))
        blackDuration = defaults.object(forKey: "ADPlayer.blackDuration") as? Double ?? 1.0
        let storedFadeDuration = defaults.object(forKey: "ADPlayer.fadeDuration") as? Double ?? 0.0
        fadeDuration = Swift.min(2.0, Swift.max(0.0, storedFadeDuration))
        targetLUFS = defaults.object(forKey: "ADPlayer.targetLUFS") as? Double ?? -18.0
        if let rawAppearance = defaults.string(forKey: "ADPlayer.appearance"),
           let storedAppearance = AppAppearance(rawValue: rawAppearance) {
            appearance = storedAppearance
        }
        autoAdvanceToUnread = defaults.bool(forKey: "ADPlayer.autoAdvanceToUnread")
        autoPlayContinuous = defaults.bool(forKey: "ADPlayer.autoPlayContinuous")
        continuousSkipPlayed = defaults.object(forKey: "ADPlayer.continuousSkipPlayed") as? Bool ?? true
        showAudioTitle = defaults.bool(forKey: "ADPlayer.showAudioTitle")
    }
}
