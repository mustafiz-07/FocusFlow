// TaskListView.swift
import SwiftUI

struct TaskListView: View {
    @ObservedObject var taskVM: TaskViewModel
    @State private var showAddTask = false
    @State private var showAddProject = false
    @State private var selectedFilter: TaskFilter = .all
    @State private var selectedProjectId: String? = nil
    @State private var searchText = ""
    @Environment(\.colorScheme) private var colorScheme

    enum TaskFilter: String, CaseIterable {
        case today = "Today"
        case all = "All"
        case completed = "Done"
    }

    var filteredTasks: [FTask] {
        var result: [FTask]
        switch selectedFilter {
        case .today: result = taskVM.todayTasks
        case .all:   result = taskVM.activeTasks
        case .completed: result = taskVM.completedTasks
        }
        if let pid = selectedProjectId {
            result = result.filter { $0.projectId == pid }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.note.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result.sorted { lhs, rhs in
            if lhs.priority.rawValue != rhs.priority.rawValue {
                return lhs.priority.rawValue > rhs.priority.rawValue
            }
            if let d1 = lhs.dueDate, let d2 = rhs.dueDate { return d1 < d2 }
            if lhs.dueDate != nil { return true }
            if rhs.dueDate != nil { return false }
            return lhs.createdAt > rhs.createdAt
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color(hex: "#12121f") : .white).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search Bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
                        TextField("Search tasks...", text: $searchText)
                            .foregroundColor(.primary)
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(Color.primary.opacity(0.09))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Filter tabs
                    HStack(spacing: 0) {
                        ForEach(TaskFilter.allCases, id: \.self) { filter in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { selectedFilter = filter }
                            } label: {
                                Text(filter.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(selectedFilter == filter ? .semibold : .regular)
                                    .foregroundColor(selectedFilter == filter ? .primary : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(selectedFilter == filter ?
                                        Color.orange.opacity(0.2) : Color.clear)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)

                    // Project chips
                    if !taskVM.projects.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ProjectChip(name: "All", color: "#888888",
                                            isSelected: selectedProjectId == nil) {
                                    selectedProjectId = nil
                                }
                                ForEach(taskVM.projects) { proj in
                                    ProjectChip(name: proj.name, color: proj.colorHex,
                                                isSelected: selectedProjectId == proj.id) {
                                        selectedProjectId = selectedProjectId == proj.id ? nil : proj.id
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                        }
                    }

                    // Task list
                    if taskVM.isLoading {
                        Spacer()
                        ProgressView().tint(.orange)
                        Spacer()
                    } else if filteredTasks.isEmpty {
                        EmptyTasksView(filter: selectedFilter)
                    } else {
                        List {
                            ForEach(filteredTasks) { task in
                                NavigationLink(destination:
                                    TaskDetailView(task: task, taskVM: taskVM)
                                ) {
                                    TaskRowView(task: task, taskVM: taskVM)
                                }
                                .listRowBackground(Color.primary.opacity(0.05))
                                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task { await taskVM.deleteTask(task) }
                                    } label: { Label("Delete", systemImage: "trash") }

                                    Button {
                                        Task { await taskVM.toggleComplete(task) }
                                    } label: {
                                        Label(task.isCompleted ? "Undo" : "Done",
                                              systemImage: task.isCompleted ? "arrow.uturn.left" : "checkmark")
                                    }
                                    .tint(.green)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(colorScheme == .dark ? Color(hex: "#12121f") : .white, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button { showAddProject = true } label: {
                            Image(systemName: "folder.badge.plus").foregroundColor(.orange)
                        }
                        Button { showAddTask = true } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3).foregroundColor(.orange)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddTask) {
                AddTaskView(taskVM: taskVM, projects: taskVM.projects)
            }
            .sheet(isPresented: $showAddProject) {
                AddProjectView(taskVM: taskVM)
            }
            .onAppear {
                taskVM.loadData()
            }
        }
    }
}

// MARK: - Task Row
struct TaskRowView: View {
    let task: FTask
    @ObservedObject var taskVM: TaskViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                Task { await taskVM.toggleComplete(task) }
            } label: {
                ZStack {
                    Circle()
                        .stroke(priorityColor, lineWidth: 2)
                        .frame(width: 26, height: 26)
                    if task.isCompleted {
                        Circle().fill(priorityColor).frame(width: 26, height: 26)
                        Image(systemName: "checkmark")
                            .font(.caption).fontWeight(.bold).foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundColor(task.isCompleted ? .gray : .primary)
                    .strikethrough(task.isCompleted, color: .gray)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let proj = task.projectId {
                        Label(taskVM.projectName(for: proj), systemImage: "folder.fill")
                            .font(.caption2)
                            .foregroundColor(Color(hex: taskVM.projectColor(for: proj)))
                    }
                    if let due = task.dueDate {
                        Label(due.shortDateString, systemImage: "calendar")
                            .font(.caption2)
                            .foregroundColor(due < Date() && !task.isCompleted ? .red : .gray)
                    }
                    if !task.subTasks.isEmpty {
                        let done = task.subTasks.filter { $0.isCompleted }.count
                        Label("\(done)/\(task.subTasks.count)", systemImage: "list.bullet")
                            .font(.caption2).foregroundColor(.gray)
                    }
                }
            }

            Spacer()

            // Pomodoro count
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(task.completedPomodoros)/\(task.estimatedPomodoros)")
                    .font(.caption2).foregroundColor(.orange)
                Image(systemName: "timer").font(.caption2).foregroundColor(.orange.opacity(0.6))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.04))
        .cornerRadius(12)
    }

    var priorityColor: Color {
        switch task.priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        case .none: return .gray
        }
    }
}

// MARK: - Project Chip
struct ProjectChip: View {
    let name: String; let color: String; let isSelected: Bool; let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.caption).fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .primary : .secondary)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(isSelected
                    ? Color(hex: color).opacity(0.3)
                    : (colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.06)))
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color(hex: color) : Color.clear, lineWidth: 1.5))
        }
    }
}

// MARK: - Empty State
struct EmptyTasksView: View {
    let filter: TaskListView.TaskFilter
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: filter == .completed ? "checkmark.seal.fill" : "checkmark.circle")
                .font(.system(size: 52)).foregroundColor(.gray.opacity(0.4))
            Text(filter == .completed ? "No completed tasks yet" :
                 filter == .today ? "Nothing due today 🎉" : "No tasks yet")
                .font(.headline).foregroundColor(.gray)
            Text("Tap + to add your first task")
                .font(.caption).foregroundColor(.gray.opacity(0.6))
            Spacer()
        }
    }
}
