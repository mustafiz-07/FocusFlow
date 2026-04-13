// ReportView.swift
// Requires iOS 16+ (Swift Charts) — supported by Xcode 14
import SwiftUI
import Charts

struct ReportView: View {
    @ObservedObject var reportVM: ReportViewModel
    @ObservedObject var taskVM: TaskViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color(hex: "#0d1324"), Color(hex: "#12121f"), Color(hex: "#1a1a2e")]
                        : [Color.white, Color(hex: "#f7f8fb"), Color(hex: "#eef2f7")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // Period Picker
                        Picker("Period", selection: $reportVM.selectedPeriod) {
                            ForEach(ReportViewModel.ReportPeriod.allCases, id: \.self) { p in
                                Text(p.rawValue).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        // Summary cards
                        SummaryCardsView(reportVM: reportVM)
                            .padding(.horizontal, 16)

                        // Focus time bar chart
                        FocusBarChart(stats: reportVM.dailyStats)
                            .padding(.horizontal, 16)

                        // Completed tasks line chart
                        TaskTrendChart(stats: reportVM.dailyStats)
                            .padding(.horizontal, 16)

                        // Project distribution
                        if !reportVM.projectStats.isEmpty {
                            ProjectDistributionView(stats: reportVM.projectStats)
                                .padding(.horizontal, 16)
                        }

                        // Calendar heatmap
                        FocusCalendarView(sessions: reportVM.sessions)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(colorScheme == .dark ? Color(hex: "#12121f") : .white, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .onAppear {
                reportVM.loadData(tasks: taskVM.tasks, projects: taskVM.projects)
            }
            .onChange(of: taskVM.tasks) { _, tasks in
                reportVM.loadData(tasks: tasks, projects: taskVM.projects)
            }
            .onChange(of: taskVM.projects) { _, projects in
                reportVM.loadData(tasks: taskVM.tasks, projects: projects)
            }
        }
    }
}

// MARK: - Summary Cards
struct SummaryCardsView: View {
    @ObservedObject var reportVM: ReportViewModel

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "Focus Time",
                     value: formatMinutes(reportVM.totalFocusMinutes),
                     icon: "clock.fill", color: .orange)
            StatCard(title: "Pomodoros",
                     value: "\(reportVM.totalPomodoros)",
                     icon: "timer", color: .red)
            StatCard(title: "Tasks Done",
                     value: "\(reportVM.totalCompletedTasks)",
                     icon: "checkmark.circle.fill", color: .green)
            StatCard(title: "Day Streak",
                     value: "\(reportVM.currentStreak) 🔥",
                     icon: "flame.fill", color: .yellow)
        }
    }

    func formatMinutes(_ mins: Double) -> String {
        if mins < 60 { return String(format: "%.0f min", mins) }
        let h = Int(mins / 60); let m = Int(mins.truncatingRemainder(dividingBy: 60))
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }
}

struct StatCard: View {
    let title: String; let value: String; let icon: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.headline)
                    .padding(8)
                    .background(color.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Spacer()
            }
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.primary.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Focus Bar Chart
struct FocusBarChart: View {
    let stats: [DailyStat]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Focus Time").font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
            Chart {
                ForEach(stats) { stat in
                    BarMark(
                        x: .value("Date", stat.date, unit: .day),
                        y: .value("Minutes", stat.focusMinutes)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, Color(hex: "#e05c00")],
                                       startPoint: .bottom, endPoint: .top)
                    )
                    .cornerRadius(4)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        .foregroundStyle(Color.gray)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel().foregroundStyle(Color.gray)
                    AxisGridLine().foregroundStyle(Color.primary.opacity(0.08))
                }
            }
            .frame(height: 180)
            .chartPlotStyle { plot in
                plot.background(Color.clear)
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.06))
        .cornerRadius(16)
    }
}

// MARK: - Task Trend Chart (line chart)
struct TaskTrendChart: View {
    let stats: [DailyStat]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Completed Tasks Trend").font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
            Chart {
                ForEach(stats) { stat in
                    LineMark(
                        x: .value("Date", stat.date, unit: .day),
                        y: .value("Tasks", stat.completedTasks)
                    )
                    .foregroundStyle(Color.green)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", stat.date, unit: .day),
                        y: .value("Tasks", stat.completedTasks)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [Color.green.opacity(0.3), .clear],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", stat.date, unit: .day),
                        y: .value("Tasks", stat.completedTasks)
                    )
                    .foregroundStyle(Color.green)
                    .symbolSize(30)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        .foregroundStyle(Color.gray)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel().foregroundStyle(Color.gray)
                    AxisGridLine().foregroundStyle(Color.primary.opacity(0.08))
                }
            }
            .frame(height: 160)
            .chartPlotStyle { plot in plot.background(Color.clear) }
        }
        .padding(16)
        .background(Color.primary.opacity(0.06))
        .cornerRadius(16)
    }
}

// MARK: - Project Distribution (pie-like bar)
struct ProjectDistributionView: View {
    let stats: [ProjectStat]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time by Project").font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)

            ForEach(stats) { stat in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Circle().fill(Color(hex: stat.colorHex)).frame(width: 10, height: 10)
                        Text(stat.projectName).font(.caption).foregroundColor(.primary)
                        Spacer()
                        Text(String(format: "%.0f min · %.0f%%",
                                    stat.focusMinutes, stat.percentage * 100))
                            .font(.caption).foregroundColor(.gray)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.1))
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: stat.colorHex))
                                .frame(width: geo.size.width * stat.percentage, height: 8)
                                .animation(.easeInOut, value: stat.percentage)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.06))
        .cornerRadius(16)
    }
}

// MARK: - Focus Calendar Heatmap
struct FocusCalendarView: View {
    let sessions: [PomodoroSession]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let dayLabels = ["S","M","T","W","T","F","S"]

    var focusMap: [Date: Double] {
        var map: [Date: Double] = [:]
        for s in sessions where s.type == .focus && s.wasCompleted {
            let day = Calendar.current.startOfDay(for: s.startTime)
            map[day, default: 0] += s.durationMinutes
        }
        return map
    }

    var last30Days: [Date] {
        (0..<30).compactMap { Calendar.current.date(byAdding: .day, value: -29 + $0, to: Date().startOfDay) }
    }

    func color(for mins: Double) -> Color {
        if mins == 0 { return Color.primary.opacity(0.08) }
        if mins < 30 { return Color.orange.opacity(0.3) }
        if mins < 60 { return Color.orange.opacity(0.6) }
        if mins < 120 { return Color.orange.opacity(0.85) }
        return Color.orange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Focus Heatmap (Last 30 Days)")
                .font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)

            HStack(spacing: 4) {
                ForEach(Array(dayLabels.enumerated()), id: \.offset) { _, d in
                    Text(d).font(.caption2).foregroundColor(.gray).frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                // Padding for first weekday
                let firstWeekday = Calendar.current.component(.weekday, from: last30Days.first ?? Date()) - 1
                ForEach(0..<firstWeekday, id: \.self) { _ in Color.clear.frame(height: 28) }

                ForEach(last30Days, id: \.self) { day in
                    let mins = focusMap[day] ?? 0
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color(for: mins))
                        .frame(height: 28)
                        .overlay(
                            Text(Calendar.current.component(.day, from: day) == 1 ?
                                 "\(Calendar.current.component(.day, from: day))" : "")
                            .font(.system(size: 7)).foregroundColor(.white.opacity(0.4))
                        )
                }
            }

            // Legend
            HStack(spacing: 6) {
                Text("Less").font(.caption2).foregroundColor(.gray)
                ForEach([0.0, 20.0, 50.0, 80.0, 120.0], id: \.self) { m in
                    RoundedRectangle(cornerRadius: 2).fill(color(for: m)).frame(width: 14, height: 14)
                }
                Text("More").font(.caption2).foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.06))
        .cornerRadius(16)
    }
}
