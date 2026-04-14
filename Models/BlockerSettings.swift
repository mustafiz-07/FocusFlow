//
//  BlockerSettings.swift
//  FocusFlow
//
//  Created by mustaahh on 14/4/26.
//
import Foundation

// MARK: - BlockerSettings

struct BlockerSettings: Codable {

    // Master switches
    var isBlockerEnabled: Bool   = false
    var isStrictModeEnabled: Bool = false

    // Strict mode behaviour
    var strictExitDelaySeconds: Int = 10   // countdown before user can force-exit
    var exitPenaltyXP: Int          = 50   // XP deducted for abandoning in strict mode
    var showShameMessage: Bool      = true // show motivational guilt message

    // MARK: - UserDefaults persistence

    private static let key = "focusflow_blocker_settings"

    static func load() -> BlockerSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(BlockerSettings.self, from: data)
        else { return BlockerSettings() }
        return decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: BlockerSettings.key)
    }
}
