/// MainTabView.swift
import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var timerVM       = TimerViewModel()
    @StateObject private var taskVM        = TaskViewModel()
    @StateObject private var reportVM      = ReportViewModel()
    @StateObject private var gamificationVM = GamificationViewModel()
    @StateObject private var studyRoomVM    = StudyRoomViewModel()
    @StateObject private var calendarVM     = CalendarViewModel()
    @StateObject private var plannerVM      = SmartPlannerViewModel()
    @StateObject private var blockerVM      = BlockerViewModel()

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {

            // ── Focus Timer ───────────────────────────────────
            TimerView(
                timerVM:        timerVM,
                taskVM:         taskVM,
                gamificationVM: gamificationVM,
                blockerVM:      blockerVM
            )
            .tabItem { Label("Focus", systemImage: "timer") }
            .tag(0)

            // ── Tasks ─────────────────────────────────────────
            TaskListView(taskVM: taskVM)
                .tabItem { Label("Tasks", systemImage: "checkmark.circle") }
                .tag(1)

            // ── Planner / Calendar ────────────────────────────
            CalendarPlannerView(
                calendarVM: calendarVM,
                plannerVM:  plannerVM,
                taskVM:     taskVM,
                timerVM:    timerVM
            )
            .tabItem { Label("Planner", systemImage: "calendar") }
            .tag(2)
            
            // ── White Noise ───────────────────────────────────

            WhiteNoiseView()
                .tabItem { Label("Sounds", systemImage: "waveform") }
                .tag(3)

            // ── Study Rooms ───────────────────────────────────
            StudyRoomView(vm: studyRoomVM, gamificationVM: gamificationVM)
                .tabItem { Label("Rooms", systemImage: "person.3.fill") }
                .tag(4)

            // ── Progress / Gamification ───────────────────────
            GamificationView(vm: gamificationVM)
                .tabItem { Label("Progress", systemImage: "star.circle.fill") }
                .tag(5)

            // ── Reports ───────────────────────────────────────
            ReportView(reportVM: reportVM, taskVM: taskVM)
                .tabItem { Label("Report", systemImage: "chart.bar.fill") }
                .tag(6)

            // ── Focus Blocker ─────────────────────────────────
            BlockerView(blockerVM: blockerVM)
                .tabItem { Label("Strict Mode", systemImage: "shield.fill") }
                .tag(7)
          
        }
        .tint(.orange)
        .onAppear {
            setupTabBarAppearance()
            taskVM.loadData()
            loadUserSettings()
            flushPendingSessions()
            NotificationService.shared.requestPermissionIfNeeded()
            gamificationVM.loadProgress()
            taskVM.onTaskCompleted = { [weak gamificationVM] priority in
                gamificationVM?.taskCompleted(priority: priority)
            }
        }
        .onChange(of: scenePhase) { phase in
            handleScenePhaseChange(phase)
        }
        .onChange(of: timerVM.state) { newState in
            guard newState != .running else { return }
            NotificationService.shared.cancelPomodoroExitReminder()
        }
        .onChange(of: themeManager.theme) { _ in
            setupTabBarAppearance()
        }
        .onChange(of: taskVM.tasks) { newTasks in
            reportVM.loadData(tasks: newTasks, projects: taskVM.projects)
        }
        .onChange(of: gamificationVM.progress) { prog in
            studyRoomVM.updateMyLeaderboardEntry(
                weeklyMinutes: prog.totalFocusMinutes,
                totalMinutes:  prog.totalFocusMinutes,
                streak:        prog.currentStreak,
                level:         prog.level.level
            )
        }
        // Achievement toast
        .overlay(alignment: .bottom) {
            if let first = gamificationVM.newlyUnlocked.first {
                AchievementToast(achievement: first) {
                    gamificationVM.clearNewlyUnlocked()
                }
                .padding(.bottom, 90)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4), value: gamificationVM.newlyUnlocked.count)
    }

    // MARK: - Helpers

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            flushPendingSessions()
            NotificationService.shared.cancelPomodoroExitReminder()
        case .background:
            guard timerVM.state == .running,
                  blockerVM.settings.isBlockerEnabled,
                  blockerVM.settings.isStrictModeEnabled else { return }
            NotificationService.shared.schedulePomodoroExitReminder(secondsRemaining: timerVM.secondsRemaining)
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    private func flushPendingSessions() {
        guard let uid = AuthService.shared.uid else { return }
        Task { await SessionSyncService.shared.flushPendingSessions(for: uid) }
    }

    private func loadUserSettings() {
        guard let uid = AuthService.shared.uid else { return }
        Task {
            let settings = (try? await FirebaseService.shared.fetchSettings(uid: uid)) ?? UserSettings()
            await MainActor.run {
                timerVM.loadSettings(settings)
                themeManager.apply(theme: settings.theme)
            }
        }
    }

    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = themeManager.isDarkMode
            ? UIColor(Color(hex: "#12121f"))
            : UIColor.systemBackground
        appearance.stackedLayoutAppearance.selected.iconColor   = UIColor.systemOrange
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.systemOrange]
        appearance.stackedLayoutAppearance.normal.iconColor     = themeManager.isDarkMode ? UIColor.systemGray : UIColor.darkGray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes   = [
            .foregroundColor: themeManager.isDarkMode ? UIColor.systemGray : UIColor.darkGray
        ]
        UITabBar.appearance().standardAppearance  = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
