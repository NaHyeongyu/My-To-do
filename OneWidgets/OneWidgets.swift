import AppIntents
import SwiftUI
import WidgetKit

struct TodayOverviewEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

private enum OneWidgetLayout {
    static let contentPadding: CGFloat = 14
    static let compactSpacing: CGFloat = 8
    static let sectionSpacing: CGFloat = 12
    static let actionButtonHeight: CGFloat = 34
}

private struct MarkRoutineOutcomeIntent: AppIntent {
    static let title: LocalizedStringResource = "Mark Routine Outcome"
    static let openAppWhenRun = false

    @Parameter(title: "Routine ID")
    var routineID: String

    @Parameter(title: "Outcome")
    var outcome: String

    init() {
        routineID = ""
        outcome = WidgetRoutineOutcome.pending.rawValue
    }

    init(routineID: UUID, outcome: WidgetRoutineOutcome) {
        self.routineID = routineID.uuidString
        self.outcome = outcome.rawValue
    }

    func perform() async throws -> some IntentResult {
        guard
            let routineID = UUID(uuidString: routineID),
            let outcome = WidgetRoutineOutcome(rawValue: outcome),
            outcome.isResolved
        else {
            return .result()
        }

        WidgetSnapshotStore.updateRoutineOutcome(routineID: routineID, outcome: outcome)
        WidgetCenter.shared.reloadTimelines(ofKind: "RoutineCheckInWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "TodayOverviewWidget")
        return .result()
    }
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
        let now = Date()
        let snapshot = WidgetSnapshotStore.load()
        let entry = TodayOverviewEntry(date: now, snapshot: snapshot)
        let fallbackRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        let nextRoutineUnlock = snapshot.routines
            .filter { !$0.outcome.isResolved }
            .compactMap(\.startDate)
            .filter { $0 > now }
            .min()
        let nextRefresh = [nextRoutineUnlock, fallbackRefresh].compactMap(\.self).min() ?? fallbackRefresh
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

private extension View {
    @ViewBuilder
    func oneWidgetContentPadding(for family: WidgetFamily) -> some View {
        switch family {
        case .systemSmall, .systemMedium:
            padding(OneWidgetLayout.contentPadding)
        default:
            self
        }
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
        Group {
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
        .widgetURL(OneWidgetDeepLink.calendar)
    }

    private var smallHomeView: some View {
        VStack(alignment: .leading, spacing: OneWidgetLayout.compactSpacing) {
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
        .oneWidgetContentPadding(for: family)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumHomeView: some View {
        HStack(alignment: .top, spacing: OneWidgetLayout.sectionSpacing) {
            widgetSection(title: "Calendar", systemImage: "calendar", rows: routineRows)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            Divider()
                .padding(.vertical, 2)
            widgetSection(title: "Tasks", systemImage: "checkmark.circle", rows: taskRows)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .oneWidgetContentPadding(for: family)
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
        .contentMarginsDisabled()
    }
}

struct RoutineCheckInWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: TodayOverviewEntry

    private var routine: WidgetRoutineItem? {
        entry.snapshot.routines.first { !$0.outcome.isResolved } ?? entry.snapshot.routines.first
    }

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumView
            case .accessoryRectangular:
                accessoryView
            default:
                smallView
            }
        }
        .widgetURL(OneWidgetDeepLink.calendar)
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if let routine {
                routineSummary(routine)
            } else {
                emptyState
            }

            Spacer(minLength: 0)

            actionLinks
        }
        .oneWidgetContentPadding(for: family)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumView: some View {
        HStack(alignment: .center, spacing: OneWidgetLayout.sectionSpacing) {
            VStack(alignment: .leading, spacing: 10) {
                header

                if let routine {
                    routineSummary(routine)
                } else {
                    emptyState
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                actionLinks
            }
            .frame(width: 126)
        }
        .oneWidgetContentPadding(for: family)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var accessoryView: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let routine {
                Text(routine.title)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(routine.startTimeText) · \(routine.outcome.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("No routine")
                    .font(.headline)
                    .lineLimit(1)
                Text("Open One")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var header: some View {
        Label("Check-in", systemImage: "1.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private func routineSummary(_ routine: WidgetRoutineItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(routine.title)
                .font(.headline.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            HStack(spacing: 6) {
                Text("\(routine.startTimeText) - \(routine.endTimeText)")
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if routine.outcome.isResolved {
                    ViewThatFits(in: .horizontal) {
                        Label(routine.outcome.title, systemImage: routine.outcome.symbolName)
                            .labelStyle(.titleAndIcon)

                        Image(systemName: routine.outcome.symbolName)
                    }
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(routine.outcome == .success ? .green : .red)
                    .lineLimit(1)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No open routine")
                .font(.headline.weight(.semibold))
                .lineLimit(1)

            Text("Open Calendar")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var actionLinks: some View {
        let isAvailable = routine?.isOutcomeAvailable(at: entry.date) == true

        HStack(spacing: 8) {
            if isAvailable, let routine {
                Button(intent: MarkRoutineOutcomeIntent(routineID: routine.id, outcome: .fail)) {
                    actionIcon("xmark", color: .red)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fail")
            } else {
                actionIcon("xmark", color: .red, isLocked: true)
                    .accessibilityLabel("Fail locked until routine start")
            }

            if isAvailable, let routine {
                Button(intent: MarkRoutineOutcomeIntent(routineID: routine.id, outcome: .success)) {
                    actionIcon("checkmark", color: .green)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Success")
            } else {
                actionIcon("checkmark", color: .green, isLocked: true)
                    .accessibilityLabel("Success locked until routine start")
            }
        }
    }

    private func actionIcon(_ systemName: String, color: Color, isLocked: Bool = false) -> some View {
        Image(systemName: systemName)
            .font(.caption.weight(.bold))
            .frame(maxWidth: .infinity)
            .frame(height: OneWidgetLayout.actionButtonHeight)
            .foregroundStyle(.white)
            .background(color.opacity(isLocked ? 0.32 : 1), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(color.opacity(isLocked ? 0.4 : 0), lineWidth: 1)
            }
            .opacity(isLocked ? 0.62 : 1)
    }
}

struct RoutineCheckInWidget: Widget {
    let kind = "RoutineCheckInWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayOverviewProvider()) { entry in
            RoutineCheckInWidgetView(entry: entry)
        }
        .configurationDisplayName("Routine Check-in")
        .description("Quickly mark the current routine as fail or success.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular
        ])
        .contentMarginsDisabled()
    }
}

@main
struct OneWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayOverviewWidget()
        RoutineCheckInWidget()
    }
}
