//
//  CalendarPlannerView.swift
//  FocusFlow
//
//  Created by mustaahh on 14/4/26.
//


import SwiftUI
import EventKit

struct CalendarPlannerView: View {
    @ObservedObject var calendarVM: CalendarViewModel
    @ObservedObject var plannerVM: SmartPlannerViewModel
    @ObservedObject var taskVM: TaskViewModel
    @ObservedObject var timerVM: TimerViewModel
    @State private var selectedTab: PlannerTab = .schedule
    @State private var showEventCreator = false
    @State private var showGenerateConfirm = false
    @Environment(\.colorScheme) private var colorScheme

    enum PlannerTab: String, CaseIterable {
        case schedule = "Schedule"; case planner = "Smart Plan"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color(hex: "#0d1324"), Color(hex: "#12121f"), Color(hex: "#1a1a2e")]
                        : [Color.white, Color(hex: "#f7f8fb"), Color(hex: "#eef2f7")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {

                    // ── Tab Picker ────────────────────────────────
                    Picker("", selection: $selectedTab) {
                        ForEach(PlannerTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    if selectedTab == .schedule {
                        ScheduleTabContent(
                            calendarVM: calendarVM,
                            taskVM: taskVM,
                            timerVM: timerVM,
                            showEventCreator: $showEventCreator
                        )
                    } else {
                        SmartPlannerTabContent(plannerVM: plannerVM, taskVM: taskVM, timerVM: timerVM)
                    }
                }
            }
            .navigationTitle("Planner")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(colorScheme == .dark ? Color(hex: "#12121f") : .white, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .toolbar {
                if selectedTab == .schedule {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showEventCreator = true } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.orange).font(.title3)
                        }
                        .disabled(!calendarVM.isAuthorized)
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showGenerateConfirm = true } label: {
                            Label("Generate", systemImage: "wand.and.stars")
                                .font(.subheadline).foregroundColor(.orange)
                        }
                    }
                }
            }
            .sheet(isPresented: $showEventCreator) {
                CreateEventSheet(calendarVM: calendarVM, taskVM: taskVM)
            }
            .confirmationDialog("Generate Plan", isPresented: $showGenerateConfirm, titleVisibility: .visible) {
                Button("Generate for Today") {
                    plannerVM.planDate = Date()
                    plannerVM.generatePlan(tasks: taskVM.tasks, settings: timerVM.settings)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Auto-schedule your tasks into Pomodoro sessions based on priority and due dates.")
            }
            .onAppear { calendarVM.reloadToday() }
            .onChange(of: calendarVM.eventsForDate) { _, events in
                Task {
                    await taskVM.syncCalendarEvents(events, for: calendarVM.selectedDate)
                }
            }
            .alert("Calendar Access", isPresented: .constant(calendarVM.errorMessage != nil)) {
                Button("OK") { calendarVM.errorMessage = nil }
            } message: {
                Text(calendarVM.errorMessage ?? "")
            }
        }
    }
}

// MARK: - Schedule Tab

private struct ScheduleTabContent: View {
    @ObservedObject var calendarVM: CalendarViewModel
    @ObservedObject var taskVM: TaskViewModel
    @ObservedObject var timerVM: TimerViewModel
    @Binding var showEventCreator: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Week Date Strip
            WeekDateStrip(calendarVM: calendarVM)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            if calendarVM.isRequestingAccess {
                ProgressView("Requesting access…").tint(.orange).padding(40)
            } else if !calendarVM.isAuthorized {
                CalendarPermissionPrompt { calendarVM.requestAccessIfNeeded() }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
            } else if calendarVM.eventsForDate.isEmpty {
                EmptyDayView(date: calendarVM.selectedDate) { showEventCreator = true }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
            } else {
                DayTimelineView(calendarVM: calendarVM, timerVM: timerVM)
            }
        }
    }
}

// MARK: - Week Date Strip

private struct WeekDateStrip: View {
    @ObservedObject var calendarVM: CalendarViewModel

    var body: some View {
        HStack(spacing: 0) {
            ForEach(calendarVM.weekDates, id: \.self) { date in
                Button {
                    calendarVM.selectedDate = date
                } label: {
                    VStack(spacing: 4) {
                        Text(dayLetter(date))
                            .font(.caption2).foregroundColor(.gray)
                        Text(dayNumber(date))
                            .font(.subheadline).fontWeight(calendarVM.isSelected(date) ? .bold : .regular)
                            .foregroundColor(foregroundColor(date))
                            .frame(width: 32, height: 32)
                            .background(background(date))
                            .clipShape(Circle())

                        // Event dot
                        Circle()
                            .fill(Color.orange.opacity(hasEvents(date) ? 1 : 0))
                            .frame(width: 4, height: 4)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(14)
    }

    func dayLetter(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "E"
        return String(f.string(from: d).prefix(1))
    }

    func dayNumber(_ d: Date) -> String {
        "\(Calendar.current.component(.day, from: d))"
    }

    func foregroundColor(_ d: Date) -> Color {
        if calendarVM.isSelected(d) { return .white }
        if calendarVM.isToday(d)    { return .orange }
        return .gray
    }

    func background(_ d: Date) -> Color {
        if calendarVM.isSelected(d) { return .orange }
        if calendarVM.isToday(d)    { return .orange.opacity(0.15) }
        return .clear
    }

    func hasEvents(_ d: Date) -> Bool {
        !CalendarService.shared.events(for: d).isEmpty
    }
}

// MARK: - Day Timeline

private struct DayTimelineView: View {
    @ObservedObject var calendarVM: CalendarViewModel
    @ObservedObject var timerVM: TimerViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(calendarVM.hourSlots, id: \.self) { hour in
                    HourRow(hour: hour, events: calendarVM.events(inHour: hour), timerVM: timerVM)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
    }
}

private struct HourRow: View {
    let hour: Date
    let events: [EKEvent]
    @ObservedObject var timerVM: TimerViewModel

    var hourLabel: String {
        let f = DateFormatter(); f.dateFormat = "h a"
        return f.string(from: hour)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(hourLabel)
                .font(.caption2).foregroundColor(.gray.opacity(0.7))
                .frame(width: 40, alignment: .trailing)
                .padding(.top, 2)

            VStack(spacing: 0) {
                Divider().background(Color.primary.opacity(0.08))
                VStack(spacing: 6) {
                    ForEach(events, id: \.eventIdentifier) { event in
                        CalendarEventRow(event: event, timerVM: timerVM)
                    }
                }
                .padding(.vertical, events.isEmpty ? 0 : 6)
            }
        }
        .frame(minHeight: events.isEmpty ? 36 : nil)
    }
}

private struct CalendarEventRow: View {
    let event: EKEvent
    @ObservedObject var timerVM: TimerViewModel
    @State private var showFocusMenu = false

    var body: some View {
        HStack(spacing: 10) {
            // Calendar color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: event.calendarColorHex))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "")
                    .font(.subheadline).fontWeight(.medium).foregroundColor(.primary)
                    .lineLimit(1)
                Text(event.timeRangeLabel)
                    .font(.caption2).foregroundColor(.gray)
            }
            Spacer()

            // Focus shortcut
            Button {
                showFocusMenu = true
            } label: {
                Image(systemName: "timer")
                    .font(.caption).foregroundColor(.orange)
                    .padding(6).background(Color.orange.opacity(0.1)).cornerRadius(8)
            }
            .confirmationDialog("Start Focus on \"\(event.title ?? "event")\"?",
                                isPresented: $showFocusMenu, titleVisibility: .visible) {
                Button("Start \(timerVM.settings.pomodoroMinutes) min Focus") {
                    timerVM.stop()
                    timerVM.start()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Color(hex: event.calendarColorHex).opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(Color(hex: event.calendarColorHex).opacity(0.3), lineWidth: 1))
        .cornerRadius(10)
    }
}

// MARK: - Smart Planner Tab

private struct SmartPlannerTabContent: View {
    @ObservedObject var plannerVM: SmartPlannerViewModel
    @ObservedObject var taskVM: TaskViewModel
    @ObservedObject var timerVM: TimerViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {

                // Work-hours row
                WorkHoursSelector(plannerVM: plannerVM)
                    .padding(.horizontal, 16)

                if plannerVM.isGenerating {
                    VStack(spacing: 12) {
                        ProgressView().tint(.orange).scaleEffect(1.3)
                        Text("Planning your day…").font(.subheadline).foregroundColor(.gray)
                    }
                    .frame(height: 200)
                } else if plannerVM.plannedSessions.isEmpty {
                    EmptyPlanView {
                        plannerVM.planDate = Date()
                        plannerVM.generatePlan(tasks: taskVM.tasks, settings: timerVM.settings)
                    }
                    .padding(.horizontal, 16)
                } else {
                    // Summary card
                    PlanSummaryCard(plannerVM: plannerVM)
                        .padding(.horizontal, 16)

                    // Session list
                    VStack(spacing: 8) {
                        ForEach(plannerVM.plannedSessions) { session in
                            PlannedSessionRow(session: session) {
                                plannerVM.toggleComplete(session)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 30)
            }
            .padding(.top, 8)
        }
    }
}

private struct WorkHoursSelector: View {
    @ObservedObject var plannerVM: SmartPlannerViewModel

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Start", systemImage: "sunrise.fill").font(.caption).foregroundColor(.gray)
                Picker("", selection: $plannerVM.workStartHour) {
                    ForEach(6..<23, id: \.self) { h in Text(hourLabel(h)).tag(h) }
                }
                .pickerStyle(.menu).tint(.orange)
                .padding(6).background(Color.primary.opacity(0.08)).cornerRadius(8)
            }

            Image(systemName: "arrow.right").foregroundColor(.gray)

            VStack(alignment: .leading, spacing: 4) {
                Label("End", systemImage: "sunset.fill").font(.caption).foregroundColor(.gray)
                Picker("", selection: $plannerVM.workEndHour) {
                    ForEach(7..<24, id: \.self) { h in Text(hourLabel(h)).tag(h) }
                }
                .pickerStyle(.menu).tint(.orange)
                .padding(6).background(Color.primary.opacity(0.08)).cornerRadius(8)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.primary.opacity(0.05)).cornerRadius(14)
    }

    func hourLabel(_ h: Int) -> String {
        let f = DateFormatter(); f.dateFormat = "h a"
        let cal = Calendar.current
        let d = cal.date(bySettingHour: h, minute: 0, second: 0, of: Date())!
        return f.string(from: d)
    }
}

private struct PlanSummaryCard: View {
    @ObservedObject var plannerVM: SmartPlannerViewModel

    var body: some View {
        HStack(spacing: 0) {
            SummaryPill(value: "\(plannerVM.totalCount)", label: "Sessions", icon: "timer", color: .orange)
            Divider().background(Color.white.opacity(0.1)).frame(height: 40)
            SummaryPill(value: "\(plannerVM.totalFocusMinutes)m", label: "Focus", icon: "clock.fill", color: .blue)
            Divider().background(Color.white.opacity(0.1)).frame(height: 40)
            SummaryPill(value: "\(plannerVM.completedCount)/\(plannerVM.totalCount)", label: "Done", icon: "checkmark.circle.fill", color: .green)
        }
        .padding(12)
        .background(Color.primary.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(Color.white.opacity(0.08), lineWidth: 1))
        .cornerRadius(14)
    }
}

private struct SummaryPill: View {
    let value: String; let label: String; let icon: String; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.caption).foregroundColor(color)
            Text(value).font(.subheadline).fontWeight(.bold).foregroundColor(.primary)
            Text(label).font(.caption2).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PlannedSessionRow: View {
    let session: PlannedSession
    let onToggle: () -> Void

    var priorityColor: Color {
        switch session.priority {
        case .high:   return .red
        case .medium: return .orange
        case .low:    return .blue
        case .none:   return .gray
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Priority bar
            RoundedRectangle(cornerRadius: 2)
                .fill(priorityColor)
                .frame(width: 4, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(session.taskTitle)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundColor(session.isCompleted ? .gray : .white)
                    .strikethrough(session.isCompleted)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(session.timeRangeLabel)
                        .font(.caption2).foregroundColor(.gray)
                    Text("·")
                        .foregroundColor(.gray)
                    Label("\(session.pomodoroMinutes) min", systemImage: "timer")
                        .font(.caption2).foregroundColor(.orange)
                }
            }

            Spacer()

            // Complete toggle
            Button(action: onToggle) {
                Image(systemName: session.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(session.isCompleted ? .green : .gray.opacity(0.4))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(session.isCompleted
                      ? Color.green.opacity(0.04)
                      : Color.primary.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(session.isCompleted
                            ? Color.green.opacity(0.15)
                            : Color.primary.opacity(0.09), lineWidth: 1))
        )
    }
}

// MARK: - Create Event Sheet

struct CreateEventSheet: View {
    @ObservedObject var calendarVM: CalendarViewModel
    @ObservedObject var taskVM: TaskViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var title: String = ""
    @State private var startTime: Date = Date()
    @State private var durationMinutes: Int = 25
    @State private var isSaving = false
    @State private var errorMsg: String? = nil

    let durations = [15, 25, 30, 45, 60, 90]

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color(hex: "#12121f") : .white).ignoresSafeArea()

                VStack(spacing: 20) {

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Session Title", systemImage: "pencil").font(.caption).foregroundColor(.gray)
                        TextField("e.g. Deep Work: SwiftUI", text: $title)
                            .foregroundColor(.primary).padding(12)
                            .background(Color.primary.opacity(0.09)).cornerRadius(10)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Start Time", systemImage: "clock").font(.caption).foregroundColor(.gray)
                        DatePicker("", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .labelsHidden().tint(.orange)
                            .padding(8).background(Color.primary.opacity(0.09)).cornerRadius(10)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Duration", systemImage: "timer").font(.caption).foregroundColor(.gray)
                        HStack(spacing: 8) {
                            ForEach(durations, id: \.self) { dur in
                                Button { durationMinutes = dur } label: {
                                    Text("\(dur)m")
                                        .font(.subheadline).fontWeight(.medium)
                                        .foregroundColor(durationMinutes == dur ? .white : .gray)
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(durationMinutes == dur ? Color.orange : Color.primary.opacity(0.08))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }

                    if let err = errorMsg {
                        Text(err).font(.caption).foregroundColor(.red).padding(.top, 4)
                    }

                    Spacer()

                    Button {
                        guard !title.isEmpty else { return }
                        isSaving = true
                        if calendarVM.createFocusEvent(title: title, start: startTime, durationMinutes: durationMinutes) != nil {
                            Task {
                                await taskVM.syncCalendarEvents(calendarVM.eventsForDate, for: calendarVM.selectedDate)
                                await MainActor.run {
                                    isSaving = false
                                    dismiss()
                                }
                            }
                        } else {
                            errorMsg = calendarVM.errorMessage
                            isSaving = false
                        }
                    } label: {
                        Group {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Label("Add to Calendar", systemImage: "calendar.badge.plus")
                                    .font(.headline).foregroundColor(.primary)
                            }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(title.isEmpty ? Color.gray.opacity(0.3) : Color.orange)
                        .cornerRadius(14)
                    }
                    .disabled(title.isEmpty || isSaving)
                }
                .padding(16)
            }
            .navigationTitle("Add Focus Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(colorScheme == .dark ? Color(hex: "#12121f") : .white, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.gray)
                }
            }
        }
    }
}

// MARK: - Permission Prompt

private struct CalendarPermissionPrompt: View {
    let onGrant: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 50)).foregroundColor(.orange.opacity(0.7))
            Text("Calendar Access Needed")
                .font(.headline).foregroundColor(.primary)
            Text("Allow FocusFlow to read your calendar so your events appear in the schedule view.")
                .font(.subheadline).foregroundColor(.gray).multilineTextAlignment(.center)
            Button(action: onGrant) {
                Label("Grant Access", systemImage: "checkmark.shield.fill")
                    .font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color.orange).cornerRadius(12)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.05)).cornerRadius(16)
    }
}

private struct EmptyDayView: View {
    let date: Date; let onCreate: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar").font(.system(size: 46)).foregroundColor(.gray.opacity(0.4))
            Text("No events on \(date.shortDateString)")
                .font(.headline).foregroundColor(.primary)
            Text("Your calendar is clear — add a focus block or enjoy the free time!")
                .font(.subheadline).foregroundColor(.gray).multilineTextAlignment(.center)
            Button(action: onCreate) {
                Label("Add Focus Block", systemImage: "plus.circle.fill")
                    .font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color.orange).cornerRadius(10)
            }
        }
        .padding(30).frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.05)).cornerRadius(16)
    }
}

private struct EmptyPlanView: View {
    let onGenerate: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 50)).foregroundColor(.orange.opacity(0.7))
            Text("Auto-Plan Your Day")
                .font(.headline).foregroundColor(.primary)
            Text("FocusFlow will schedule your high-priority and due-today tasks into optimized Pomodoro sessions.")
                .font(.subheadline).foregroundColor(.gray).multilineTextAlignment(.center)
            Button(action: onGenerate) {
                Label("Generate Plan", systemImage: "wand.and.stars")
                    .font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color.orange).cornerRadius(12)
            }
        }
        .padding(30).frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.05)).cornerRadius(16)
    }
}
