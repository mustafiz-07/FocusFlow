// Constants.swift
import Foundation

enum AppConstants {

    // ── Freesound API Credentials ─────────────────────────────
    // Project: FocusFlow
    static let freesoundAPIKey    = "2z0mCF98pC0pLi74TmEuJUjO4YNfkWEgw9CoiNVG"
    static let freesoundClientID  = "vNVR4yscmS2JMiQxZB9X"
    static let freesoundCallbackURL = "http://localhost/callback"
    static let freesoundBaseURL   = "https://freesound.org/apiv2"
    static let freesoundOAuthURL  = "https://freesound.org/apiv2/oauth2/authorize/"
    static let freesoundTokenURL  = "https://freesound.org/apiv2/oauth2/access_token/"

    // ── Firestore Collection Paths ────────────────────────────
    enum FirestorePath {
        static let users = "users"
        static func tasks(uid: String) -> String    { "users/\(uid)/tasks" }
        static func projects(uid: String) -> String { "users/\(uid)/projects" }
        static func sessions(uid: String) -> String { "users/\(uid)/sessions" }
        static func settings(uid: String) -> String { "users/\(uid)/settings" }
    }

    // ── Notification IDs ──────────────────────────────────────
    enum NotificationID {
        static let pomodoroEnd     = "pomodoro_end"
        static let pomodoroWarning = "pomodoro_warning"
        static let pomodoroExitReminder = "pomodoro_exit_reminder"
        static let taskReminder    = "task_reminder_"
    }

    // ── Local White Noise Sounds ──────────────────────────────
    // Drop these .mp3 files into your Xcode project (target: FocusFlow)
    static let localSounds: [WhiteNoiseSound] = [
        WhiteNoiseSound(id: "rain",        name: "Rain",         icon: "cloud.rain.fill",       isLocal: true, category: .rain),
        WhiteNoiseSound(id: "forest",      name: "Forest",       icon: "leaf.fill",             isLocal: true, category: .nature),
        WhiteNoiseSound(id: "cafe",        name: "Coffee Shop",  icon: "cup.and.saucer.fill",   isLocal: true, category: .cafe),
        WhiteNoiseSound(id: "fire",        name: "Fireplace",    icon: "flame.fill",            isLocal: true, category: .fire),
        WhiteNoiseSound(id: "ocean",       name: "Ocean Waves",  icon: "water.waves",           isLocal: true, category: .ocean),
        WhiteNoiseSound(id: "white_noise", name: "White Noise",  icon: "waveform",              isLocal: true, category: .noise),
        WhiteNoiseSound(id: "thunder",     name: "Thunderstorm", icon: "cloud.bolt.rain.fill",  isLocal: true, category: .rain),
        WhiteNoiseSound(id: "wind",        name: "Wind",         icon: "wind",                  isLocal: true, category: .nature),
    ]

    // ── Freesound Categories → search queries + icons ─────────
    static let freesoundCategories: [SoundCategory] = [
        SoundCategory(id: .rain,    label: "Rain",       icon: "cloud.rain.fill",      color: "#4A90E2",
                      queries: ["rain ambient loop",  "heavy rain relaxing",   "light rain peaceful"]),
        SoundCategory(id: .nature,  label: "Nature",     icon: "leaf.fill",            color: "#4AE27A",
                      queries: ["forest birds ambient","nature sounds peaceful","birds chirping morning"]),
        SoundCategory(id: .cafe,    label: "Café",       icon: "cup.and.saucer.fill",  color: "#C8924A",
                      queries: ["coffee shop ambient", "cafe background noise", "restaurant chatter"]),
        SoundCategory(id: .ocean,   label: "Ocean",      icon: "water.waves",          color: "#4AC8E2",
                      queries: ["ocean waves beach",   "sea waves relaxing",    "waves crashing shore"]),
        SoundCategory(id: .fire,    label: "Fire",       icon: "flame.fill",           color: "#E2774A",
                      queries: ["fireplace crackling", "campfire loop",         "fire burning ambient"]),
        SoundCategory(id: .noise,   label: "Noise",      icon: "waveform",             color: "#9B9B9B",
                      queries: ["white noise focus",   "brown noise sleep",     "pink noise ambient"]),
        SoundCategory(id: .wind,    label: "Wind",       icon: "wind",                 color: "#A0D8EF",
                      queries: ["wind ambient loop",   "gentle breeze outdoor", "wind through trees"]),
        SoundCategory(id: .city,    label: "City",       icon: "building.2.fill",      color: "#AE4AE2",
                      queries: ["city ambient noise",  "urban street sounds",   "city rain night"]),
        SoundCategory(id: .space,   label: "Space",      icon: "moon.stars.fill",      color: "#4A4AE2",
                      queries: ["space ambient music", "deep space drone",      "sci-fi ambient loop"]),
        SoundCategory(id: .thunder, label: "Thunder",    icon: "cloud.bolt.rain.fill", color: "#666699",
                      queries: ["thunder rain storm",  "thunderstorm ambient",  "storm lightning sound"]),
    ]
}

// MARK: - Sound Category enum
enum SoundCategoryID: String, Codable, CaseIterable {
    case rain, nature, cafe, ocean, fire, noise, wind, city, space, thunder
}

struct SoundCategory: Identifiable {
    var id: SoundCategoryID
    let label: String
    let icon: String
    let color: String
    let queries: [String]       // rotate through these for variety
}

// MARK: - WhiteNoiseSound model
struct WhiteNoiseSound: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let icon: String
    let isLocal: Bool
    var category: SoundCategoryID = .noise
    var streamURL: String?   = nil   // Freesound HQ preview URL
    var freesoundId: Int?    = nil
    var durationSeconds: Double = 0
    var authorName: String  = ""
    var isFavorite: Bool    = false
    var tags: [String]      = []

    // Custom Hashable/Equatable on id only
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: WhiteNoiseSound, rhs: WhiteNoiseSound) -> Bool { lhs.id == rhs.id }
}
