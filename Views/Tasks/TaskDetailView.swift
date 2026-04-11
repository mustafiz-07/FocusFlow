// TaskDetailView.swift
import SwiftUI

struct TaskDetailView: View {
    @State var task: FTask
    @ObservedObject var taskVM: TaskViewModel
    @Environment(\.dismiss) var dismiss

    @State private var isEditing = false
    @State private var editTitle = ""
    @State private var editNote = ""
    @State private var editPriority: TaskPriority = .none
    @State private var editEstimated = 1
    @State private var newSubTaskText = ""
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color(hex: "#12121f") : .white).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Title section
                    VStack(alignment: .leading, spacing: 8) {
                        if isEditing {
                            TextField("Task title", text: $editTitle, axis: .vertical)
                                .font(.title2).fontWeight(.semibold).foregroundColor(.primary)
                                .padding(10)
                                .background(Color.primary.opacity(0.09))
                                .cornerRadius(10)
                        } else {
                            Text(task.title)
                                .font(.title2).fontWeight(.semibold).foregroundColor(.primary)
                        }

                        // Metadata row
                        HStack(spacing: 12) {
                            PriorityBadge(priority: task.priority)
                            if let proj = task.projectId {
                                Label(taskVM.projectName(for: proj), systemImage: "folder.fill")
                                    .font(.caption)
                                    .foregroundColor(Color(hex: taskVM.projectColor(for: proj)))
                            }
                            if task.isCompleted {
                                Label("Completed", systemImage: "checkmark.circle.fill")
                                    .font(.caption).foregroundColor(.green)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(14)

                    // Pomodoro progress
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Pomodoro Progress", systemImage: "timer").font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                            if isEditing {
                                Stepper("", value: $editEstimated, in: 1...20)
                                    .labelsHidden()
                            }
                            Text("\(task.completedPomodoros) / \(isEditing ? editEstimated : task.estimatedPomodoros)")
                                .font(.subheadline).fontWeight(.bold).foregroundColor(.orange)
                        }

                        // Progress dots
                        HStack(spacing: 6) {
                            ForEach(0..<(isEditing ? editEstimated : task.estimatedPomodoros), id: \.self) { i in
                                Circle()
                                    .fill(i < task.completedPomodoros ? Color.orange : Color.white.opacity(0.15))
                                    .frame(width: 16, height: 16)
                            }
                            Spacer()
                        }

                        let pct = task.estimatedPomodoros > 0 ?
                            Double(task.completedPomodoros) / Double(task.estimatedPomodoros) : 0
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.1))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 4).fill(Color.orange)
                                    .frame(width: geo.size.width * min(pct, 1), height: 6)
                                    .animation(.easeInOut, value: pct)
                            }
                        }
                        .frame(height: 6)
                    }
                    .padding(16)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(14)

                    // Due date & Reminder
                    VStack(spacing: 12) {
                        if let due = task.dueDate {
                            InfoRow(icon: "calendar", label: "Due Date", value: due.shortDateString,
                                    color: due < Date() && !task.isCompleted ? .red : .gray)
                        }
                        if let rem = task.reminderDate {
                            InfoRow(icon: "bell.fill", label: "Reminder", value: rem.shortDateString + " " + rem.shortTimeString, color: .yellow)
                        }
                        if task.recurring.type != .none {
                            InfoRow(icon: "repeat", label: "Recurring", value: task.recurring.type.rawValue.capitalized, color: .cyan)
                        }
                    }
                    .padding(16)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(14)

                    // Sub-tasks
                    if !task.subTasks.isEmpty || isEditing {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Sub-tasks")
                                .font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)

                            ForEach(task.subTasks.indices, id: \.self) { i in
                                HStack(spacing: 10) {
                                    Button {
                                        task.subTasks[i].isCompleted.toggle()
                                        Task { await taskVM.updateTask(task) }
                                    } label: {
                                        Image(systemName: task.subTasks[i].isCompleted ?
                                              "checkmark.circle.fill" : "circle")
                                        .foregroundColor(task.subTasks[i].isCompleted ? .green : .gray)
                                    }
                                    Text(task.subTasks[i].title)
                                        .font(.subheadline)
                                        .foregroundColor(task.subTasks[i].isCompleted ? .gray : .primary)
                                        .strikethrough(task.subTasks[i].isCompleted, color: .gray)
                                    Spacer()
                                }
                            }

                            if isEditing {
                                HStack {
                                    TextField("New sub-task...", text: $newSubTaskText)
                                        .foregroundColor(.primary).padding(10)
                                        .background(Color.primary.opacity(0.09)).cornerRadius(8)
                                    Button {
                                        guard !newSubTaskText.isEmpty else { return }
                                        task.subTasks.append(SubTask(title: newSubTaskText))
                                        newSubTaskText = ""
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.orange).font(.title3)
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(14)
                    }

                    // Note
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Note").font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
                        if isEditing {
                            TextField("Add a note...", text: $editNote, axis: .vertical)
                                .foregroundColor(.primary).padding(10)
                                .background(Color.primary.opacity(0.09)).cornerRadius(10)
                                .lineLimit(6)
                        } else if !task.note.isEmpty {
                            Text(task.note).font(.subheadline).foregroundColor(.gray)
                        } else {
                            Text("No note").font(.subheadline).foregroundColor(.gray.opacity(0.4))
                        }
                    }
                    .padding(16)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(14)

                    // Mark complete button
                    Button {
                        Task { await taskVM.toggleComplete(task) }
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: task.isCompleted ? "arrow.uturn.left.circle.fill" : "checkmark.circle.fill")
                            Text(task.isCompleted ? "Mark Incomplete" : "Mark Complete")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(task.isCompleted ? Color.gray.opacity(0.3) : Color.green.opacity(0.2))
                        .foregroundColor(task.isCompleted ? .gray : .green)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(task.isCompleted ? Color.gray : Color.green, lineWidth: 1.5))
                    }

                    Spacer(minLength: 40)
                }
                .padding(16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(colorScheme == .dark ? Color(hex: "#12121f") : .white, for: .navigationBar)
        .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        task.title = editTitle
                        task.note = editNote
                        task.priority = editPriority
                        task.estimatedPomodoros = editEstimated
                        Task { await taskVM.updateTask(task) }
                    } else {
                        editTitle = task.title
                        editNote = task.note
                        editPriority = task.priority
                        editEstimated = task.estimatedPomodoros
                    }
                    isEditing.toggle()
                }
                .foregroundColor(.orange)
            }
        }
    }
}

struct InfoRow: View {
    let icon: String; let label: String; let value: String; let color: Color
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(color).frame(width: 20)
            Text(label).font(.subheadline).foregroundColor(.gray)
            Spacer()
            Text(value).font(.subheadline).foregroundColor(.primary)
        }
    }
}

struct PriorityBadge: View {
    let priority: TaskPriority
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: priority.icon)
            Text(priority.label)
        }
        .font(.caption2).fontWeight(.semibold)
        .foregroundColor(Color(designColor: priority.color))
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color(designColor: priority.color).opacity(0.15))
        .cornerRadius(6)
    }
}
