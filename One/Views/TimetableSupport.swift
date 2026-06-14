import SwiftUI

private struct CalendarPageTurnEffect<Value: Equatable>: ViewModifier {
    let value: Value
    let direction: Int

    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .opacity(opacity)
            .onChange(of: value) { _, _ in
                offset = direction >= 0 ? 28 : -28
                opacity = 0.86

                DispatchQueue.main.async {
                    withAnimation(.snappy(duration: 0.24)) {
                        offset = 0
                        opacity = 1
                    }
                }
            }
    }
}

extension View {
    func calendarPageTurn<Value: Equatable>(for value: Value, direction: Int) -> some View {
        modifier(CalendarPageTurnEffect(value: value, direction: direction))
    }
}

enum CalendarSwipeScope {
    case day
    case week
    case month

    var component: Calendar.Component {
        switch self {
        case .day, .week:
            .day
        case .month:
            .month
        }
    }

    var step: Int {
        switch self {
        case .day, .month:
            1
        case .week:
            7
        }
    }

    var minimumDistance: CGFloat {
        switch self {
        case .day:
            46
        case .week, .month:
            12
        }
    }
}

enum TimetableViewMode: String, CaseIterable, Identifiable {
    case day
    case month

    static let defaultsKey = "timetableViewMode"

    var id: String { rawValue }

    static func storedValue() -> TimetableViewMode {
        guard
            let rawValue = UserDefaults.standard.string(forKey: defaultsKey),
            let mode = TimetableViewMode(rawValue: rawValue)
        else {
            return .day
        }

        return mode
    }

    var title: String {
        switch self {
        case .day: "Day"
        case .month: "Month"
        }
    }

    var systemImage: String {
        switch self {
        case .day: "calendar.day.timeline.left"
        case .month: "calendar"
        }
    }
}

enum RoutineNowPhase {
    case active
    case next
    case missed

    var title: String {
        switch self {
        case .active: "Now"
        case .next: "Next"
        case .missed: "Missed"
        }
    }

    var systemImage: String {
        switch self {
        case .active: "bolt.fill"
        case .next: "arrow.right"
        case .missed: "exclamationmark"
        }
    }
}

struct RoutineDayProgress {
    let total: Int
    let done: Int
    let skipped: Int

    var completed: Int {
        done + skipped
    }

    var pending: Int {
        max(0, total - completed)
    }

    var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var summaryText: String {
        guard total > 0 else {
            return "No routines"
        }

        return "\(pending) open · \(done) success · \(skipped) fail"
    }
}

struct CalendarMissionSummary {
    let plannedMinutes: Int
    let completedMinutes: Int
    let openTaskCount: Int

    var plannedText: String {
        plannedMinutes.readableDuration
    }

    var completedText: String {
        completedMinutes.readableDuration
    }

    var openTaskText: String {
        "\(openTaskCount)"
    }
}

struct RoutineNowCandidate: Identifiable {
    let item: ScheduleItem
    var phase: RoutineNowPhase
    let status: RoutineOccurrenceStatus
    let startMinute: Int
    let endMinute: Int
    let delayMinutes: Int
    let calendar: Calendar
    let dayStart: Date

    var id: UUID {
        item.id
    }

    var timeText: String {
        "\(formattedTime(for: startMinute)) - \(formattedTime(for: endMinute))"
    }

    var delayText: String? {
        delayMinutes > 0 ? "+\(delayMinutes)m" : nil
    }

    func withPhase(_ nextPhase: RoutineNowPhase) -> RoutineNowCandidate {
        var copy = self
        copy.phase = nextPhase
        return copy
    }

    private func formattedTime(for minute: Int) -> String {
        let date = calendar.date(byAdding: .minute, value: minute, to: dayStart) ?? dayStart
        return date.formatted(.dateTime.hour().minute())
    }
}

struct CalendarNowModeCard: View {
    let candidate: RoutineNowCandidate?
    let progress: RoutineDayProgress
    let summary: CalendarMissionSummary
    let onAddRoutine: () -> Void
    let onDone: (ScheduleItem) -> Void
    let onSkip: (ScheduleItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            missionMetrics

            if let candidate {
                candidateContent(candidate)
            } else {
                emptyContent
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .missionCard()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(candidate?.phase.title ?? "Today", systemImage: candidate?.phase.systemImage ?? "checklist")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MissionTheme.selectedText)
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(MissionTheme.accent, in: Capsule(style: .continuous))

                Text(progress.summaryText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(MissionTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Spacer(minLength: 0)
            }

            ProgressView(value: progress.fraction)
                .tint(MissionTheme.accent)
        }
    }

    private var missionMetrics: some View {
        HStack(spacing: 8) {
            MissionMetricPill(title: "Planned", value: summary.plannedText)
            MissionMetricPill(title: "Done", value: summary.completedText)
            MissionMetricPill(title: "Tasks", value: summary.openTaskText)
        }
    }

    private func candidateContent(_ candidate: RoutineNowCandidate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(candidate.item.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(MissionTheme.graphite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    if let delayText = candidate.delayText {
                        Text(delayText)
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(MissionTheme.secondaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(MissionTheme.separator.opacity(0.44), in: Capsule(style: .continuous))
                    }
                }

                Text(candidate.timeText)
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(MissionTheme.secondaryText)
                    .lineLimit(1)

                if !candidate.item.notes.isEmpty {
                    Text(candidate.item.notes)
                        .font(.caption)
                        .foregroundStyle(MissionTheme.tertiaryText)
                        .lineLimit(1)
                }
            }

            actionRow(candidate)
        }
    }

    @ViewBuilder
    private func actionRow(_ candidate: RoutineNowCandidate) -> some View {
        HStack(spacing: 8) {
            Button {
                onSkip(candidate.item)
            } label: {
                Label("Fail", systemImage: "xmark")
                    .frame(maxWidth: .infinity)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .missionLiquidButton(.prominent)
            .tint(MissionTheme.danger)
            .accessibilityLabel("Mark routine as fail")

            Button {
                onDone(candidate.item)
            } label: {
                Label("Success", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .missionLiquidButton(.prominent)
            .tint(MissionTheme.success)
            .accessibilityLabel("Mark routine as success")
        }
        .font(.caption.weight(.semibold))
        .buttonBorderShape(.capsule)
    }

    private var emptyContent: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(progress.total == 0 ? "No routines today" : "Clear for today")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(MissionTheme.graphite)

                Text(progress.total == 0 ? "Add the first block." : "No open routine remains.")
                    .font(.caption)
                    .foregroundStyle(MissionTheme.secondaryText)
            }

            Spacer(minLength: 0)

            Button {
                onAddRoutine()
            } label: {
                Image(systemName: "plus")
                    .frame(width: 36, height: 32)
            }
            .missionLiquidButton(.prominent)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Add routine")
        }
    }
}

private struct MissionMetricPill: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 5) {
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(MissionTheme.graphite)
                .lineLimit(1)
                .minimumScaleFactor(0.76)

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(MissionTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(MissionTheme.separator.opacity(0.12), in: Capsule(style: .continuous))
    }
}
