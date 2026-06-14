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
                WidgetRoutineItem(
                    id: item.id,
                    title: item.title,
                    startTimeText: timeText(for: item.startTime, fallback: now),
                    endTimeText: timeText(for: item.endTime, fallback: now),
                    outcome: outcome(for: item, on: today, routineStates: routineStates, calendar: calendar)
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

    private static func timeText(for date: Date?, fallback: Date) -> String {
        (date ?? fallback).formatted(.dateTime.hour().minute())
    }

    private static func outcome(
        for item: ScheduleItem,
        on date: Date,
        routineStates: [RoutineOccurrenceState],
        calendar: Calendar
    ) -> WidgetRoutineOutcome {
        switch routineStates.state(for: item, on: date, calendar: calendar)?.status {
        case .done:
            .success
        case .skipped:
            .fail
        case .pending, nil:
            .pending
        }
    }
}
