//
//  CalenderService.swift
//  FocusFlow
//
//  Created by mustaahh on 14/4/26.
//
import Foundation
import Combine
import EventKit

@MainActor
final class CalendarService: ObservableObject {

    static let shared = CalendarService()

    private let store = EKEventStore()

    @Published var isAuthorized: Bool = false
    @Published var availableCalendars: [EKCalendar] = []

    private init() {
        refreshAuthStatus()
    }

    // MARK: - Auth

    func refreshAuthStatus() {
        if #available(iOS 17.0, *) {
            isAuthorized = EKEventStore.authorizationStatus(for: .event) == .fullAccess
        } else {
            isAuthorized = EKEventStore.authorizationStatus(for: .event) == .authorized
        }
    }

    func requestAccess() async -> Bool {
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await store.requestFullAccessToEvents()
            } else {
                granted = try await store.requestAccess(to: .event)
            }
            isAuthorized = granted
            if granted { availableCalendars = store.calendars(for: .event) }
            return granted
        } catch {
            isAuthorized = false
            return false
        }
    }

    // MARK: - Fetch Events

    /// Returns all EKEvents for a given date, sorted by start time.
    func events(for date: Date) -> [EKEvent] {
        guard isAuthorized else { return [] }
        let start = Calendar.current.startOfDay(for: date)
        let end   = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let pred  = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: pred).sorted { $0.startDate < $1.startDate }
    }

    /// Returns today's events.
    func todayEvents() -> [EKEvent] { events(for: Date()) }

    // MARK: - Create Focus Session Event

    @discardableResult
    func createFocusEvent(title: String, start: Date, durationMinutes: Int) throws -> String {
        guard isAuthorized else { throw CalError.notAuthorized }
        let event = EKEvent(eventStore: store)
        event.title     = "🍅 \(title)"
        event.startDate = start
        event.endDate   = Calendar.current.date(byAdding: .minute, value: durationMinutes, to: start)!
        event.notes     = "FocusFlow Pomodoro Session"
        event.calendar  = store.defaultCalendarForNewEvents
        try store.save(event, span: .thisEvent, commit: true)
        return event.eventIdentifier
    }

    // MARK: - Delete Event

    func deleteEvent(identifier: String) {
        guard isAuthorized, let event = store.event(withIdentifier: identifier) else { return }
        try? store.remove(event, span: .thisEvent, commit: true)
    }

    // MARK: - Error

    enum CalError: LocalizedError {
        case notAuthorized
        var errorDescription: String? { "Calendar access not granted. Please enable in Settings." }
    }
}

// MARK: - EKEvent convenience

extension EKEvent {
    var durationMinutes: Int {
        guard let start = startDate, let end = endDate else { return 0 }
        return max(0, Int(end.timeIntervalSince(start) / 60))
    }

    var timeRangeLabel: String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        return "\(fmt.string(from: startDate)) – \(fmt.string(from: endDate))"
    }

    var calendarColorHex: String {
        guard let cgColor = calendar.cgColor else { return "#4A90E2" }
        let comps = cgColor.components ?? [0.29, 0.56, 0.89, 1]
        let r = Int((comps[safe: 0] ?? 0.29) * 255)
        let g = Int((comps[safe: 1] ?? 0.56) * 255)
        let b = Int((comps[safe: 2] ?? 0.89) * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
