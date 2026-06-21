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
        let routines = items.routines(on: today, routineStates: routineStates, calendar: calendar)
            .prefix(5)
            .map { item in
                let state = routineStates.state(for: item, on: today, calendar: calendar)
                let delayMinutes = state?.delayMinutes ?? 0
                let startMinute = calendar.minuteOfDay(for: item.startTime ?? now) + delayMinutes
                let duration = max(5, item.plannedDurationMinutes(state: state, calendar: calendar))
                let endMinute = startMinute + duration
                let startDate = calendar.date(byAdding: .minute, value: startMinute, to: today) ?? now
                let endDate = calendar.date(byAdding: .minute, value: endMinute, to: today) ?? now
                let persistedOutcome = outcome(for: state)
                let displayOutcome = resolvedSnapshotOutcome(
                    for: item,
                    startDate: startDate,
                    persistedOutcome: persistedOutcome,
                    in: existingSnapshot,
                    calendar: calendar
                )

                return WidgetRoutineItem(
                    id: item.id,
                    title: item.title,
                    startTimeText: timeText(for: startDate),
                    endTimeText: endTimeText(for: endDate, crossesNextDay: endMinute >= ScheduleItem.minutesPerDay),
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
        startDate: Date,
        persistedOutcome: WidgetRoutineOutcome,
        in snapshot: WidgetSnapshot,
        calendar: Calendar
    ) -> WidgetRoutineOutcome {
        guard persistedOutcome == .pending else {
            return persistedOutcome
        }

        guard
            let existingRoutine = snapshot.routines.first(where: { $0.id == item.id }),
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
}
