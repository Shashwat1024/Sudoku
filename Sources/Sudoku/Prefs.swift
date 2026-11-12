import SwiftUI

/// UserDefaults keys for settings. Views read them with @AppStorage;
/// game logic reads them through the helpers below.
enum Pref {
    static let haptics = "pref.haptics"
    static let sounds = "pref.sounds"
    static let showMistakes = "pref.showMistakes"
    static let highlightSame = "pref.highlightSame"
    static let autoNotes = "pref.autoRemoveNotes"
    static let mistakeLimit = "pref.mistakeLimit"
    static let theme = "pref.theme"
    static let glass = "pref.glass"

    static func bool(_ key: String, _ fallback: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? fallback
    }

    static func int(_ key: String, _ fallback: Int) -> Int {
        UserDefaults.standard.object(forKey: key) as? Int ?? fallback
    }
}

func formatTime(_ seconds: Int?) -> String {
    guard let s = seconds else { return "–" }
    if s >= 3600 {
        return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
    return String(format: "%d:%02d", s / 60, s % 60)
}
