// TimerViewModel.swift
import Foundation
import Combine
import AVFoundation
import AudioToolbox
import os

enum TimerState { case idle, running, paused }

@MainActor
class TimerViewModel: ObservableObject {
    // ── Published State ───────────────────────────────────────
    @Published var state: TimerState = .idle
    @Published var sessionType: SessionType = .focus
    @Published var secondsRemaining: Int = 25 * 60
    @Published var totalSeconds: Int = 25 * 60
    @Published var completedSessionsCount: Int = 0
    @Published var selectedTask: FTask? = nil
    @Published var settings: UserSettings = UserSettings()
    @Published var showBreakSkipAlert = false
    @Published var isContinuousMode = false
    @Published var lastSessionSaveError: String? = nil
    @Published var pendingSessionCount: Int = 0

    // ── Session tracking ──────────────────────────────────────
    private var sessionStartTime: Date? = nil
    private var currentSession: PomodoroSession? = nil
    private var uid: String? { AuthService.shared.uid }

    // ── Timer ─────────────────────────────────────────────────
    private var timer: AnyCancellable? = nil
    private var backgroundDate: Date? = nil
    private var notificationScheduled = false
    private let logger = Logger(subsystem: "FocusFlow", category: "TimerViewModel")

    // MARK: - Computed
    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - Double(secondsRemaining) / Double(totalSeconds)
    }

    var sessionLabel: String {
        switch sessionType {
        case .focus: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }

    // MARK: - Load Settings
    func loadSettings(_ s: UserSettings) {
        settings = s
        isContinuousMode = s.continuousMode
        if state == .idle { resetToCurrentSessionDuration() }
    }

    // MARK: - Start
    func start() {
        guard state != .running else { return }
        state = .running
        if sessionStartTime == nil { sessionStartTime = Date() }

        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }

        // Schedule notifications
        if !notificationScheduled {
            NotificationService.shared.cancelTimerNotifications()
            NotificationService.shared.scheduleTimerEndNotification(
                secondsFromNow: TimeInterval(secondsRemaining), sessionType: sessionType)
            NotificationService.shared.scheduleWarningNotification(secondsFromNow: TimeInterval(secondsRemaining))
            notificationScheduled = true
        }
    }

    // MARK: - Pause
    func pause() {
        guard state == .running else { return }
        state = .paused
        timer?.cancel(); timer = nil
        notificationScheduled = false
        NotificationService.shared.cancelTimerNotifications()
    }

    // MARK: - Resume
    func resume() { start() }

    // MARK: - Stop / Reset
    func stop() {
        pause()
        state = .idle
        resetToCurrentSessionDuration()
        sessionStartTime = nil
        currentSession = nil
    }

    // MARK: - Skip Break
    func skipBreak() {
        guard sessionType != .focus else { return }
        stop()
        sessionType = .focus
        resetToCurrentSessionDuration()
    }

    // MARK: - Tick
    private func tick() {
        guard secondsRemaining > 0 else {
            sessionCompleted()
            return
        }
        secondsRemaining -= 1
    }

    // MARK: - Session Completed
    private func sessionCompleted() {
        timer?.cancel(); timer = nil
        notificationScheduled = false

        let completedSessionType = sessionType
        let completedTask = selectedTask
        let completedStartTime = sessionStartTime
        let completedEndTime = Date()

        // Vibrate
        if settings.vibrationEnabled { AudioServicesPlaySystemSound(kSystemSoundID_Vibrate) }

        // Save session to Firestore
        Task {
            await saveCurrentSession(
                completed: true,
                sessionType: completedSessionType,
                task: completedTask,
                startTime: completedStartTime,
                endTime: completedEndTime
            )
        }

        if sessionType == .focus {
            completedSessionsCount += 1
            // Increment task pomodoro count
            if selectedTask != nil { Task { await incrementTaskPomodoro() } }
        }

        // Determine next session
        let nextType = determineNextSession()

        if isContinuousMode {
            sessionType = nextType
            resetToCurrentSessionDuration()
            sessionStartTime = Date()
            start()
        } else {
            state = .idle
            sessionType = nextType
            resetToCurrentSessionDuration()
            sessionStartTime = nil
            if sessionType != .focus {
                showBreakSkipAlert = true
            }
        }
    }

    private func determineNextSession() -> SessionType {
        if sessionType == .focus {
            if completedSessionsCount % settings.sessionsUntilLongBreak == 0 {
                return .longBreak
            }
            return .shortBreak
        }
        return .focus
    }

    private func resetToCurrentSessionDuration() {
        switch sessionType {
        case .focus:     secondsRemaining = settings.pomodoroMinutes * 60; totalSeconds = secondsRemaining
        case .shortBreak: secondsRemaining = settings.shortBreakMinutes * 60; totalSeconds = secondsRemaining
        case .longBreak: secondsRemaining = settings.longBreakMinutes * 60; totalSeconds = secondsRemaining
        }
    }

    // MARK: - Firestore
    private func saveCurrentSession(
        completed: Bool,
        sessionType: SessionType,
        task: FTask?,
        startTime: Date?,
        endTime: Date
    ) async {
        guard let uid = uid else {
            lastSessionSaveError = "Failed to persist session: missing authenticated user"
            logger.error("Session save skipped because uid was missing")
            return
        }

        guard let startTime else {
            lastSessionSaveError = "Failed to persist session: missing session start time"
            logger.error("Session save skipped because startTime was missing. uid: \\(uid, privacy: .private(mask: .hash))")
            return
        }

        let duration = max(Int(endTime.timeIntervalSince(startTime)), 1)
        let session = PomodoroSession(
            taskId: task?.id,
            projectId: task?.projectId,
            type: sessionType,
            startTime: startTime,
            endTime: endTime,
            durationSeconds: duration,
            wasCompleted: completed
        )

        let outcome = await SessionSyncService.shared.saveSessionOrQueue(session, uid: uid)
        pendingSessionCount = await SessionSyncService.shared.pendingCount(for: uid)

        switch outcome {
        case .synced:
            lastSessionSaveError = nil
            logger.info("Session saved successfully for uid: \(uid, privacy: .private(mask: .hash))")
        case .queued(let reason):
            lastSessionSaveError = "Session queued for retry: \(reason)"
            logger.error("Session queued due to save failure. uid: \(uid, privacy: .private(mask: .hash)), reason: \(reason, privacy: .public)")
        case .failed(let reason):
            lastSessionSaveError = "Failed to persist session: \(reason)"
            logger.fault("Session save failed without queue persistence. uid: \(uid, privacy: .private(mask: .hash)), reason: \(reason, privacy: .public)")
        }
    }

    private func incrementTaskPomodoro() async {
        guard var task = selectedTask, let uid = uid else { return }
        task.completedPomodoros += 1
        do {
            try await FirebaseService.shared.updateTask(task, uid: uid)
        } catch {
            logger.error("Unable to update task pomodoro count. uid: \(uid, privacy: .private(mask: .hash)), taskId: \(task.id ?? "none", privacy: .public), reason: \(error.localizedDescription, privacy: .public)")
        }
        selectedTask = task
    }

    // MARK: - Background handling
    func handleBackground() { backgroundDate = Date() }
    func handleForeground() {
        guard let bg = backgroundDate, state == .running else { backgroundDate = nil; return }
        let elapsed = Int(Date().timeIntervalSince(bg))
        secondsRemaining = max(0, secondsRemaining - elapsed)
        backgroundDate = nil
        if secondsRemaining == 0 { sessionCompleted() }
    }
}
