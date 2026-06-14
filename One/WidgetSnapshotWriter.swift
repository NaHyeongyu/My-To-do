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
        let routines = items.routines(on: today, calendar: calendar)
            .prefix(5)
            .map { item in
                let state = routineStates.state(for: item, on: today, calendar: calendar)
                let delayMinutes = state?.delayMinutes ?? 0
                let startMinute = calendar.minuteOfDay(for: item.startTime ?? now) + delayMinutes
                let duration = max(5, item.durationMinutes(calendar: calendar))
                let endMinute = startMinute + duration
                let startDate = calendar.date(byAdding: .minute, value: startMinute, to: today) ?? now
                let endDate = calendar.date(byAdding: .minute, value: endMinute, to: today) ?? now

                return WidgetRoutineItem(
                    id: item.id,
                    title: item.title,
                    startTimeText: timeText(for: startDate),
                    endTimeText: timeText(for: endDate),
                    startDate: startDate,
                    endDate: endDate,
                    outcome: outcome(for: state)
                )
            }

        let tasks = items.openTasks()
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
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func timeText(for date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
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
}
