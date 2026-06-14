import Foundation
import WidgetKit

enum WidgetSnapshotWriter {
    static func save(items: [ScheduleItem], now: Date = .now, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        let routines = items.routines(on: today, calendar: calendar)
            .prefix(5)
            .map { item in
                WidgetRoutineItem(
                    id: item.id,
                    title: item.title,
                    startTimeText: timeText(for: item.startTime, fallback: now),
                    endTimeText: timeText(for: item.endTime, fallback: now)
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
}
