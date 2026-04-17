//
//  SessionSyncService.swift
//  FocusFlow
//
//  Created by mustaahh on 12/4/26.
//
import Foundation
import os
import FirebaseFirestore

@MainActor
final class SessionSyncService {
    static let shared = SessionSyncService()

    enum SessionSyncOutcome {
        case synced
        case queued(reason: String)
        case failed(reason: String)
    }

    private struct PendingSessionRecord: Codable {
        let id: String
        let uid: String
        let session: PomodoroSession
        let createdAt: Date
        var attemptCount: Int
    }

    private let logger = Logger(subsystem: "FocusFlow", category: "SessionSync")
    private let queueStorageKey = "focusflow_pending_sessions_v1"
    private let maxRetryAttempts = 3
    private let maxQueueSize = 500

    private init() {}

    func saveSessionOrQueue(_ session: PomodoroSession, uid: String) async -> SessionSyncOutcome {
        let record = makeRecord(session: session, uid: uid)

        do {
            try await saveWithRetry(record: record)
            removePending(recordId: record.id)
            logger.info("Session synced successfully: \(record.id, privacy: .public)")
            return .synced
        } catch {
            let queued = enqueue(record)
            let reason = error.localizedDescription
            if queued {
                logger.error("Session queued after sync failure: \(record.id, privacy: .public), reason: \(reason, privacy: .public)")
                return .queued(reason: reason)
            }
            logger.error("Session sync and queue both failed: \(record.id, privacy: .public), reason: \(reason, privacy: .public)")
            return .failed(reason: reason)
        }
    }

    func flushPendingSessions(for uid: String) async {
        let queue = loadQueue()
        if queue.isEmpty { return }

        var kept: [PendingSessionRecord] = []
        var flushedCount = 0

        for var record in queue {
            if record.uid != uid {
                kept.append(record)
                continue
            }

            do {
                try await saveWithRetry(record: record)
                flushedCount += 1
            } catch {
                record.attemptCount += 1
                kept.append(record)
                logger.error("Failed to flush queued session: \(record.id, privacy: .public), attempt: \(record.attemptCount), reason: \(error.localizedDescription, privacy: .public)")
            }
        }

        _ = saveQueue(kept)

        if flushedCount > 0 {
            logger.info("Flushed queued sessions: \(flushedCount)")
        }
    }

    func pendingCount(for uid: String? = nil) -> Int {
        let queue = loadQueue()
        guard let uid else { return queue.count }
        return queue.filter { $0.uid == uid }.count
    }

    private func saveWithRetry(record: PendingSessionRecord) async throws {
        var lastError: Error?

        for attempt in 1...maxRetryAttempts {
            do {
                _ = try await FirebaseService.shared.saveSession(record.session, uid: record.uid, documentId: record.id)
                return
            } catch {
                lastError = error

                if attempt < maxRetryAttempts && isRetryable(error) {
                    let delay = retryDelayNanoseconds(for: attempt)
                    logger.warning("Retrying session save: \(record.id, privacy: .public), attempt: \(attempt), reason: \(error.localizedDescription, privacy: .public)")
                    try? await Task.sleep(nanoseconds: delay)
                    continue
                }
                break
            }
        }

        throw lastError ?? NSError(domain: "SessionSyncService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown session sync failure"])
    }

    private func isRetryable(_ error: Error) -> Bool {
        let nsError = error as NSError

        // Firestore transient errors worth retrying.
        if nsError.domain == FirestoreErrorDomain,
           let code = FirestoreErrorCode.Code(rawValue: nsError.code) {
            switch code {
            case .aborted, .cancelled, .deadlineExceeded, .internal, .resourceExhausted, .unavailable:
                return true
            default:
                return false
            }
        }

        // Common transient URL transport failures.
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorTimedOut,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorCannotFindHost,
                 NSURLErrorDNSLookupFailed:
                return true
            default:
                return false
            }
        }

        return false
    }

    private func retryDelayNanoseconds(for attempt: Int) -> UInt64 {
        let seconds = min(pow(2.0, Double(attempt - 1)), 8.0)
        return UInt64(seconds * 1_000_000_000)
    }

    private func makeRecord(session: PomodoroSession, uid: String) -> PendingSessionRecord {
        let id = makeSessionDocumentId(session: session, uid: uid)
        return PendingSessionRecord(
            id: id,
            uid: uid,
            session: session,
            createdAt: Date(),
            attemptCount: 0
        )
    }

    private func makeSessionDocumentId(session: PomodoroSession, uid: String) -> String {
        let ms = Int(session.startTime.timeIntervalSince1970 * 1000)
        let taskKey = session.taskId ?? "none"
        let raw = "s_\(uid)_\(ms)_\(session.type.rawValue)_\(taskKey)"
        return raw.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "_", options: .regularExpression)
    }

    private func enqueue(_ record: PendingSessionRecord) -> Bool {
        var queue = loadQueue()

        // De-duplicate based on deterministic record id.
        queue.removeAll { $0.id == record.id }
        queue.append(record)

        if queue.count > maxQueueSize {
            queue = Array(queue.suffix(maxQueueSize))
        }

        return saveQueue(queue)
    }

    private func removePending(recordId: String) {
        var queue = loadQueue()
        let originalCount = queue.count
        queue.removeAll { $0.id == recordId }
        if queue.count != originalCount {
            _ = saveQueue(queue)
        }
    }

    private func loadQueue() -> [PendingSessionRecord] {
        guard let data = UserDefaults.standard.data(forKey: queueStorageKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([PendingSessionRecord].self, from: data)
        } catch {
            logger.error("Unable to decode pending session queue: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private func saveQueue(_ queue: [PendingSessionRecord]) -> Bool {
        do {
            let data = try JSONEncoder().encode(queue)
            UserDefaults.standard.set(data, forKey: queueStorageKey)
            return true
        } catch {
            logger.error("Unable to persist pending session queue: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}

