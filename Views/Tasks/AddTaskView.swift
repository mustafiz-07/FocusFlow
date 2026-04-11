// AddTaskView.swift
import SwiftUI

struct AddTaskView: View {
    @ObservedObject var taskVM: TaskViewModel
    let projects: [Project]
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var note = ""
    @State private var priority: TaskPriority = .none
    @State private var dueDate: Date = Date()
    @State private var hasDueDate = false
    @State private var reminderDate: Date = Date()
    @State private var hasReminder = false
    @State private var selectedProjectId: String? = nil
    @State private var estimatedPomodoros: Int = 1
    @State private var subTaskText = ""
    @State private var subTasks: [SubTask] = []
    @State private var recurringType: RecurringType = .none
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color(hex: "#12121f") : .white).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // Title
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Task Title", systemImage: "pencil")
                                .font(.caption).foregroundColor(.gray)
                            TextField("What needs to be done?", text: $title, axis: .vertical)
                                .foregroundColor(.primary)
                                .padding(12)
                                .background(Color.primary.opacity(0.09))
                                .cornerRadius(10)
                                .lineLimit(3)
                        }

                        // Priority
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Priority", systemImage: "flag.fill").font(.caption).foregroundColor(.gray)
                            HStack(spacing: 8) {
                                ForEach(TaskPriority.allCases, id: \.self) { p in
                                    Button {
                                        priority = p
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: p.icon)
                                            Text(p.label)
                                        }
                                        .font(.caption).fontWeight(.medium)
                                        .foregroundColor(priority == p ? .primary : .secondary)
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(priority == p ?
                                            Color(designColor: p.color).opacity(0.3) : Color.primary.opacity(0.08))
                                        .cornerRadius(8)
                                        .overlay(RoundedRectangle(cornerRadius: 8)
                                            .stroke(priority == p ? Color(designColor: p.color) : Color.clear, lineWidth: 1.5))
                                    }
                                }
                            }
                        }

                        // Project
                        if !projects.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Project", systemImage: "folder.fill").font(.caption).foregroundColor(.gray)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ProjectChip(name: "None", color: "#888888",
                                                    isSelected: selectedProjectId == nil) {
                                            selectedProjectId = nil
                                        }
                                        ForEach(projects) { p in
                                            ProjectChip(name: p.name, color: p.colorHex,
                                                        isSelected: selectedProjectId == p.id) {
                                                selectedProjectId = p.id
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Due date
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: $hasDueDate) {
                                Label("Due Date", systemImage: "calendar").font(.subheadline).foregroundColor(.primary)
                            }
                            .tint(.orange)
                            if hasDueDate {
                                DatePicker("", selection: $dueDate, displayedComponents: .date)
                                    .datePickerStyle(.graphical)
                                    .accentColor(.orange)
                            }
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.08))
                        .cornerRadius(12)

                        // Reminder
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: $hasReminder) {
                                Label("Reminder", systemImage: "bell.fill").font(.subheadline).foregroundColor(.primary)
                            }
                            .tint(.orange)
                            if hasReminder {
                                DatePicker("", selection: $reminderDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .accentColor(.orange)
                            }
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.08))
                        .cornerRadius(12)

                        // Recurring
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Recurring", systemImage: "repeat").font(.caption).foregroundColor(.gray)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(RecurringType.allCases, id: \.self) { r in
                                        Button {
                                            recurringType = r
                                        } label: {
                                            Text(r.rawValue.capitalized)
                                                .font(.caption).fontWeight(.medium)
                                                .foregroundColor(recurringType == r ? .primary : .secondary)
                                                .padding(.horizontal, 12).padding(.vertical, 6)
                                                .background(recurringType == r ?
                                                    Color.orange.opacity(0.2) : Color.primary.opacity(0.08))
                                                .cornerRadius(8)
                                                .overlay(RoundedRectangle(cornerRadius: 8)
                                                    .stroke(recurringType == r ? Color.orange : Color.clear, lineWidth: 1.5))
                                        }
                                    }
                                }
                            }
                        }

                        // Estimated Pomodoros
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Estimated Pomodoros", systemImage: "timer").font(.caption).foregroundColor(.gray)
                            HStack {
                                Button { if estimatedPomodoros > 1 { estimatedPomodoros -= 1 } } label: {
                                    Image(systemName: "minus.circle.fill").font(.title3).foregroundColor(.orange)
                                }
                                Text("\(estimatedPomodoros)").font(.title3).fontWeight(.bold).foregroundColor(.primary)
                                    .frame(width: 32)
                                Button { estimatedPomodoros += 1 } label: {
                                    Image(systemName: "plus.circle.fill").font(.title3).foregroundColor(.orange)
                                }
                                Spacer()
                                Text("≈ \(estimatedPomodoros * 25) min").font(.caption).foregroundColor(.gray)
                            }
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.08))
                        .cornerRadius(12)

                        // Sub-tasks
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Sub-tasks", systemImage: "list.bullet").font(.caption).foregroundColor(.gray)
                            HStack {
                                TextField("Add sub-task...", text: $subTaskText)
                                    .foregroundColor(.primary)
                                    .padding(10)
                                    .background(Color.primary.opacity(0.09))
                                    .cornerRadius(8)
                                Button {
                                    guard !subTaskText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                                    subTasks.append(SubTask(title: subTaskText.trimmingCharacters(in: .whitespaces)))
                                    subTaskText = ""
                                } label: {
                                    Image(systemName: "plus.circle.fill").font(.title3).foregroundColor(.orange)
                                }
                            }
                            ForEach(subTasks.indices, id: \.self) { i in
                                HStack {
                                    Image(systemName: "circle").foregroundColor(.gray)
                                    Text(subTasks[i].title).font(.subheadline).foregroundColor(.primary)
                                    Spacer()
                                    Button { subTasks.remove(at: i) } label: {
                                        Image(systemName: "xmark").font(.caption).foregroundColor(.gray)
                                    }
                                }
                                .padding(.horizontal, 8)
                            }
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.08))
                        .cornerRadius(12)

                        // Note
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Note", systemImage: "note.text").font(.caption).foregroundColor(.gray)
                            TextField("Add a note...", text: $note, axis: .vertical)
                                .foregroundColor(.primary)
                                .padding(12)
                                .background(Color.primary.opacity(0.09))
                                .cornerRadius(10)
                                .lineLimit(5)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(colorScheme == .dark ? Color(hex: "#12121f") : .white, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.gray)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let task = FTask(
                            title: title.trimmingCharacters(in: .whitespaces),
                            note: note, priority: priority,
                            dueDate: hasDueDate ? dueDate : nil,
                            reminderDate: hasReminder ? reminderDate : nil,
                            projectId: selectedProjectId,
                            subTasks: subTasks,
                            estimatedPomodoros: estimatedPomodoros,
                            recurring: RecurringRule(type: recurringType)
                        )
                        Task { await taskVM.addTask(task) }
                        dismiss()
                    }
                    .foregroundColor(.orange)
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Add Project
struct AddProjectView: View {
    @ObservedObject var taskVM: TaskViewModel
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var selectedColor = "#4A90E2"
    @State private var selectedIcon = "folder.fill"
    @Environment(\.colorScheme) private var colorScheme

    let colors = ["#4A90E2","#E24A4A","#4AE27A","#E2B84A","#AE4AE2","#4AE2D4","#E2774A","#E24A98"]
    let icons = ["folder.fill","book.fill","laptopcomputer","dumbbell.fill","music.note","paintbrush.fill","briefcase.fill","cart.fill"]

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color(hex: "#12121f") : .white).ignoresSafeArea()
                VStack(spacing: 24) {
                    // Preview
                    HStack(spacing: 12) {
                        Image(systemName: selectedIcon)
                            .font(.title2)
                            .foregroundColor(Color(hex: selectedColor))
                        Text(name.isEmpty ? "Project Name" : name)
                            .font(.headline)
                            .foregroundColor(name.isEmpty ? .gray : .primary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(hex: selectedColor).opacity(0.15))
                    .cornerRadius(14)

                    TextField("Project name", text: $name)
                        .foregroundColor(.primary)
                        .padding(14)
                        .background(Color.primary.opacity(0.09))
                        .cornerRadius(12)

                    // Color picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color").font(.caption).foregroundColor(.gray)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                            ForEach(colors, id: \.self) { c in
                                Circle()
                                    .fill(Color(hex: c))
                                    .frame(width: 32, height: 32)
                                    .overlay(Circle().stroke(Color.primary, lineWidth: selectedColor == c ? 3 : 0))
                                    .onTapGesture { selectedColor = c }
                            }
                        }
                    }

                    // Icon picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Icon").font(.caption).foregroundColor(.gray)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                            ForEach(icons, id: \.self) { i in
                                Image(systemName: i)
                                    .font(.title3)
                                    .foregroundColor(selectedIcon == i ? Color(hex: selectedColor) : .gray)
                                    .frame(width: 36, height: 36)
                                    .background(selectedIcon == i ? Color(hex: selectedColor).opacity(0.2) : Color.primary.opacity(0.08))
                                    .cornerRadius(8)
                                    .onTapGesture { selectedIcon = i }
                            }
                        }
                    }
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(colorScheme == .dark ? Color(hex: "#12121f") : .white, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.gray)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let p = Project(name: name, colorHex: selectedColor, icon: selectedIcon)
                        Task { await taskVM.addProject(p) }
                        dismiss()
                    }
                    .foregroundColor(.orange).fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
