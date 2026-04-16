// NotificationService.swift
import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    private let permissionRequestedKey = "focusflow_notifications_permission_requested_once"
    private let exitReminderDelay: TimeInterval = 120

    func requestPermission() {
        requestPermissionIfNeeded()
    }

    func requestPermissionIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: permissionRequestedKey) == false else { return }
        defaults.set(true, forKey: permissionRequestedKey)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            print("Notification permission granted: \(granted)")
        }
    }

    // MARK: - Timer End Notification
    func scheduleTimerEndNotification(secondsFromNow: TimeInterval, sessionType: SessionType) {
        let content = UNMutableNotificationContent()
        content.sound = UNNotificationSound(named: UNNotificationSoundName("bell.mp3"))
        switch sessionType {
        case .focus:
            content.title = "🍅 Pomodoro Complete!"
            content.body = "Great work! Take a well-deserved break."
        case .shortBreak:
            content.title = "⏱ Break Over!"
            content.body = "Time to focus again. You've got this!"
        case .longBreak:
            content.title = "⏱ Long Break Over!"
            content.body = "Ready for another round? Let's go!"
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, secondsFromNow), repeats: false)
        let request = UNNotificationRequest(
            identifier: AppConstants.NotificationID.pomodoroEnd,
            content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Warning Notification (1 min before end)
    func scheduleWarningNotification(secondsFromNow: TimeInterval) {
        guard secondsFromNow > 65 else { return } // only if >65s remain
        let warningTime = secondsFromNow - 60
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Almost Done!"
        content.body = "1 minute left in your Pomodoro session."
        content.sound = UNNotificationSound.default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: warningTime, repeats: false)
        let request = UNNotificationRequest(
            identifier: AppConstants.NotificationID.pomodoroWarning,
            content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Task Reminder
    func scheduleTaskReminder(task: FTask) {
        guard let reminderDate = task.reminderDate, let id = task.id else { return }
        guard reminderDate > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "📝 Task Reminder"
        content.body = task.title
        content.sound = UNNotificationSound.default
        content.userInfo = ["taskId": id]
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: AppConstants.NotificationID.taskReminder + id,
            content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Cancel
    func cancelTimerNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [AppConstants.NotificationID.pomodoroEnd,
                             AppConstants.NotificationID.pomodoroWarning])
    }

    func cancelTaskReminder(taskId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [AppConstants.NotificationID.taskReminder + taskId])
    }

    // MARK: - Pomodoro Exit Reminder
    func schedulePomodoroExitReminder(secondsRemaining: Int) {
        // If the timer can end before the reminder delay, don't schedule this reminder.
        guard secondsRemaining > Int(exitReminderDelay) else {
            cancelPomodoroExitReminder()
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Pomodoro Running ⏳"
        content.body = "You left the app. Stay focused!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: exitReminderDelay, repeats: false)
        let request = UNNotificationRequest(
            identifier: AppConstants.NotificationID.pomodoroExitReminder,
            content: content,
            trigger: trigger
        )

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [AppConstants.NotificationID.pomodoroExitReminder])
        center.add(request)
    }

    func cancelPomodoroExitReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [AppConstants.NotificationID.pomodoroExitReminder])
        center.removeDeliveredNotifications(withIdentifiers: [AppConstants.NotificationID.pomodoroExitReminder])
    }
}
