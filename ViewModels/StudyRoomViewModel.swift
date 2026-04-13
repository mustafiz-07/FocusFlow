//
//  StudyRoomViewModel.swift
//  FocusFlow
//
//  Created by mustaahh on 14/4/26.
//


import Foundation
import Combine
import FirebaseAuth

@MainActor
final class StudyRoomViewModel: ObservableObject {

    // MARK: - Published

    @Published var activeRooms: [StudyRoom] = []
    @Published var currentRoom: StudyRoom? = nil
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingLeaderboard: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isInRoom: Bool = false

    // MARK: - Timer for live countdown

    @Published var liveSecondsRemaining: Int = 0
    private var countdownTimer: AnyCancellable? = nil

    // MARK: - Private

    private var uid: String?        { AuthService.shared.uid }
    private var displayName: String {
        AuthService.shared.currentUser?.displayName
        ?? AuthService.shared.currentUser?.email?.components(separatedBy: "@").first
        ?? "Anon"
    }
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Load Rooms

    func startListeningToRooms() {
        isLoading = true
        StudyRoomService.shared.listenToActiveRooms()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let e) = completion { self?.errorMessage = e.localizedDescription }
                },
                receiveValue: { [weak self] rooms in
                    self?.isLoading = false
                    self?.activeRooms = rooms
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Create Room

    func createRoom(name: String, topic: String, durationMinutes: Int) async {
        guard let uid else { return }
        let room = StudyRoom(
            name:                name,
            hostUID:             uid,
            hostName:            displayName,
            topic:               topic,
            timerDurationSeconds: durationMinutes * 60
        )
        do {
            let id = try await StudyRoomService.shared.createRoom(room)
            listenToRoom(id: id)
            let me = RoomParticipant(id: uid, displayName: displayName)
            try await StudyRoomService.shared.joinRoom(roomId: id, participant: me)
            isInRoom = true
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Join Room

    func joinRoom(_ room: StudyRoom) async {
        guard let uid, let roomId = room.id else { return }
        guard !room.isFull else { errorMessage = "This room is full."; return }
        let me = RoomParticipant(id: uid, displayName: displayName)
        do {
            try await StudyRoomService.shared.joinRoom(roomId: roomId, participant: me)
            listenToRoom(id: roomId)
            isInRoom = true
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Leave Room

    func leaveCurrentRoom() async {
        guard let uid, let room = currentRoom, let roomId = room.id else { return }
        do {
            try await StudyRoomService.shared.leaveRoom(roomId: roomId, participantId: uid)
            if room.hostUID == uid { try? await StudyRoomService.shared.endRoom(roomId: roomId) }
        } catch { errorMessage = error.localizedDescription }
        currentRoom = nil
        isInRoom = false
        stopCountdown()
    }

    // MARK: - Start / Pause / Resume (host only)

    func startRoom() async {
        guard let id = currentRoom?.id else { return }
        do {
            try await StudyRoomService.shared.startRoom(roomId: id)
        } catch { errorMessage = error.localizedDescription }
    }

    func pauseRoom() async {
        guard let id = currentRoom?.id else { return }
        do {
            try await StudyRoomService.shared.pauseRoom(roomId: id)
        } catch { errorMessage = error.localizedDescription }
        stopCountdown()
    }

    func endRoom() async {
        guard let id = currentRoom?.id else { return }
        do {
            try await StudyRoomService.shared.endRoom(roomId: id)
        } catch { errorMessage = error.localizedDescription }
        currentRoom = nil
        isInRoom = false
        stopCountdown()
    }

    // MARK: - Leaderboard

    func loadLeaderboard() {
        isLoadingLeaderboard = true
        Task {
            do {
                leaderboard = try await StudyRoomService.shared.fetchLeaderboard()
            } catch { errorMessage = error.localizedDescription }
            isLoadingLeaderboard = false
        }
    }

    func updateMyLeaderboardEntry(weeklyMinutes: Int, totalMinutes: Int, streak: Int, level: Int) {
        guard let uid else { return }
        let entry = LeaderboardEntry(
            uid: uid, displayName: displayName,
            weeklyMinutes: weeklyMinutes, totalMinutes: totalMinutes,
            currentStreak: streak, levelNumber: level
        )
        Task { try? await StudyRoomService.shared.upsertLeaderboardEntry(entry) }
    }

    // MARK: - Private: Listen to single room

    private func listenToRoom(id: String) {
        StudyRoomService.shared.listenToRoom(id: id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] room in
                    self?.currentRoom = room
                    self?.syncCountdown(with: room)
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Countdown

    private func syncCountdown(with room: StudyRoom?) {
        guard let room else { stopCountdown(); return }
        switch room.roomState {
        case .running:
            liveSecondsRemaining = room.remainingSeconds ?? room.timerDurationSeconds
            startCountdown()
        case .paused:
            liveSecondsRemaining = room.timerDurationSeconds
            stopCountdown()
        case .waiting:
            liveSecondsRemaining = room.timerDurationSeconds
            stopCountdown()
        case .ended:
            liveSecondsRemaining = 0
            stopCountdown()
        }
    }

    private func startCountdown() {
        countdownTimer?.cancel()
        countdownTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.liveSecondsRemaining > 0 {
                    self.liveSecondsRemaining -= 1
                } else {
                    self.stopCountdown()
                }
            }
    }

    private func stopCountdown() {
        countdownTimer?.cancel()
        countdownTimer = nil
    }

    // MARK: - Helpers

    var isHost: Bool {
        guard let uid else { return false }
        return currentRoom?.hostUID == uid
    }

    var myParticipant: RoomParticipant? {
        guard let uid else { return nil }
        return currentRoom?.participants.first { $0.id == uid }
    }
}

