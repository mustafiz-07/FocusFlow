//
//  StudyRoomService.swift
//  FocusFlow
//
//  Created by mustaahh on 14/4/26.
//


import Foundation
import FirebaseFirestore
import Combine

final class StudyRoomService {

    static let shared = StudyRoomService()
    private let db = Firestore.firestore()
    private let roomsCollection   = "studyRooms"
    private let leaderCollection  = "leaderboard"

    private init() {}

    // MARK: - Create Room

    func createRoom(_ room: StudyRoom) async throws -> String {
        let ref = db.collection(roomsCollection).document()
        let data = try Firestore.Encoder().encode(room)
        try await ref.setData(data)
        return ref.documentID
    }

    // MARK: - Listen to Active Rooms

    func listenToActiveRooms() -> AnyPublisher<[StudyRoom], Error> {
        let subject = PassthroughSubject<[StudyRoom], Error>()
        db.collection(roomsCollection)
            .whereField("stateRaw", in: [StudyRoom.RoomState.waiting.rawValue,
                                         StudyRoom.RoomState.running.rawValue])
            .addSnapshotListener { snapshot, error in
                if let error { subject.send(completion: .failure(error)); return }
                let rooms = (snapshot?.documents ?? []).compactMap {
                    try? $0.data(as: StudyRoom.self)
                }
                .sorted { $0.createdAt > $1.createdAt }

                subject.send(Array(rooms.prefix(30)))
            }
        return subject.eraseToAnyPublisher()
    }

    // MARK: - Listen to Single Room

    func listenToRoom(id: String) -> AnyPublisher<StudyRoom?, Error> {
        let subject = PassthroughSubject<StudyRoom?, Error>()
        db.collection(roomsCollection).document(id)
            .addSnapshotListener { snapshot, error in
                if let error { subject.send(completion: .failure(error)); return }
                let room = try? snapshot?.data(as: StudyRoom.self)
                subject.send(room)
            }
        return subject.eraseToAnyPublisher()
    }

    // MARK: - Join / Leave

    func joinRoom(roomId: String, participant: RoomParticipant) async throws {
        let data = try Firestore.Encoder().encode(participant)
        try await db.collection(roomsCollection).document(roomId).updateData([
            "participants": FieldValue.arrayUnion([data])
        ])
    }

    func leaveRoom(roomId: String, participantId: String) async throws {
        // Re-fetch doc → remove participant → write back
        let ref = db.collection(roomsCollection).document(roomId)
        let snap = try await ref.getDocument()
        guard var room = try? snap.data(as: StudyRoom.self) else { return }
        room.participants.removeAll { $0.id == participantId }
        let updatedArray = try room.participants.map { try Firestore.Encoder().encode($0) }
        try await ref.updateData(["participants": updatedArray])
    }

    // MARK: - Room State

    func startRoom(roomId: String) async throws {
        try await db.collection(roomsCollection).document(roomId).updateData([
            "stateRaw":   StudyRoom.RoomState.running.rawValue,
            "startedAt":  Timestamp(date: Date()),
            "focusSessionCount": FieldValue.increment(Int64(1))
        ])
    }

    func pauseRoom(roomId: String) async throws {
        try await db.collection(roomsCollection).document(roomId).updateData([
            "stateRaw": StudyRoom.RoomState.paused.rawValue
        ])
    }

    func resumeRoom(roomId: String) async throws {
        try await db.collection(roomsCollection).document(roomId).updateData([
            "stateRaw":  StudyRoom.RoomState.running.rawValue,
            "startedAt": Timestamp(date: Date())
        ])
    }

    func endRoom(roomId: String) async throws {
        try await db.collection(roomsCollection).document(roomId).updateData([
            "stateRaw": StudyRoom.RoomState.ended.rawValue
        ])
    }

    // MARK: - Leaderboard

    func fetchLeaderboard() async throws -> [LeaderboardEntry] {
        let snap = try await db.collection(leaderCollection)
            .order(by: "weeklyMinutes", descending: true)
            .limit(to: 20)
            .getDocuments()
        return snap.documents.compactMap { try? $0.data(as: LeaderboardEntry.self) }
    }

    func upsertLeaderboardEntry(_ entry: LeaderboardEntry) async throws {
        guard !entry.uid.isEmpty else { return }
        let ref = db.collection(leaderCollection).document(entry.uid)
        let data = try Firestore.Encoder().encode(entry)
        try await ref.setData(data, merge: true)
    }
}

// MARK: - FirebaseService extension: UserProgress

extension FirebaseService {

    // users/{uid}/gamification/progress
    private func progressRef(uid: String) -> DocumentReference {
        Firestore.firestore()
            .collection("users").document(uid)
            .collection("gamification").document("progress")
    }

    func fetchUserProgress(uid: String) async throws -> UserProgress {
        let doc = try await progressRef(uid: uid).getDocument()
        return (try? doc.data(as: UserProgress.self)) ?? UserProgress()
    }

    func saveUserProgress(_ progress: UserProgress, uid: String) async throws {
        try progressRef(uid: uid).setData(from: progress, merge: true)
    }
}
