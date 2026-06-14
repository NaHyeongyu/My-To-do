import SwiftUI
import WidgetKit

struct TodayOverviewEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct TodayOverviewProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayOverviewEntry {
        TodayOverviewEntry(
            date: .now,
            snapshot: WidgetSnapshot(
                generatedAt: .now,
                routines: [
                    WidgetRoutineItem(id: UUID(), title: "Morning review", startTimeText: "8:00 AM", endTimeText: "8:30 AM")
                ],
                tasks: [
                    WidgetTaskItem(id: UUID(), title: "Plan today")
                ]
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayOverviewEntry) -> Void) {
        completion(TodayOverviewEntry(date: .now, snapshot: WidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayOverviewEntry>) -> Void) {
        let entry = TodayOverviewEntry(date: .now, snapshot: WidgetSnapshotStore.load())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct TodayOverviewWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: TodayOverviewEntry

    private var routines: [WidgetRoutineItem] {
        entry.snapshot.routines
    }

    private var tasks: [WidgetTaskItem] {
        entry.snapshot.tasks
    }

    var body: some View {
        switch family {
        case .systemSmall:
            smallHomeView
        case .systemMedium:
            mediumHomeView
        case .accessoryInline:
            inlineLockView
        case .accessoryCircular:
            circularLockView
        case .accessoryRectangular:
            rectangularLockView
        default:
            mediumHomeView
        }
    }

    private var smallHomeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today")
                .font(.headline)
                .foregroundStyle(.primary)

            if let routine = routines.first {
                VStack(alignment: .leading, spacing: 2) {
                    Text(routine.startTimeText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(routine.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)
                }
            } else if let task = tasks.first {
                Label(task.title, systemImage: "checkmark.circle")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
            } else {
                Text("No plans")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                countPill("\(routines.count)", "calendar")
                countPill("\(tasks.count)", "checkmark.circle")
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumHomeView: some View {
        HStack(alignment: .top, spacing: 16) {
            widgetSection(title: "Calendar", systemImage: "calendar", rows: routineRows)
            Divider()
            widgetSection(title: "Tasks", systemImage: "checkmark.circle", rows: taskRows)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var inlineLockView: some View {
        Text("\(routines.count) events • \(tasks.count) tasks")
    }

    private var circularLockView: some View {
        VStack(spacing: 2) {
            Image(systemName: "checkmark.circle")
            Text("\(tasks.count)")
                .font(.caption2.weight(.bold))
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var rectangularLockView: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let routine = routines.first {
                Text("\(routine.startTimeText) \(routine.title)")
                    .font(.headline)
                    .lineLimit(1)
            } else {
                Text("No calendar events")
                    .font(.headline)
                    .lineLimit(1)
            }

            Text("\(tasks.count) open tasks")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var routineRows: [String] {
        if routines.isEmpty {
            return ["No events"]
        }

        return routines.prefix(3).map { "\($0.startTimeText)  \($0.title)" }
    }

    private var taskRows: [String] {
        if tasks.isEmpty {
            return ["No tasks"]
        }

        return tasks.prefix(4).map(\.title)
    }

    private func widgetSection(title: String, systemImage: String, rows: [String]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            ForEach(rows, id: \.self) { row in
                Text(row)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func countPill(_ text: String, _ systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
    }
}

struct TodayOverviewWidget: Widget {
    let kind = "TodayOverviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayOverviewProvider()) { entry in
            TodayOverviewWidgetView(entry: entry)
        }
        .configurationDisplayName("Today")
        .description("Shows today's calendar and open tasks.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

@main
struct OneWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayOverviewWidget()
    }
}
