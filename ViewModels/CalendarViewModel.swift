//
//  CalendarViewModel.swift
//  FocusFlow
//
//  Created by mustaahh on 14/4/26.
//


import Foundation
import EventKit
import Combine

@MainActor
final class CalendarViewModel: ObservableObject {

    // MARK: - Published

    @Published var selectedDate: Date = Date()
    @Published var eventsForDate: [EKEvent] = []
    @Published var isAuthorized: Bool = false
    @Published var isRequestingAccess: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: - Private

    private let service = CalendarService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        isAuthorized = service.isAuthorized
        // Refresh events when selected date changes
        $selectedDate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] date in self?.loadEvents(for: date) }
            .store(in: &cancellables)
    }

    // MARK: - Access

    func requestAccessIfNeeded() {
        guard !service.isAuthorized else {
            isAuthorized = true
            loadEvents(for: selectedDate)
            return
        }
        isRequestingAccess = true
        Task {
            errorMessage = nil
            let granted = await service.requestAccess()
            service.refreshAuthStatus()
            isAuthorized = service.isAuthorized
            isRequestingAccess = false
            if granted && service.isAuthorized {
                loadEvents(for: selectedDate)
            } else {
                errorMessage = "Calendar access was not granted. If you denied it before, enable Calendar access in Settings."
            }
        }
    }

    // MARK: - Load Events

    func loadEvents(for date: Date) {
        guard service.isAuthorized else { eventsForDate = []; return }
        eventsForDate = service.events(for: date)
    }

    func reloadToday() {
        service.refreshAuthStatus()
        isAuthorized = service.isAuthorized
        loadEvents(for: selectedDate)
    }

    // MARK: - Create Focus Event in Calendar

    func createFocusEvent(title: String, start: Date, durationMinutes: Int) -> String? {
        do {
            let id = try service.createFocusEvent(title: title, start: start, durationMinutes: durationMinutes)
            // Refresh events list
            loadEvents(for: start)
            return id
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Delete Event

    func deleteEvent(identifier: String) {
        service.deleteEvent(identifier: identifier)
        loadEvents(for: selectedDate)
    }

    // MARK: - Week dates (for mini calendar strip)

    var weekDates: [Date] {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: selectedDate)
        let startOfWeek = cal.date(byAdding: .day, value: -(weekday - 1), to: cal.startOfDay(for: selectedDate))!
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    func isSelected(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }

    func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    // MARK: - Hour slots for day view (7am – 10pm)

    var hourSlots: [Date] {
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        return (7...22).compactMap {
            Calendar.current.date(byAdding: .hour, value: $0, to: startOfDay)
        }
    }

    /// Events that overlap a given hour slot
    func events(inHour hour: Date) -> [EKEvent] {
        let cal = Calendar.current
        let end = cal.date(byAdding: .hour, value: 1, to: hour)!
        return eventsForDate.filter { e in
            guard let start = e.startDate, let endDate = e.endDate else { return false }
            return start < end && endDate > hour
        }
    }
}
