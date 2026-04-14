// ReportViewModel.swift
import Foundation
import Combine

struct DailyStat: Identifiable {
    let id = UUID()
    let date: Date
    let focusMinutes: Double
    let completedTasks: Int
    let pomodoroCount: Int
}

struct ProjectStat: Identifiable {
    let id = UUID()
    let projectName: String
    let colorHex: String
    let focusMinutes: Double
    let percentage: Double
}

@MainActor
class ReportViewModel: ObservableObject {
    @Published var sessions: [PomodoroSession] = []
    @Published var dailyStats: [DailyStat] = []
    @Published var projectStats: [ProjectStat] = []
    @Published var isLoading = false

    // Summary
    @Published var totalFocusMinutes: Double = 0
    @Published var totalPomodoros: Int = 0
    @Published var totalCompletedTasks: Int = 0
    @Published var currentStreak: Int = 0

    @Published var selectedPeriod: ReportPeriod = .week {
        didSet {
            Task { await computeStats() }
        }
    }

    private var uid: String? { AuthService.shared.uid }
    private var cancellables = Set<AnyCancellable>()
    private var allTasks: [FTask] = []
    private var allProjects: [Project] = []

    enum ReportPeriod: String, CaseIterable {
        case day = "Day", week = "Week", month = "Month"
    }

    // MARK: - Load
    func loadData(tasks: [FTask], projects: [Project]) {
        allTasks = tasks
        allProjects = projects
        guard let uid = uid else { return }

        if !sessions.isEmpty {
            Task { await computeStats() }
        }

        if cancellables.isEmpty {
            isLoading = true

            FirebaseService.shared.fetchAllSessions(uid: uid)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [weak self] _ in
                        self?.isLoading = false
                    },
                    receiveValue: { [weak self] sessions in
                        guard let self else { return }
                        self.sessions = sessions
                        self.isLoading = false
                        Task { await self.computeStats() }
                    }
                )
                .store(in: &cancellables)
        }
    }

    func computeStats(tasks: [FTask] = [], projects: [Project] = []) async {
        let t = tasks.isEmpty ? allTasks : tasks
        let p = projects.isEmpty ? allProjects : projects

        if !tasks.isEmpty {
            allTasks = tasks
        }

        if !projects.isEmpty {
            allProjects = projects
        }

        let now = Date()
        let (start, days) = periodRange(for: selectedPeriod, from: now)

        let filtered = sessions.filter {
            $0.startTime >= start && $0.startTime <= now && $0.type == .focus && $0.wasCompleted
        }

        // Daily stats
        var stats: [DailyStat] = []
        for i in 0..<days {
            guard let day = Calendar.current.date(byAdding: .day, value: -i, to: now.startOfDay) else { continue }
            let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: day)!
            let daySessions = filtered.filter { $0.startTime >= day && $0.startTime < dayEnd }
            let mins = daySessions.reduce(0.0) { $0 + $1.durationMinutes }
            let completed = t.filter { task in
                guard let completedAt = task.completedAt else { return false }
                return completedAt >= day && completedAt < dayEnd
            }.count
            stats.append(DailyStat(date: day, focusMinutes: mins, completedTasks: completed, pomodoroCount: daySessions.count))
        }
        dailyStats = stats.reversed()

        // Summary
        totalFocusMinutes = filtered.reduce(0.0) { $0 + $1.durationMinutes }
        totalPomodoros = filtered.count
        totalCompletedTasks = t.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= start
        }.count

        // Streak
        currentStreak = computeStreak(sessions: sessions)

        // Project stats
        var projMinutes: [String: Double] = [:]
        for s in filtered {
            let key = s.projectId ?? "none"
            projMinutes[key, default: 0] += s.durationMinutes
        }
        let total = projMinutes.values.reduce(0, +)
        projectStats = projMinutes.compactMap { (key, mins) -> ProjectStat? in
            let name = p.first { $0.id == key }?.name ?? (key == "none" ? "Uncategorized" : key)
            let color = p.first { $0.id == key }?.colorHex ?? "#888888"
            return ProjectStat(projectName: name, colorHex: color,
                               focusMinutes: mins, percentage: total > 0 ? mins / total : 0)
        }.sorted { $0.focusMinutes > $1.focusMinutes }
    }

    private func periodRange(for period: ReportPeriod, from date: Date) -> (Date, Int) {
        switch period {
        case .day: return (date.startOfDay, 1)
        case .week: return (Calendar.current.date(byAdding: .day, value: -6, to: date.startOfDay)!, 7)
        case .month: return (Calendar.current.date(byAdding: .day, value: -29, to: date.startOfDay)!, 30)
        }
    }

    private func computeStreak(sessions: [PomodoroSession]) -> Int {
        var streak = 0
        var checkDate = Date().startOfDay
        let focusDays = Set(sessions.filter { $0.type == .focus && $0.wasCompleted }
            .map { Calendar.current.startOfDay(for: $0.startTime) })
        while focusDays.contains(checkDate) {
            streak += 1
            checkDate = Calendar.current.date(byAdding: .day, value: -1, to: checkDate)!
        }
        return streak
    }
}
