// UserSettings.swift
import Foundation
import FirebaseFirestore

struct UserSettings: Codable {
    var pomodoroMinutes: Int = 25
    var shortBreakMinutes: Int = 5
    var longBreakMinutes: Int = 15
    var sessionsUntilLongBreak: Int = 4
    var autoStartBreaks: Bool = false
    var autoStartPomodoros: Bool = false
    var continuousMode: Bool = false
    var notifyBeforeEndSeconds: Int = 60   // alert 1 min before end
    var vibrationEnabled: Bool = true
    var soundEnabled: Bool = true
    var alarmSoundName: String = "bell"
    var selectedWhiteNoise: String? = nil  // freesound ID or local name
    var whiteNoiseVolume: Float = 0.5
    var dailyGoalPomodoros: Int = 8
    var theme: String = "dark"            // "dark" / "light"
}
