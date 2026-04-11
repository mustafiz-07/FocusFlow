// TaskViewModel.swift
import Foundation
import Combine
import EventKit

@MainActor
class TaskViewModel: ObservableObject {
    /// Set from MainTabView after initialisation so XP can be awarded
    var onTaskCompleted: ((TaskPriority) -> Void)? = nil
    @Published var tasks: [FTask] = []
    @Published var projects: [Project] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private var uid: String? { AuthService.shared.uid }
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Filtered views
    var todayTasks: [FTask] {
        tasks.filter { t in
            guard !t.isCompleted else { return false }
            if let due = t.dueDate { return Calendar.current.isDateInToday(due) }
            return false
        }
    }

    var activeTasks: [FTask] { tasks.filter { !$0.isCompleted } }
    var completedTasks: [FTask] { tasks.filter { $0.isCompleted } }

    func tasksForProject(_ projectId: String) -> [FTask] {
        tasks.filter { $0.projectId == projectId && !$0.isCompleted }
    }

    // MARK: - Load
    func loadData() {
        guard let uid = uid else { return }
        isLoading = true

        FirebaseService.shared.fetchTasks(uid: uid)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion { self?.errorMessage = error.localizedDescription }
            }, receiveValue: { [weak self] tasks in
                self?.tasks = tasks
                self?.isLoading = false
            })
            .store(in: &cancellables)

        FirebaseService.shared.fetchProjects(uid: uid)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] projects in
                self?.projects = projects
            })
            .store(in: &cancellables)
    }

    // MARK: - Add Task
    func addTask(_ task: FTask) async {
        guard let uid = uid else { return }
        do {
            let id = try await FirebaseService.shared.addTask(task, uid: uid)
            if task.reminderDate != nil {
                var t = task; t.id = id
                NotificationService.shared.scheduleTaskReminder(task: t)
            }
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Update Task
    func updateTask(_ task: FTask) async {
        guard let uid = uid else { return }
        do {
            try await FirebaseService.shared.updateTask(task, uid: uid)
            if let id = task.id {
                NotificationService.shared.cancelTaskReminder(taskId: id)
                if task.reminderDate != nil { NotificationService.shared.scheduleTaskReminder(task: task) }
            }
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Toggle Complete
    func toggleComplete(_ task: FTask) async {
        var updated = task
        updated.isCompleted.toggle()
        updated.completedAt = updated.isCompleted ? Date() : nil
        await updateTask(updated)
        // Notify gamification system
        if updated.isCompleted { onTaskCompleted?(updated.priority) }
    }

    // MARK: - Delete Task
    func deleteTask(_ task: FTask) async {
        guard let uid = uid, let id = task.id else { return }
        do {
            try await FirebaseService.shared.deleteTask(id: id, uid: uid)
            if let taskId = task.id { NotificationService.shared.cancelTaskReminder(taskId: taskId) }
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Projects
    func addProject(_ project: Project) async {
        guard let uid = uid else { return }
        _ = try? await FirebaseService.shared.addProject(project, uid: uid)
    }

    func deleteProject(_ project: Project) async {
        guard let uid = uid, let id = project.id else { return }
        try? await FirebaseService.shared.deleteProject(id: id, uid: uid)
    }

    // MARK: - Calendar Sync
    func syncCalendarEvents(_ events: [EKEvent], for date: Date) async {
        let calendar = Calendar.current
        let eventIds = Set(events.compactMap(\.eventIdentifier))

        for event in events {
            guard let eventId = event.eventIdentifier else { continue }

            let trimmedTitle = event.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let title = trimmedTitle.isEmpty ? "Calendar Event" : trimmedTitle
            let startDate = event.startDate
            let durationMinutes = max(event.durationMinutes, 1)
            let estimatedPomodoros = max(Int(ceil(Double(durationMinutes) / 25.0)), 1)
            let updatedNote = buildCalendarNote(for: event)

            if var existing = tasks.first(where: { $0.calendarEventIdentifier == eventId }) {
                if existing.title != title ||
                    existing.note != updatedNote ||
                    existing.dueDate != startDate ||
                    existing.estimatedPomodoros != estimatedPomodoros {
                    existing.title = title
                    existing.note = updatedNote
                    existing.dueDate = startDate
                    existing.estimatedPomodoros = estimatedPomodoros
                    await updateTask(existing)
                }
            } else {
                let task = FTask(
                    title: title,
                    note: updatedNote,
                    dueDate: startDate,
                    estimatedPomodoros: estimatedPomodoros,
                    tags: ["calendar"],
                    calendarEventIdentifier: eventId
                )
                await addTask(task)
            }
        }

        let staleTasks = tasks.filter { task in
            guard let eventId = task.calendarEventIdentifier else { return false }
            guard let dueDate = task.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: date) && !eventIds.contains(eventId)
        }

        for task in staleTasks {
            await deleteTask(task)
        }
    }

    private func buildCalendarNote(for event: EKEvent) -> String {
        var components: [String] = ["Synced from Calendar"]
        if let notes = event.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            components.append(notes)
        }
        return components.joined(separator: "\n\n")
    }

    func projectName(for id: String?) -> String {
        guard let id = id else { return "No Project" }
        return projects.first { $0.id == id }?.name ?? "Unknown"
    }

    func projectColor(for id: String?) -> String {
        guard let id = id else { return "#888888" }
        return projects.first { $0.id == id }?.colorHex ?? "#888888"
    }
}
