// SettingsView.swift
import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @ObservedObject var timerVM: TimerViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var settings: UserSettings = UserSettings()
    @State private var isSaving = false
    @State private var showDeleteAlert = false
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var uid: String? { AuthService.shared.uid }
    private var isDark: Bool { colorScheme == .dark }
    private var backgroundColor: Color { isDark ? Color(hex: "#12121f") : .white }
    private var cardColor: Color { isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.04) }
    private var primaryText: Color { isDark ? .white : .black }
    private var secondaryText: Color { isDark ? .gray : .secondary }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                List {

                    // ── Timer Lengths ──────────────────────────────────
                    Section {
                        PomodoroStepperRow(value: $settings.pomodoroMinutes)
                        StepperRow(label: "Short Break", icon: "cup.and.saucer.fill",
                                   value: $settings.shortBreakMinutes, range: 1...30, step: 1,
                                   unit: "min", color: .green)
                        StepperRow(label: "Long Break", icon: "moon.fill",
                                   value: $settings.longBreakMinutes, range: 5...60, step: 5,
                                   unit: "min", color: .cyan)
                        StepperRow(label: "Sessions Until Long Break", icon: "repeat",
                                   value: $settings.sessionsUntilLongBreak, range: 2...8, step: 1,
                                   unit: "", color: .purple)
                    } header: { SectionHeader(title: "Timer", icon: "timer") }
                    .listRowBackground(cardColor)

                    // ── Automation ─────────────────────────────────────
                    Section {
                        ToggleRow(label: "Auto-start Breaks", icon: "play.circle.fill",
                                  value: $settings.autoStartBreaks, color: .green)
                        ToggleRow(label: "Auto-start Pomodoros", icon: "play.circle.fill",
                                  value: $settings.autoStartPomodoros, color: .orange)
                        ToggleRow(label: "Continuous Mode", icon: "arrow.clockwise",
                                  value: $settings.continuousMode, color: .cyan)
                    } header: { SectionHeader(title: "Automation", icon: "gearshape") }
                    .listRowBackground(cardColor)

                    // ── Notifications ──────────────────────────────────
                    Section {
                        ToggleRow(label: "Vibration", icon: "iphone.radiowaves.left.and.right",
                                  value: $settings.vibrationEnabled, color: .yellow)
                        ToggleRow(label: "Sound", icon: "speaker.wave.2.fill",
                                  value: $settings.soundEnabled, color: .blue)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "bell.badge.fill").foregroundColor(.orange).frame(width: 28)
                                Text("Warn Before End").foregroundColor(primaryText)
                                Spacer()
                                Text("\(settings.notifyBeforeEndSeconds)s").foregroundColor(.gray)
                            }
                            Slider(value: Binding(
                                get: { Double(settings.notifyBeforeEndSeconds) },
                                set: { settings.notifyBeforeEndSeconds = Int($0) }
                            ), in: 0...120, step: 10)
                            .tint(.orange)
                        }
                        .padding(.vertical, 4)
                    } header: { SectionHeader(title: "Notifications", icon: "bell.fill") }
                    .listRowBackground(cardColor)

                    // ── Goals ──────────────────────────────────────────
                    Section {
                        StepperRow(label: "Daily Pomodoro Goal", icon: "target",
                                   value: $settings.dailyGoalPomodoros, range: 1...20, step: 1,
                                   unit: "", color: .orange)
                    } header: { SectionHeader(title: "Goals", icon: "target") }
                    .listRowBackground(cardColor)

                    // ── Appearance ─────────────────────────────────────
                    Section {
                        HStack {
                            Image(systemName: "circle.lefthalf.filled")
                                .foregroundColor(.orange)
                                .frame(width: 28)
                            Toggle("Dark Mode", isOn: Binding(
                                get: { settings.theme != "light" },
                                set: { isDark in
                                    settings.theme = isDark ? "dark" : "light"
                                    themeManager.apply(theme: settings.theme)
                                }
                            ))
                            .foregroundColor(primaryText)
                            .tint(.orange)
                        }
                    } header: { SectionHeader(title: "Appearance", icon: "paintbrush.fill") }
                    .listRowBackground(cardColor)

                    // ── Account ────────────────────────────────────────
                    Section {
                        if let user = AuthService.shared.currentUser {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .font(.title2).foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.displayName ?? "User")
                                        .font(.subheadline).fontWeight(.medium).foregroundColor(primaryText)
                                    Text(user.email ?? "").font(.caption).foregroundColor(secondaryText)
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        Button {
                            dismiss()
                            authVM.signOut()
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(.red).frame(width: 28)
                                Text("Sign Out").foregroundColor(.red)
                            }
                        }

                        Button {
                            showDeleteAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "trash").foregroundColor(.red.opacity(0.7)).frame(width: 28)
                                Text("Delete Account").foregroundColor(.red.opacity(0.7))
                            }
                        }
                    } header: { SectionHeader(title: "Account", icon: "person.fill") }
                    .listRowBackground(cardColor)

                    // Version
                    Section {
                        HStack {
                            Spacer()
                            Text("FocusFlow v1.0.0").font(.caption).foregroundColor(secondaryText)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(backgroundColor, for: .navigationBar)
            .toolbarColorScheme(isDark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.gray)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveSettings() }
                        .foregroundColor(.orange).fontWeight(.semibold)
                }
            }
            .onAppear { settings = timerVM.settings }
            .alert("Delete Account", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    Task { try? await AuthService.shared.deleteAccount() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete your account and all data. This action cannot be undone.")
            }
        }
    }

    func saveSettings() {
        themeManager.apply(theme: settings.theme)
        timerVM.loadSettings(settings)
        Task {
            guard let uid = uid else { return }
            isSaving = true
            try? await FirebaseService.shared.saveSettings(settings, uid: uid)
            isSaving = false
        }
        dismiss()
    }
}

// MARK: - Reusable Setting Rows
struct StepperRow: View {
    let label: String; let icon: String
    @Binding var value: Int
    let range: ClosedRange<Int>; let step: Int; let unit: String; let color: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(color).frame(width: 28)
            Text(label).foregroundColor(colorScheme == .dark ? .white : .black)
            Spacer()
            Button { if value - step >= range.lowerBound { value -= step } } label: {
                Image(systemName: "minus.circle.fill").foregroundColor(.gray)
            }.buttonStyle(.plain)
            Text("\(value)\(unit.isEmpty ? "" : " \(unit)")")
                .font(.subheadline).fontWeight(.medium).foregroundColor(.orange)
                .frame(minWidth: 52, alignment: .center)
            Button { if value + step <= range.upperBound { value += step } } label: {
                Image(systemName: "plus.circle.fill").foregroundColor(.orange)
            }.buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}

struct PomodoroStepperRow: View {
    @Binding var value: Int
    @Environment(\.colorScheme) private var colorScheme

    private let supportedValues = [1] + Array(stride(from: 5, through: 90, by: 5))

    var body: some View {
        HStack {
            Image(systemName: "timer").foregroundColor(.orange).frame(width: 28)
            Text("Pomodoro").foregroundColor(colorScheme == .dark ? .white : .black)
            Spacer()
            Button {
                value = previousValue(from: value)
            } label: {
                Image(systemName: "minus.circle.fill").foregroundColor(.gray)
            }
            .buttonStyle(.plain)
            .disabled(value == supportedValues.first)

            Text("\(value) min")
                .font(.subheadline).fontWeight(.medium).foregroundColor(.orange)
                .frame(minWidth: 52, alignment: .center)

            Button {
                value = nextValue(from: value)
            } label: {
                Image(systemName: "plus.circle.fill").foregroundColor(.orange)
            }
            .buttonStyle(.plain)
            .disabled(value == supportedValues.last)
        }
        .padding(.vertical, 2)
    }

    private func previousValue(from current: Int) -> Int {
        guard let index = supportedValues.lastIndex(where: { $0 <= current }) else {
            return supportedValues.first ?? 1
        }

        return index > 0 ? supportedValues[index - 1] : supportedValues[0]
    }

    private func nextValue(from current: Int) -> Int {
        guard let index = supportedValues.firstIndex(where: { $0 >= current }) else {
            return supportedValues.last ?? 90
        }

        return index < supportedValues.count - 1 ? supportedValues[index + 1] : supportedValues[index]
    }
}

struct ToggleRow: View {
    let label: String; let icon: String
    @Binding var value: Bool; let color: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(color).frame(width: 28)
            Toggle(label, isOn: $value).foregroundColor(colorScheme == .dark ? .white : .black).tint(.orange)
        }
    }
}

struct SectionHeader: View {
    let title: String; let icon: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.caption).foregroundColor(.orange)
            Text(title).font(.caption).foregroundColor(.gray)
        }
    }
}
