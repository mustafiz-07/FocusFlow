//
//  GamificationModel.swift
//  FocusFlow
//
//  Created by mustaahh on 14/4/26.
//
import Foundation
import FirebaseFirestore

// MARK: - Achievement Category

enum AchievementCategory: String, Codable, CaseIterable {
    case streak    = "streak"
    case focus     = "focus"
    case tasks     = "tasks"
    case social    = "social"
    case milestone = "milestone"

    var icon: String {
        switch self {
        case .streak:    return "flame.fill"
        case .focus:     return "timer"
        case .tasks:     return "checkmark.circle.fill"
        case .social:    return "person.2.fill"
        case .milestone: return "star.fill"
        }
    }

    var colorHex: String {
        switch self {
        case .streak:    return "#FF6B35"
        case .focus:     return "#F7931E"
        case .tasks:     return "#00C896"
        case .social:    return "#A855F7"
        case .milestone: return "#FFD700"
        }
    }

    var label: String { rawValue.capitalized }
}

// MARK: - Achievement Requirement

struct AchievementRequirement: Codable, Equatable {
    enum Kind: String, Codable { case streak, focusMinutes, pomodoroCount, tasksCompleted, joinedRoom, hostedRoom, reachLevel }
    let kind: Kind
    let value: Int

    static func streak(days: Int) -> Self       { .init(kind: .streak, value: days) }
    static func focusMinutes(_ m: Int) -> Self  { .init(kind: .focusMinutes, value: m) }
    static func pomodoroCount(_ c: Int) -> Self { .init(kind: .pomodoroCount, value: c) }
    static func tasksCompleted(_ c: Int) -> Self{ .init(kind: .tasksCompleted, value: c) }
    static func joinedRoom(count: Int) -> Self  { .init(kind: .joinedRoom, value: count) }
    static func hostedRoom(count: Int) -> Self  { .init(kind: .hostedRoom, value: count) }
    static func reachLevel(_ l: Int) -> Self    { .init(kind: .reachLevel, value: l) }
}

// MARK: - Achievement

struct Achievement: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let xpReward: Int
    let category: AchievementCategory
    let requirement: AchievementRequirement
    var isUnlocked: Bool = false
    var unlockedAt: Date? = nil

    // Evaluate whether progress meets requirement
    func isMet(by progress: UserProgress) -> Bool {
        let v = requirement.value
        switch requirement.kind {
        case .streak:        return progress.currentStreak >= v
        case .focusMinutes:  return progress.totalFocusMinutes >= v
        case .pomodoroCount: return progress.totalPomodoros >= v
        case .tasksCompleted:return progress.totalTasksCompleted >= v
        case .joinedRoom:    return progress.totalRoomsJoined >= v
        case .hostedRoom:    return progress.totalRoomsHosted >= v
        case .reachLevel:    return progress.level.level >= v
        }
    }

    // MARK: - All achievements catalog
    static let catalog: [Achievement] = [
        // Streak
        Achievement(id: "streak_3",   title: "On a Roll",         description: "3-day focus streak",    icon: "flame",               xpReward: 50,  category: .streak,    requirement: .streak(days: 3)),
        Achievement(id: "streak_7",   title: "Week Warrior",      description: "7-day focus streak",    icon: "flame.fill",          xpReward: 150, category: .streak,    requirement: .streak(days: 7)),
        Achievement(id: "streak_14",  title: "Fortnight Focus",   description: "14-day streak",         icon: "bolt.fill",           xpReward: 300, category: .streak,    requirement: .streak(days: 14)),
        Achievement(id: "streak_30",  title: "Iron Mind",         description: "30-day focus streak",   icon: "bolt.shield.fill",    xpReward: 750, category: .streak,    requirement: .streak(days: 30)),
        // Focus
        Achievement(id: "focus_1h",   title: "First Hour",        description: "Focus for 60 minutes",  icon: "clock.fill",          xpReward: 30,  category: .focus,     requirement: .focusMinutes(60)),
        Achievement(id: "focus_10h",  title: "Deep Work",         description: "10 total hours of focus",icon: "brain.head.profile", xpReward: 200, category: .focus,     requirement: .focusMinutes(600)),
        Achievement(id: "focus_50h",  title: "Flow State",        description: "50 total hours of focus",icon: "waveform.path",      xpReward: 600, category: .focus,     requirement: .focusMinutes(3000)),
        Achievement(id: "pomo_10",    title: "Pomodoro Starter",  description: "Complete 10 pomodoros", icon: "timer",               xpReward: 40,  category: .focus,     requirement: .pomodoroCount(10)),
        Achievement(id: "pomo_50",    title: "Pomodoro Pro",      description: "Complete 50 pomodoros", icon: "timer.circle.fill",   xpReward: 150, category: .focus,     requirement: .pomodoroCount(50)),
        Achievement(id: "pomo_100",   title: "Century Club",      description: "100 pomodoros done",    icon: "rosette",             xpReward: 400, category: .focus,     requirement: .pomodoroCount(100)),
        // Tasks
        Achievement(id: "tasks_5",    title: "Getting Started",   description: "Complete 5 tasks",      icon: "checkmark.circle",    xpReward: 20,  category: .tasks,     requirement: .tasksCompleted(5)),
        Achievement(id: "tasks_25",   title: "Getting Things Done",description: "Complete 25 tasks",    icon: "checkmark.seal",      xpReward: 100, category: .tasks,     requirement: .tasksCompleted(25)),
        Achievement(id: "tasks_100",  title: "Task Master",       description: "Complete 100 tasks",    icon: "checkmark.seal.fill", xpReward: 400, category: .tasks,     requirement: .tasksCompleted(100)),
        // Social
        Achievement(id: "social_join", title: "Study Buddy",              description: "Join a study room",     icon: "person.2.fill",       xpReward: 40,  category: .social,    requirement: .joinedRoom(count: 1)),
        Achievement(id: "social_5",   title: "Social Learner",    description: "Join 5 study rooms",    icon: "person.3.fill",       xpReward: 120, category: .social,    requirement: .joinedRoom(count: 5)),
        Achievement(id: "social_host",title: "Room Host",         description: "Host a study session",  icon: "person.badge.plus",   xpReward: 60,  category: .social,    requirement: .hostedRoom(count: 1)),
        // Milestone
        Achievement(id: "level_5",    title: "Rising Star",       description: "Reach level 5",         icon: "star.fill",           xpReward: 100, category: .milestone, requirement: .reachLevel(5)),
        Achievement(id: "level_10",   title: "Focused Force",     description: "Reach level 10",        icon: "star.circle.fill",    xpReward: 300, category: .milestone, requirement: .reachLevel(10)),
    ]
}

// MARK: - XP Level

struct XPLevel: Equatable {
    let level: Int
    let title: String
    let emoji: String
    let minXP: Int
    let maxXP: Int

    static let all: [XPLevel] = [
        XPLevel(level: 1,  title: "Beginner",     emoji: "🌱", minXP: 0,     maxXP: 150),
        XPLevel(level: 2,  title: "Focused",       emoji: "🌿", minXP: 150,   maxXP: 400),
        XPLevel(level: 3,  title: "Determined",    emoji: "🌳", minXP: 400,   maxXP: 800),
        XPLevel(level: 4,  title: "Achiever",      emoji: "⚡", minXP: 800,   maxXP: 1400),
        XPLevel(level: 5,  title: "Rising Star",   emoji: "⭐", minXP: 1400,  maxXP: 2200),
        XPLevel(level: 6,  title: "Scholar",       emoji: "📚", minXP: 2200,  maxXP: 3200),
        XPLevel(level: 7,  title: "Expert",        emoji: "🎯", minXP: 3200,  maxXP: 4500),
        XPLevel(level: 8,  title: "Master",        emoji: "🔥", minXP: 4500,  maxXP: 6000),
        XPLevel(level: 9,  title: "Elite",         emoji: "💎", minXP: 6000,  maxXP: 8000),
        XPLevel(level: 10, title: "Focused Force", emoji: "🏆", minXP: 8000,  maxXP: Int.max),
    ]

    static func current(for xp: Int) -> XPLevel {
        all.last(where: { xp >= $0.minXP }) ?? all[0]
    }
}

// MARK: - UserProgress

struct UserProgress: Codable, Equatable {
    var totalXP: Int = 0
    var totalPomodoros: Int = 0
    var totalFocusMinutes: Int = 0
    var totalTasksCompleted: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var totalRoomsJoined: Int = 0
    var totalRoomsHosted: Int = 0
    var unlockedAchievementIds: [String] = []
    var lastFocusDate: Date? = nil
    var coins: Int = 0

    // MARK: - Level helpers
    var level: XPLevel { XPLevel.current(for: totalXP) }

    var nextLevel: XPLevel? { XPLevel.all.first { $0.level == level.level + 1 } }

    var xpInCurrentLevel: Int { totalXP - level.minXP }

    var xpNeededForNextLevel: Int {
        guard let next = nextLevel else { return 1 }
        return next.minXP - level.minXP
    }

    var levelProgress: Double {
        guard xpNeededForNextLevel > 0 else { return 1.0 }
        return min(1.0, Double(xpInCurrentLevel) / Double(xpNeededForNextLevel))
    }

    // MARK: - XP earned for events
    static func xp(forFocusMinutes mins: Int) -> Int { mins * 2 }           // 25 min = 50 XP
    static func xp(forTaskCompleted priority: TaskPriority) -> Int {
        switch priority { case .high: return 30; case .medium: return 20; case .low: return 15; case .none: return 10 }
    }
    static func xp(forStreakDay streak: Int) -> Int { min(streak * 5, 100) } // bonus, capped 100
    static let xpForJoiningRoom: Int = 15
    static let xpForHostingRoom: Int = 25
}

// MARK: - Study Room

struct StudyRoom: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var name: String
    var hostUID: String
    var hostName: String
    var topic: String = ""
    var maxParticipants: Int = 10
    var timerDurationSeconds: Int = 1500
    var stateRaw: String = RoomState.waiting.rawValue
    var startedAt: Date? = nil
    var participants: [RoomParticipant] = []
    var focusSessionCount: Int = 0
    var createdAt: Date = Date()

    enum RoomState: String, Codable {
        case waiting, running, paused, ended
    }

    var roomState: RoomState { RoomState(rawValue: stateRaw) ?? .waiting }
    var participantCount: Int { participants.count }
    var isFull: Bool { participantCount >= maxParticipants }

    var elapsedSeconds: Int? {
        guard roomState == .running, let start = startedAt else { return nil }
        return Int(Date().timeIntervalSince(start))
    }

    var remainingSeconds: Int? {
        guard let elapsed = elapsedSeconds else { return nil }
        return max(0, timerDurationSeconds - elapsed)
    }
}

struct RoomParticipant: Identifiable, Codable, Equatable {
    var id: String        // = Firebase UID
    var displayName: String
    var joinedAt: Date = Date()
    var focusMinutes: Int = 0
    var isReady: Bool = false
    var avatarInitial: String { String(displayName.prefix(1)).uppercased() }
}

// MARK: - Leaderboard

struct LeaderboardEntry: Identifiable, Codable {
    @DocumentID var docId: String?
    var id: String { docId ?? UUID().uuidString }
    var uid: String = ""
    var displayName: String
    var weeklyMinutes: Int = 0
    var totalMinutes: Int = 0
    var currentStreak: Int = 0
    var levelNumber: Int = 1
    var avatarInitial: String { String(displayName.prefix(1)).uppercased() }
}

// MARK: - Planned Session (Smart Planner)

struct PlannedSession: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var taskId: String?
    var taskTitle: String
    var estimatedPomodoros: Int
    var pomodoroMinutes: Int
    var scheduledStart: Date
    var scheduledEnd: Date
    var priority: TaskPriority
    var isCompleted: Bool = false
    var calendarEventId: String? = nil

    var durationMinutes: Int {
        Int(scheduledEnd.timeIntervalSince(scheduledStart) / 60)
    }

    var timeRangeLabel: String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        return "\(fmt.string(from: scheduledStart)) – \(fmt.string(from: scheduledEnd))"
    }
}
