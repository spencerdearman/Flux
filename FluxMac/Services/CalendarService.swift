//
//  FluxMacCalendarService.swift
//  FluxMac
//
//  Created by OpenAI.
//

import Combine
import EventKit
import Foundation
import SwiftData

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let isAllDay: Bool
}

@MainActor
final class CalendarStore: ObservableObject {
    @Published private(set) var todayEvents: [CalendarEvent] = []
    @Published private(set) var upcomingEvents: [CalendarEvent] = []
    @Published private(set) var calendarAccessGranted = false
    @Published private(set) var remindersAccessGranted = false

    private let eventStore = EKEventStore()

    func refresh() {
        requestAccessIfNeeded()
        guard calendarAccessGranted else { return }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let weekAhead = calendar.date(byAdding: .day, value: 7, to: start) ?? .now
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: start) ?? .now

        let todayPredicate = eventStore.predicateForEvents(withStart: start, end: tomorrow, calendars: nil)
        let weekPredicate = eventStore.predicateForEvents(withStart: tomorrow, end: weekAhead, calendars: nil)

        todayEvents = eventStore.events(matching: todayPredicate)
            .sorted { $0.startDate < $1.startDate }
            .map(CalendarEvent.init)
        upcomingEvents = eventStore.events(matching: weekPredicate)
            .sorted { $0.startDate < $1.startDate }
            .map(CalendarEvent.init)
    }

    func importReminders(into context: ModelContext, areas: [Area]) {
        requestAccessIfNeeded()
        guard remindersAccessGranted else { return }

        let predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        eventStore.fetchReminders(matching: predicate) { reminders in
            guard let reminders else { return }

            Task { @MainActor in
                let existingTitles = Set(
                    (try? context.fetch(FetchDescriptor<TaskItem>()))?.map { $0.title.lowercased() } ?? []
                )

                for reminder in reminders where !existingTitles.contains(reminder.title.lowercased()) {
                    let notes = reminder.notes ?? ""
                    let decision = SemanticRouter.analyze(title: reminder.title, notes: notes, areas: areas)
                    let task = TaskItem(
                        title: reminder.title,
                        notes: notes,
                        whenDate: reminder.dueDateComponents?.date,
                        deadline: reminder.dueDateComponents?.date,
                        status: decision.suggestedStatus,
                        isInInbox: decision.matchedArea == nil,
                        isEvening: decision.shouldMarkEvening,
                        area: decision.matchedArea
                    )
                    context.insert(task)
                }

                try? context.save()
            }
        }
    }

    private func requestAccessIfNeeded() {
        eventStore.requestAccess(to: .event) { [weak self] granted, _ in
            guard let self else { return }
            Task { @MainActor [granted] in
                self.calendarAccessGranted = granted
                if granted {
                    self.refresh()
                }
            }
        }

        eventStore.requestAccess(to: .reminder) { [weak self] granted, _ in
            guard let self else { return }
            Task { @MainActor [granted] in
                self.remindersAccessGranted = granted
            }
        }
    }
}

private extension CalendarEvent {
    init(event: EKEvent) {
        self.id = event.eventIdentifier
        self.title = event.title
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.location = event.location
        self.isAllDay = event.isAllDay
    }
}
