//
//  SmartPlannerViewModel.swift
//  FocusFlow
//
//  Created by mustaahh on 14/4/26.
//


import Foundation
import Combine

@MainActor
final class SmartPlannerViewModel: ObservableObject {

    // MARK: - Published

    @Published var plannedSessions: [PlannedSession] = []
    @Published var isGenerating: Bool = false
    @Published var planDate: Date = Date()
    @Published var workStartHour: Int = 9   // 9:00 AM
    @Published var workEndHour: Int   = 18  // 6:00 PM

    // MARK: - Generate Plan

    /// Auto-schedules eligible tasks into Pomodoro blocks.
    func generatePlan(tasks: [FTask], settings: UserSettings) {
        isGenerating = true

        Task {
            let result = await buildSchedule(tasks: tasks, settings: settings)
            plannedSessions = result
            isGenerating = false
        }
    }

    // MARK: - Private schedule builder

    private func buildSchedule(tasks: [FTask], settings: UserSettings) async -> [PlannedSession] {
        // 1. Eligible tasks = incomplete + due today or high-priority
        let cal = Calendar.current
        let targetDay = cal.startOfDay(for: planDate)

        var eligible = tasks.filter { task in
            guard !task.isCompleted else { return false }
            if let due = task.dueDate, cal.isDate(due, inSameDayAs: planDate) { return true }
            if task.priority == .high || task.priority == .medium { return true }
            return false
        }

        // 2. Sort: high priority first, then medium, then by due date
        eligible.sort { lhs, rhs in
            if lhs.priority.rawValue != rhs.priority.rawValue {
                return lhs.priority.rawValue > rhs.priority.rawValue
            }
            switch (lhs.dueDate, rhs.dueDate) {
            case (.some(let d1), .some(let d2)): return d1 < d2
            case (.some, .none): return true
            case (.none, .some): return false
            default: return lhs.createdAt < rhs.createdAt
            }
        }

        // 3. Build slots
        let pomodoroSecs = settings.pomodoroMinutes * 60
        let shortBreakSecs = settings.shortBreakMinutes * 60
        let sessionsUntilLong = settings.sessionsUntilLongBreak
        let longBreakSecs = settings.longBreakMinutes * 60

        // Determine start time
        let now = Date()
        var cursor: Date = {
            let workStart = cal.date(bySettingHour: workStartHour, minute: 0, second: 0, of: planDate)!
            if cal.isDateInToday(planDate) && now > workStart {
                // Round up to next 5-min boundary
                let mins = cal.component(.minute, from: now)
                let rounded = ((mins / 5) + 1) * 5
                return cal.date(byAdding: .minute, value: rounded - mins, to: now) ?? now
            }
            return workStart
        }()

        let workEnd = cal.date(bySettingHour: workEndHour, minute: 0, second: 0, of: planDate)!

        var sessions: [PlannedSession] = []
        var pomodoroCount = 0

        for task in eligible {
            let pomodoros = max(1, task.estimatedPomodoros - task.completedPomodoros)

            for i in 0..<pomodoros {
                // Check we haven't exceeded work hours
                let sessionEnd = cursor.addingTimeInterval(TimeInterval(pomodoroSecs))
                guard sessionEnd <= workEnd else { break }

                let session = PlannedSession(
                    taskId:             task.id,
                    taskTitle:          task.title,
                    estimatedPomodoros: pomodoros,
                    pomodoroMinutes:    settings.pomodoroMinutes,
                    scheduledStart:     cursor,
                    scheduledEnd:       sessionEnd,
                    priority:           task.priority
                )
                sessions.append(session)
                pomodoroCount += 1

                // Advance cursor past the session + break
                cursor = sessionEnd
                let isLastOfTask = (i == pomodoros - 1)

                if !isLastOfTask || pomodoroCount % sessionsUntilLong == 0 {
                    let breakDuration = (pomodoroCount % sessionsUntilLong == 0)
                        ? longBreakSecs : shortBreakSecs
                    cursor = cursor.addingTimeInterval(TimeInterval(breakDuration))
                } else {
                    // 5-min gap between tasks
                    cursor = cursor.addingTimeInterval(300)
                }
            }
        }

        return sessions
    }

    // MARK: - Mark Complete

    func markComplete(session: PlannedSession) {
        guard let idx = plannedSessions.firstIndex(where: { $0.id == session.id }) else { return }
        plannedSessions[idx].isCompleted = true
    }

    func toggleComplete(_ session: PlannedSession) {
        guard let idx = plannedSessions.firstIndex(where: { $0.id == session.id }) else { return }
        plannedSessions[idx].isCompleted.toggle()
    }

    // MARK: - Computed helpers

    var completedCount: Int { plannedSessions.filter { $0.isCompleted }.count }
    var totalCount: Int { plannedSessions.count }

    var completionPercentage: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var totalFocusMinutes: Int {
        plannedSessions.reduce(0) { $0 + $1.pomodoroMinutes }
    }

    var estimatedEndTime: Date? {
        plannedSessions.last?.scheduledEnd
    }

    var planSummary: String {
        guard !plannedSessions.isEmpty else { return "No sessions scheduled." }
        let tasks = Set(plannedSessions.compactMap { $0.taskId }).count
        return "\(plannedSessions.count) sessions · \(tasks) tasks · \(totalFocusMinutes) min focus"
    }
}
