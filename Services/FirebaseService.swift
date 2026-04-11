// FirebaseService.swift
import Foundation
import FirebaseFirestore
import Combine

class FirebaseService {
    static let shared = FirebaseService()
    private let db = Firestore.firestore()

    // MARK: - Settings
    func saveSettings(_ settings: UserSettings, uid: String) async throws {
        let ref = db.collection("users").document(uid).collection("settings").document("preferences")
        try ref.setData(from: settings, merge: true)
    }

    func fetchSettings(uid: String) async throws -> UserSettings {
        let ref = db.collection("users").document(uid).collection("settings").document("preferences")
        let doc = try await ref.getDocument()
        return (try? doc.data(as: UserSettings.self)) ?? UserSettings()
    }

    // MARK: - Tasks
    func addTask(_ task: FTask, uid: String) async throws -> String {
        let ref = try db.collection("users").document(uid).collection("tasks").addDocument(from: task)
        return ref.documentID
    }

    func updateTask(_ task: FTask, uid: String) async throws {
        guard let id = task.id else { return }
        try db.collection("users").document(uid).collection("tasks").document(id).setData(from: task, merge: true)
    }

    func deleteTask(id: String, uid: String) async throws {
        try await db.collection("users").document(uid).collection("tasks").document(id).delete()
    }

    func fetchTasks(uid: String) -> AnyPublisher<[FTask], Error> {
        let subject = PassthroughSubject<[FTask], Error>()
        db.collection("users").document(uid).collection("tasks")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error { subject.send(completion: .failure(error)); return }
                let tasks = (snapshot?.documents ?? []).compactMap { try? $0.data(as: FTask.self) }
                subject.send(tasks)
            }
        return subject.eraseToAnyPublisher()
    }

    // MARK: - Projects
    func addProject(_ project: Project, uid: String) async throws -> String {
        let ref = try db.collection("users").document(uid).collection("projects").addDocument(from: project)
        return ref.documentID
    }

    func updateProject(_ project: Project, uid: String) async throws {
        guard let id = project.id else { return }
        try db.collection("users").document(uid).collection("projects").document(id).setData(from: project, merge: true)
    }

    func deleteProject(id: String, uid: String) async throws {
        try await db.collection("users").document(uid).collection("projects").document(id).delete()
    }

    func fetchProjects(uid: String) -> AnyPublisher<[Project], Error> {
        let subject = PassthroughSubject<[Project], Error>()
        db.collection("users").document(uid).collection("projects")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error { subject.send(completion: .failure(error)); return }
                let projects = (snapshot?.documents ?? []).compactMap { try? $0.data(as: Project.self) }
                subject.send(projects)
            }
        return subject.eraseToAnyPublisher()
    }

    // MARK: - Sessions
    func saveSession(_ session: PomodoroSession, uid: String, documentId: String? = nil) async throws -> String {
        if let documentId {
            try db.collection("users").document(uid).collection("sessions").document(documentId)
                .setData(from: session, merge: true)
            return documentId
        }

        let ref = try db.collection("users").document(uid).collection("sessions").addDocument(from: session)
        return ref.documentID
    }

    func fetchSessions(uid: String, from startDate: Date, to endDate: Date) async throws -> [PomodoroSession] {
        let snapshot = try await db.collection("users").document(uid).collection("sessions")
            .whereField("startTime", isGreaterThanOrEqualTo: startDate)
            .whereField("startTime", isLessThanOrEqualTo: endDate)
            .order(by: "startTime", descending: false)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: PomodoroSession.self) }
    }

    func fetchAllSessions(uid: String) -> AnyPublisher<[PomodoroSession], Error> {
        let subject = PassthroughSubject<[PomodoroSession], Error>()
        db.collection("users").document(uid).collection("sessions")
            .order(by: "startTime", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error { subject.send(completion: .failure(error)); return }
                let sessions = (snapshot?.documents ?? []).compactMap { try? $0.data(as: PomodoroSession.self) }
                subject.send(sessions)
            }
        return subject.eraseToAnyPublisher()
    }

    // MARK: - Delete All User Data
    func deleteAllUserData(uid: String) async throws {
        let collections = ["tasks", "projects", "sessions", "settings"]
        for col in collections {
            let docs = try await db.collection("users").document(uid).collection(col).getDocuments()
            for doc in docs.documents { try await doc.reference.delete() }
        }
        try await db.collection("users").document(uid).delete()
    }
}
