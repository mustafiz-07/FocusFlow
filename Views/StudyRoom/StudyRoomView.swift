//
//  StudyRoomView.swift
//  FocusFlow
//
//  Created by mustaahh on 14/4/26.
//


import SwiftUI

struct StudyRoomView: View {
    @ObservedObject var vm: StudyRoomViewModel
    @ObservedObject var gamificationVM: GamificationViewModel
    @State private var selectedTab: RoomTab = .rooms
    @State private var showCreateSheet = false
    @Environment(\.colorScheme) private var colorScheme

    enum RoomTab: String, CaseIterable {
        case rooms = "Rooms"; case leaderboard = "Leaderboard"
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

                    // Tab Picker
                    Picker("", selection: $selectedTab) {
                        ForEach(RoomTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(16)

                    // Active Room Banner
                    if vm.isInRoom, let room = vm.currentRoom {
                        ActiveRoomBanner(room: room, vm: vm)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }

                    if selectedTab == .rooms {
                        RoomListContent(vm: vm, gamificationVM: gamificationVM, showCreate: $showCreateSheet)
                    } else {
                        LeaderboardContent(vm: vm)
                    }
                }
            }
            .navigationTitle("Study Rooms")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(colorScheme == .dark ? Color(hex: "#12121f") : .white, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .toolbar {
                if selectedTab == .rooms && !vm.isInRoom {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showCreateSheet = true } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.orange).font(.title3)
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateRoomSheet(vm: vm, gamificationVM: gamificationVM)
            }
            .onAppear {
                vm.startListeningToRooms()
                vm.loadLeaderboard()
            }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
                Button("OK") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }
}

// MARK: - Room List

private struct RoomListContent: View {
    @ObservedObject var vm: StudyRoomViewModel
    @ObservedObject var gamificationVM: GamificationViewModel
    @Binding var showCreate: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                if vm.isLoading {
                    ProgressView().tint(.orange).padding(40)
                } else if vm.activeRooms.isEmpty {
                    EmptyRoomsView { showCreate = true }
                } else {
                    ForEach(vm.activeRooms) { room in
                        RoomCard(room: room, vm: vm, gamificationVM: gamificationVM)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
    }
}

// MARK: - Room Card

private struct RoomCard: View {
    let room: StudyRoom
    @ObservedObject var vm: StudyRoomViewModel
    @ObservedObject var gamificationVM: GamificationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                // State dot
                Circle()
                    .fill(room.roomState == .running ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                    .overlay(room.roomState == .running
                             ? Circle().stroke(Color.green.opacity(0.4), lineWidth: 2).scaleEffect(1.8)
                             : nil)

                Text(room.name)
                    .font(.headline).fontWeight(.semibold).foregroundColor(.primary)
                Spacer()
                Text(stateLabel(room.roomState))
                    .font(.caption).foregroundColor(room.roomState == .running ? .green : .orange)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.primary.opacity(0.08)).cornerRadius(8)
            }

            if !room.topic.isEmpty {
                Text(room.topic)
                    .font(.subheadline).foregroundColor(.gray).lineLimit(1)
            }

            HStack(spacing: 16) {
                Label("\(room.participantCount)/\(room.maxParticipants)", systemImage: "person.2.fill")
                    .font(.caption).foregroundColor(.gray)
                Label("\(room.timerDurationSeconds / 60) min", systemImage: "timer")
                    .font(.caption).foregroundColor(.gray)
                Spacer()
                Label("\(room.focusSessionCount) sessions", systemImage: "flame.fill")
                    .font(.caption).foregroundColor(.orange)
            }

            // Participants avatars
            if !room.participants.isEmpty {
                HStack(spacing: -8) {
                    ForEach(room.participants.prefix(5)) { p in
                        Circle()
                            .fill(Color.orange.opacity(0.3))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Text(p.avatarInitial)
                                    .font(.caption2).fontWeight(.bold).foregroundColor(.primary)
                            )
                            .overlay(Circle().stroke(Color(hex: "#12121f"), lineWidth: 1.5))
                    }
                    if room.participants.count > 5 {
                        Text("+\(room.participants.count - 5)")
                            .font(.caption2).foregroundColor(.gray)
                            .padding(.leading, 14)
                    }
                }
            }

            // Join button
            if !vm.isInRoom {
                Button {
                    Task {
                        await vm.joinRoom(room)
                        gamificationVM.joinedRoom()
                    }
                } label: {
                    Text("Join Room")
                        .font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(room.isFull ? Color.gray.opacity(0.2) : Color.orange)
                        .cornerRadius(10)
                }
                .disabled(room.isFull)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.primary.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1))
        )
    }

    func stateLabel(_ state: StudyRoom.RoomState) -> String {
        switch state {
        case .waiting: return "Waiting"
        case .running: return "In Focus"
        case .paused:  return "Paused"
        case .ended:   return "Ended"
        }
    }
}

// MARK: - Active Room Banner

struct ActiveRoomBanner: View {
    let room: StudyRoom
    @ObservedObject var vm: StudyRoomViewModel

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("🔴 You're in a room")
                        .font(.caption).foregroundColor(.orange)
                    Text(room.name)
                        .font(.headline).fontWeight(.bold).foregroundColor(.primary)
                }
                Spacer()
                // Live countdown
                Text(vm.liveSecondsRemaining.timerString)
                    .font(.title2).fontWeight(.bold).monospacedDigit()
                    .foregroundColor(room.roomState == .running ? .orange : .gray)
            }

            // Host controls
            if vm.isHost {
                HStack(spacing: 10) {
                    switch room.roomState {
                    case .waiting:
                        RoomControlButton(label: "Start", icon: "play.fill", color: .green) {
                            Task { await vm.startRoom() }
                        }
                    case .running:
                        RoomControlButton(label: "Pause", icon: "pause.fill", color: .yellow) {
                            Task { await vm.pauseRoom() }
                        }
                    case .paused:
                        RoomControlButton(label: "Resume", icon: "play.fill", color: .green) {
                            Task { await vm.startRoom() }
                        }
                    case .ended: EmptyView()
                    }

                    RoomControlButton(label: "End", icon: "stop.fill", color: .red) {
                        Task { await vm.endRoom() }
                    }
                }
            } else {
                Button {
                    Task { await vm.leaveCurrentRoom() }
                } label: {
                    Label("Leave Room", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.subheadline).foregroundColor(.red)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(Color.red.opacity(0.1)).cornerRadius(10)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1.5))
        )
    }
}

struct RoomControlButton: View {
    let label: String; let icon: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.subheadline).fontWeight(.medium)
            }
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(color.opacity(0.2))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.4), lineWidth: 1))
            .cornerRadius(10)
        }
    }
}

// MARK: - Leaderboard

private struct LeaderboardContent: View {
    @ObservedObject var vm: StudyRoomViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                if vm.isLoadingLeaderboard {
                    ProgressView().tint(.orange).padding(40)
                } else if vm.leaderboard.isEmpty {
                    Text("No data yet — start focusing!")
                        .foregroundColor(.gray).padding(40)
                } else {
                    ForEach(Array(vm.leaderboard.enumerated()), id: \.element.id) { idx, entry in
                        LeaderboardRow(rank: idx + 1, entry: entry)
                            .padding(.horizontal, 16)
                        if idx < vm.leaderboard.count - 1 {
                            Divider().background(Color.primary.opacity(0.08)).padding(.horizontal, 16)
                        }
                    }
                }
            }
            .padding(.bottom, 30)
        }
    }
}

private struct LeaderboardRow: View {
    let rank: Int; let entry: LeaderboardEntry

    var rankColor: Color {
        switch rank { case 1: return Color(hex: "#FFD700"); case 2: return .gray; case 3: return Color(hex: "#CD7F32"); default: return .gray.opacity(0.5) }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Rank
            Text(rank <= 3 ? ["🥇","🥈","🥉"][rank-1] : "#\(rank)")
                .font(rank <= 3 ? .title2 : .headline)
                .frame(width: 36)

            // Avatar
            Circle()
                .fill(Color.orange.opacity(0.25))
                .frame(width: 40, height: 40)
                .overlay(Text(entry.avatarInitial)
                    .font(.headline).fontWeight(.bold).foregroundColor(.primary))

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
                HStack(spacing: 8) {
                    Label("\(entry.weeklyMinutes) min", systemImage: "clock.fill")
                        .font(.caption).foregroundColor(.gray)
                    Label("\(entry.currentStreak)🔥", systemImage: "")
                        .font(.caption).foregroundColor(.orange)
                }
            }

            Spacer()

            // Level badge
            Text("Lv \(entry.levelNumber)")
                .font(.caption).fontWeight(.bold).foregroundColor(.orange)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.orange.opacity(0.15)).cornerRadius(8)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Empty State

private struct EmptyRoomsView: View {
    let onCreate: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 50)).foregroundColor(.gray.opacity(0.4))
            Text("No active rooms").font(.headline).foregroundColor(.primary)
            Text("Be the first to create a study session!")
                .font(.subheadline).foregroundColor(.gray).multilineTextAlignment(.center)
            Button(action: onCreate) {
                Label("Create Room", systemImage: "plus.circle.fill")
                    .font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color.orange).cornerRadius(12)
            }
        }
        .padding(40)
    }
}

// MARK: - Create Room Sheet

struct CreateRoomSheet: View {
    @ObservedObject var vm: StudyRoomViewModel
    @ObservedObject var gamificationVM: GamificationViewModel
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var topic: String = ""
    @State private var durationMinutes: Int = 25
    @State private var maxParticipants: Int = 10
    @State private var isCreating: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    let durations = [15, 20, 25, 30, 45, 50, 60]

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color(hex: "#12121f") : .white).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        formField(label: "Room Name", icon: "person.2.fill") {
                            TextField("e.g. WWDC Study Group", text: $name)
                                .foregroundColor(.primary).padding(12)
                                .background(Color.primary.opacity(0.08)).cornerRadius(10)
                        }

                        formField(label: "Topic (optional)", icon: "text.bubble.fill") {
                            TextField("e.g. iOS Development", text: $topic)
                                .foregroundColor(.primary).padding(12)
                                .background(Color.primary.opacity(0.08)).cornerRadius(10)
                        }

                        formField(label: "Session Duration", icon: "timer") {
                            HStack(spacing: 8) {
                                ForEach(durations, id: \.self) { dur in
                                    Button {
                                        durationMinutes = dur
                                    } label: {
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

                        formField(label: "Max Participants", icon: "person.badge.plus") {
                            HStack {
                                Stepper("", value: $maxParticipants, in: 2...50)
                                    .labelsHidden()
                                Text("\(maxParticipants)")
                                    .font(.headline).foregroundColor(.orange).frame(width: 36)
                                Spacer()
                            }
                        }

                        Button {
                            guard !name.isEmpty else { return }
                            isCreating = true
                            Task {
                                await vm.createRoom(name: name, topic: topic, durationMinutes: durationMinutes)
                                gamificationVM.hostedRoom()
                                isCreating = false
                                dismiss()
                            }
                        } label: {
                            Group {
                                if isCreating {
                                    ProgressView().tint(.white)
                                } else {
                                    Label("Create Room", systemImage: "plus.circle.fill")
                                        .font(.headline).foregroundColor(.primary)
                                }
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(name.isEmpty ? Color.gray.opacity(0.3) : Color.orange)
                            .cornerRadius(14)
                        }
                        .disabled(name.isEmpty || isCreating)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Create Room")
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

    @ViewBuilder
    func formField<Content: View>(label: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon).font(.caption).foregroundColor(.gray)
            content()
        }
    }
}
