import Foundation
import WidgetKit

enum WidgetSnapshotWriter {
    static func save(
        items: [ScheduleItem],
        routineStates: [RoutineOccurrenceState],
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        let today = calendar.startOfDay(for: now)
        let existingSnapshot = WidgetSnapshotStore.load()
        let routines = routineOccurrences(
            items: items,
            routineStates: routineStates,
            today: today,
            calendar: calendar
        )
            .prefix(5)
            .map { occurrence in
                let item = occurrence.item
                let state = occurrence.state
                let startDate = occurrence.startDate(calendar: calendar)
                let endDate = occurrence.endDate(calendar: calendar)
                let persistedOutcome = outcome(for: state)
                let displayOutcome = resolvedSnapshotOutcome(
                    for: item,
                    occurrenceDate: occurrence.occurrenceDate,
                    startDate: startDate,
                    persistedOutcome: persistedOutcome,
                    in: existingSnapshot,
                    calendar: calendar
                )

                return WidgetRoutineItem(
                    id: item.id,
                    title: item.title,
                    startTimeText: timeText(for: startDate),
                    endTimeText: endTimeText(for: endDate, crossesNextDay: !calendar.isDate(startDate, inSameDayAs: endDate)),
                    occurrenceDate: occurrence.occurrenceDate,
                    startDate: startDate,
                    endDate: endDate,
                    outcome: displayOutcome
                )
            }

        let tasks = items
            .filter { $0.kind == .task && !$0.isCompleted }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt > rhs.createdAt
                }

                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .prefix(6)
            .map { item in
                WidgetTaskItem(id: item.id, title: item.title)
            }

        WidgetSnapshotStore.save(
            WidgetSnapshot(
                generatedAt: now,
                routines: Array(routines),
                tasks: Array(tasks)
            )
        )
        WidgetCenter.shared.reloadTimelines(ofKind: "TodayOverviewWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "RoutineCheckInWidget")
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func timeText(for date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }

    private static func endTimeText(for endDate: Date, crossesNextDay: Bool) -> String {
        let suffix = crossesNextDay ? " +1d" : ""
        return "\(timeText(for: endDate))\(suffix)"
    }

    private static func outcome(for state: RoutineOccurrenceState?) -> WidgetRoutineOutcome {
        switch state?.status {
        case .done:
            .success
        case .skipped:
            .fail
        case .pending, nil:
            .pending
        }
    }

    private static func resolvedSnapshotOutcome(
        for item: ScheduleItem,
        occurrenceDate: Date,
        startDate: Date,
        persistedOutcome: WidgetRoutineOutcome,
        in snapshot: WidgetSnapshot,
        calendar: Calendar
    ) -> WidgetRoutineOutcome {
        guard persistedOutcome == .pending else {
            return persistedOutcome
        }

        guard
            let existingRoutine = snapshot.routines.first(where: {
                $0.id == item.id && $0.matchesOccurrence(occurrenceDate, calendar: calendar)
            }),
            existingRoutine.outcome.isResolved
        else {
            return persistedOutcome
        }

        if let existingStartDate = existingRoutine.startDate,
           !calendar.isDate(existingStartDate, inSameDayAs: startDate) {
            return persistedOutcome
        }

        return existingRoutine.outcome
    }

    private static func routineOccurrences(
        items: [ScheduleItem],
        routineStates: [RoutineOccurrenceState],
        today: Date,
        calendar: Calendar
    ) -> [RoutineOccurrenceProjection] {
        let currentOccurrences = items
            .routineOccurrenceProjections(on: today, routineStates: routineStates, calendar: calendar)
            .filter(\.startsBeforeNextDay)
        let previousOccurrences = calendar.date(byAdding: .day, value: -1, to: today)
            .map(calendar.startOfDay(for:))
            .map { previousDay in
                items
                    .routineOccurrenceProjections(on: previousDay, routineStates: routineStates, calendar: calendar)
                    .filter { $0.endMinute > ScheduleItem.minutesPerDay && $0.startMinute < ScheduleItem.minutesPerDay * 2 }
            } ?? []

        return (previousOccurrences + currentOccurrences)
            .sorted { lhs, rhs in
                let lhsDate = lhs.startDate(calendar: calendar)
                let rhsDate = rhs.startDate(calendar: calendar)
                if lhsDate != rhsDate {
                    return lhsDate < rhsDate
                }

                return lhs.item.title.localizedCaseInsensitiveCompare(rhs.item.title) == .orderedAscending
            }
    }
}
