// TimerView.swift
import SwiftUI

struct TimerView: View {
    @ObservedObject var timerVM:        TimerViewModel
    @ObservedObject var taskVM:         TaskViewModel
    @ObservedObject var gamificationVM: GamificationViewModel
    @ObservedObject var blockerVM:      BlockerViewModel

    @State private var showTaskPicker    = false
    @State private var showSettings      = false
    @State private var lastCompletedCount: Int = 0
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }
    private var primaryText: Color { isDark ? .white : .black }
    private var secondaryText: Color { isDark ? Color.white.opacity(0.7) : .secondary }

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Top bar ───────────────────────────────────────
                HStack {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3).foregroundColor(secondaryText)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill").foregroundColor(.orange)
                        Text(gamificationVM.progress.currentStreak > 0
                             ? "\(gamificationVM.progress.currentStreak)d streak"
                             : "Focus Mode")
                            .font(.caption).fontWeight(.semibold).foregroundColor(secondaryText)
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Label("\(timerVM.completedSessionsCount)", systemImage: "timer")
                            .font(.subheadline)
                            .foregroundColor(secondaryText)
                        Label("Lv \(gamificationVM.progress.level.level)", systemImage: "star.fill")
                            .font(.subheadline)
                            .foregroundColor(secondaryText)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer()

                // ── Session type selector ─────────────────────────
                SessionTypeSelector(timerVM: timerVM)
                    .padding(.horizontal, 24)

                Spacer()

                // ── Timer ring ────────────────────────────────────
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 14)
                        .frame(width: 260, height: 260)

                    Circle()
                        .trim(from: 0, to: timerVM.progress)
                        .stroke(
                            LinearGradient(colors: ringColors,
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .frame(width: 260, height: 260)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: timerVM.progress)

                    VStack(spacing: 6) {
                        Text(timerVM.secondsRemaining.timerString)
                            .font(.system(size: 64, weight: .bold, design: .monospaced))
                            .foregroundColor(primaryText)
                            .minimumScaleFactor(0.5)
                        Text(timerVM.sessionLabel)
                            .font(.subheadline)
                            .foregroundColor(secondaryText)
                    }
                }

                Spacer()

                // ── Selected task ─────────────────────────────────
                Button { showTaskPicker = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(timerVM.selectedTask != nil ? .green : .gray)
                        Text(timerVM.selectedTask?.title ?? "Select a task (optional)")
                            .font(.subheadline)
                            .foregroundColor(timerVM.selectedTask != nil ? primaryText : .gray)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.gray).font(.caption)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 46)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 24)

                // ── Focus Shield Banner ───────────────────────────
                if blockerVM.isShieldActive {
                    FocusShieldBanner(blockerVM: blockerVM)
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()

                // ── Controls ──────────────────────────────────────
                HStack(spacing: 28) {

                    // Stop — routes through strict-mode check
                    if timerVM.state != .idle {
                        CircleButton(
                            icon: "stop.fill",
                            size: 52,
                            bg: blockerVM.settings.isStrictModeEnabled && blockerVM.isShieldActive
                                ? Color.red.opacity(0.25) : .white.opacity(0.12)
                        ) {
                            let allowed = blockerVM.requestStop()
                            if allowed { timerVM.stop() }
                        }
                    } else {
                        Spacer().frame(width: 52)
                    }

                    // Play / Pause
                    Button {
                        switch timerVM.state {
                        case .idle:
                            timerVM.start()
                            blockerVM.startShield()
                        case .running:
                            timerVM.pause()
                        case .paused:
                            timerVM.resume()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.orange, Color(hex: "#e05c00")],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 80, height: 80)
                                .shadow(color: .orange.opacity(0.5), radius: 16)
                            Image(systemName: timerVM.state == .running ? "pause.fill" : "play.fill")
                                .font(.title2).foregroundColor(.white)
                                .offset(x: timerVM.state != .running ? 2 : 0)
                        }
                    }

                    // Skip break
                    if timerVM.sessionType != .focus {
                        CircleButton(icon: "forward.fill", size: 52, bg: .white.opacity(0.12)) {
                            timerVM.skipBreak()
                        }
                    } else {
                        Spacer().frame(width: 52)
                    }
                }
                .padding(.bottom, 40)
            }

            // ── Strict Mode Overlay ───────────────────────────────
            if blockerVM.showStrictExitOverlay {
                StrictModeOverlay(blockerVM: blockerVM)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: blockerVM.isShieldActive)
        .animation(.easeInOut(duration: 0.25), value: blockerVM.showStrictExitOverlay)
        .sheet(isPresented: $showTaskPicker) {
            TaskPickerView(timerVM: timerVM, taskVM: taskVM)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(timerVM: timerVM)
        }
        .alert("Break Time! 🎉", isPresented: $timerVM.showBreakSkipAlert) {
            Button("Take Break") { timerVM.start(); blockerVM.startShield() }
            Button("Skip Break") { timerVM.skipBreak() }
        } message: {
            Text("You completed a Pomodoro! Ready for a \(timerVM.sessionLabel.lowercased())?")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            timerVM.handleBackground()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            timerVM.handleForeground()
        }
        // XP on session complete
        .onChange(of: timerVM.completedSessionsCount) { newCount in
            guard newCount > lastCompletedCount else { return }
            lastCompletedCount = newCount
            gamificationVM.sessionCompleted(
                durationMinutes: timerVM.settings.pomodoroMinutes,
                sessionType: .focus,
                task: timerVM.selectedTask
            )
            blockerVM.stopShield()
        }
        // Penalty XP deduction when user force-exits strict mode
        .onChange(of: blockerVM.penaltyTriggered) { triggered in
            guard triggered else { return }
            let penalty = blockerVM.settings.exitPenaltyXP
            gamificationVM.progress.totalXP = max(0, gamificationVM.progress.totalXP - penalty)
            timerVM.stop()
            blockerVM.clearPenalty()
        }
        .onAppear {
            lastCompletedCount = timerVM.completedSessionsCount
            // Sync shield if session was already running
            if timerVM.state == .running { blockerVM.startShield() }
        }
    }

    // MARK: - Style helpers

    var backgroundGradient: LinearGradient {
        if !isDark {
            switch timerVM.sessionType {
            case .focus:
                return LinearGradient(colors: [Color.white, Color(hex: "#f3f7ff"), Color(hex: "#ebf2ff")],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
            case .shortBreak:
                return LinearGradient(colors: [Color.white, Color(hex: "#f2fbf4")],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
            case .longBreak:
                return LinearGradient(colors: [Color.white, Color(hex: "#f2fbfc")],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }

        switch timerVM.sessionType {
        case .focus:
            return LinearGradient(colors: [Color(hex: "#1a1a2e"), Color(hex: "#16213e"), Color(hex: "#0f3460")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .shortBreak:
            return LinearGradient(colors: [Color(hex: "#1a2e1a"), Color(hex: "#1e3a1e")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .longBreak:
            return LinearGradient(colors: [Color(hex: "#1a2a2e"), Color(hex: "#163040")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var ringColors: [Color] {
        switch timerVM.sessionType {
        case .focus:      return [.orange, Color(hex: "#e05c00")]
        case .shortBreak: return [.green,  Color(hex: "#00b300")]
        case .longBreak:  return [.cyan,   Color(hex: "#0099bb")]
        }
    }
}

// MARK: - Session Type Selector

struct SessionTypeSelector: View {
    @ObservedObject var timerVM: TimerViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isDark = colorScheme == .dark
        HStack(spacing: 0) {
            ForEach([SessionType.focus, .shortBreak, .longBreak], id: \.self) { type in
                Button {
                    guard timerVM.state == .idle else { return }
                    timerVM.sessionType = type
                    timerVM.stop()
                } label: {
                    Text(labelFor(type))
                        .font(.caption)
                        .fontWeight(timerVM.sessionType == type ? .semibold : .regular)
                        .foregroundColor(timerVM.sessionType == type
                            ? (isDark ? .white : .black)
                            : (isDark ? .white.opacity(0.4) : .secondary))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(timerVM.sessionType == type
                            ? (isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.08))
                            : Color.clear)
                        .cornerRadius(8)
                }
            }
        }
        .background(isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.04))
        .cornerRadius(10)
    }

    func labelFor(_ type: SessionType) -> String {
        switch type {
        case .focus: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }
}

// MARK: - Circle Button

struct CircleButton: View {
    let icon: String; let size: CGFloat; let bg: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(bg).frame(width: size, height: size)
                Image(systemName: icon).font(.body).foregroundColor(.white)
            }
        }
    }
}

// MARK: - Task Picker

struct TaskPickerView: View {
    @ObservedObject var timerVM: TimerViewModel
    @ObservedObject var taskVM:  TaskViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color(hex: "#1a1a2e") : .white).ignoresSafeArea()
                List {
                    Button {
                        timerVM.selectedTask = nil; dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle").foregroundColor(.gray)
                            Text("No task").foregroundColor(.gray)
                            Spacer()
                            if timerVM.selectedTask == nil {
                                Image(systemName: "checkmark").foregroundColor(.orange)
                            }
                        }
                    }
                    .listRowBackground(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.04))

                    ForEach(taskVM.activeTasks) { task in
                        Button {
                            timerVM.selectedTask = task; dismiss()
                        } label: {
                            HStack {
                                Circle().fill(Color(designColor: task.priority.color)).frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.title).foregroundColor(colorScheme == .dark ? .white : .black)
                                    if let proj = task.projectId {
                                        Text(taskVM.projectName(for: proj)).font(.caption).foregroundColor(.gray)
                                    }
                                }
                                Spacer()
                                if timerVM.selectedTask?.id == task.id {
                                    Image(systemName: "checkmark").foregroundColor(.orange)
                                }
                            }
                        }
                        .listRowBackground(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Select Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.orange)
                }
            }
        }
    }
}
