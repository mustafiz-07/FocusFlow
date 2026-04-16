// Task.swift
import Foundation
import FirebaseFirestore

// MARK: - Priority
enum TaskPriority: Int, Codable, CaseIterable, Equatable {
    case none = 0, low = 1, medium = 2, high = 3

    var label: String {
        switch self { case .none: return "None"; case .low: return "Low"
            case .medium: return "Medium"; case .high: return "High" }
    }
    var color: String {
        switch self { case .none: return "gray"; case .low: return "blue"
            case .medium: return "orange"; case .high: return "red" }
    }
    var icon: String {
        switch self { case .none: return "minus"; case .low: return "chevron.down"
            case .medium: return "equal"; case .high: return "chevron.up" }
    }
}

// MARK: - SubTask
struct SubTask: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var title: String
    var isCompleted: Bool = false
}

// MARK: - RecurringRule
enum RecurringType: String, Codable, CaseIterable, Equatable {
    case none = "none"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case weekdays = "weekdays"
}

struct RecurringRule: Codable, Equatable {
    var type: RecurringType = .none
    var daysOfWeek: [Int]? = nil  // 1=Sun, 2=Mon ... 7=Sat
}

// MARK: - Task
struct FTask: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var title: String
    var note: String = ""
    var priority: TaskPriority = .none
    var isCompleted: Bool = false
    var dueDate: Date? = nil
    var reminderDate: Date? = nil
    var projectId: String? = nil
    var subTasks: [SubTask] = []
    var estimatedPomodoros: Int = 1
    var completedPomodoros: Int = 0
    var recurring: RecurringRule = RecurringRule()
    var createdAt: Date = Date()
    var completedAt: Date? = nil
    var tags: [String] = []
    var calendarEventIdentifier: String? = nil

    var completionPercentage: Double {
        guard !subTasks.isEmpty else { return isCompleted ? 1.0 : 0.0 }
        let done = subTasks.filter { $0.isCompleted }.count
        return Double(done) / Double(subTasks.count)
    }
}

// MARK: - Project
struct Project: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var name: String
    var colorHex: String = "#4A90E2"
    var icon: String = "folder.fill"
    var createdAt: Date = Date()
    var isArchived: Bool = false
}

// MARK: - Pomodoro Session
enum SessionType: String, Codable, Equatable {
    case focus = "focus"
    case shortBreak = "shortBreak"
    case longBreak = "longBreak"
}

struct PomodoroSession: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var taskId: String?
    var projectId: String?
    var type: SessionType = .focus
    var startTime: Date = Date()
    var endTime: Date? = nil
    var durationSeconds: Int = 0
    var wasCompleted: Bool = false

    var durationMinutes: Double { Double(durationSeconds) / 60.0 }
}
