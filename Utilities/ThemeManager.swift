import SwiftUI
import Combine

@MainActor
final class ThemeManager: ObservableObject {
    private let storageKey = "focusflow_theme_preference"

    @Published var theme: String {
        didSet {
            UserDefaults.standard.set(theme, forKey: storageKey)
        }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: storageKey)
        theme = (saved == "light" || saved == "dark") ? (saved ?? "dark") : "dark"
    }

    var preferredColorScheme: ColorScheme? {
        theme == "light" ? .light : .dark
    }

    var isDarkMode: Bool {
        theme == "dark"
    }

    func apply(theme: String) {
        self.theme = (theme == "light") ? "light" : "dark"
    }
}
