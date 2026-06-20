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

        return "\(pending) open · \(done) done · \(skipped) adjusted"
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
    let plannedDurationMinutes: Int
    let selectedVersion: RoutineVersion?
    let versionOptions: [RoutineVersion]
    let calendar: Calendar
    let dayStart: Date

    var id: UUID {
        item.id
    }

    var timeText: String {
        let suffix = endMinute >= ScheduleItem.minutesPerDay ? " +1d" : ""
        return "\(formattedTime(for: startMinute)) - \(formattedTime(for: endMinute))\(suffix)"
    }

    var delayText: String? {
        delayMinutes > 0 ? "+\(delayMinutes)m" : nil
    }

    var versionTitle: String {
        selectedVersion?.title
            ?? versionOptions.first(where: \.isDefault)?.title
            ?? "Standard"
    }

    var effectiveVersionID: String? {
        selectedVersion?.id ?? versionOptions.first(where: \.isDefault)?.id
    }

    var versionSummaryText: String {
        "\(versionTitle) · \(plannedDurationMinutes.readableDuration)"
    }

    var canSwitchVersion: Bool {
        versionOptions.count > 1
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
    let onSelectVersion: (ScheduleItem, RoutineVersion) -> Void

    @State private var versionMenuCandidate: RoutineNowCandidate?

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
        .dialogBackdrop(isPresented: versionMenuCandidate != nil)
        .confirmationDialog(
            "Version",
            isPresented: versionDialogBinding,
            titleVisibility: .visible
        ) {
            if let versionMenuCandidate {
                ForEach(versionMenuCandidate.versionOptions) { version in
                    Button {
                        onSelectVersion(versionMenuCandidate.item, version)
                        self.versionMenuCandidate = nil
                    } label: {
                        Label(
                            "\(version.title) · \(version.durationMinutes.readableDuration)",
                            systemImage: versionMenuCandidate.effectiveVersionID == version.id ? "checkmark" : "clock"
                        )
                    }
                }
            }

            Button("Cancel", role: .cancel) {
                versionMenuCandidate = nil
            }
        } message: {
            Text(versionMenuCandidate?.item.title ?? "")
        }
    }

    private var versionDialogBinding: Binding<Bool> {
        Binding {
            versionMenuCandidate != nil
        } set: { isPresented in
            if !isPresented {
                versionMenuCandidate = nil
            }
        }
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
                            .background(MissionTheme.controlFill, in: Capsule(style: .continuous))
                            .overlay {
                                Capsule(style: .continuous)
                                    .stroke(MissionTheme.separator.opacity(0.68), lineWidth: 1)
                            }
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 7) {
                        timeText(candidate.timeText)
                        versionBadge(candidate.versionSummaryText)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        timeText(candidate.timeText)
                        versionBadge(candidate.versionSummaryText)
                    }
                }

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
        if candidate.phase == .next {
            HStack(spacing: 8) {
                if candidate.canSwitchVersion {
                    RoutineOutcomeButton(
                        title: "Version",
                        systemImage: "slider.horizontal.3",
                        tint: MissionTheme.accent
                    ) {
                        versionMenuCandidate = candidate
                    }
                    .accessibilityLabel("Switch routine version")
                }

                lockedActionsLabel
            }
            .font(.caption.weight(.semibold))
            .buttonBorderShape(.capsule)
        } else {
            HStack(spacing: 8) {
                RoutineOutcomeButton(
                    title: "Adjust",
                    systemImage: "arrow.triangle.2.circlepath",
                    tint: MissionTheme.danger
                ) {
                    onSkip(candidate.item)
                }
                .accessibilityLabel("Adjust routine")

                if candidate.canSwitchVersion {
                    RoutineOutcomeButton(
                        title: "Version",
                        systemImage: "slider.horizontal.3",
                        tint: MissionTheme.accent
                    ) {
                        versionMenuCandidate = candidate
                    }
                    .accessibilityLabel("Switch routine version")
                }

                RoutineOutcomeButton(
                    title: "Done",
                    systemImage: "checkmark",
                    tint: MissionTheme.success
                ) {
                    onDone(candidate.item)
                }
                .accessibilityLabel("Mark routine as done")
            }
            .font(.caption.weight(.semibold))
            .buttonBorderShape(.capsule)
        }
    }

    private func timeText(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium).monospacedDigit())
            .foregroundStyle(MissionTheme.secondaryText)
            .lineLimit(1)
    }

    private func versionBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(MissionTheme.graphite)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(MissionTheme.controlFill, in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .stroke(MissionTheme.separator.opacity(0.68), lineWidth: 1)
            }
    }

    private var lockedActionsLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.caption.weight(.semibold))

            Text("Available at start")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .foregroundStyle(MissionTheme.secondaryText)
        .frame(maxWidth: .infinity)
        .frame(height: 38)
        .background(MissionTheme.controlFill, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(MissionTheme.separator.opacity(0.68), lineWidth: 1)
        }
        .accessibilityLabel("Routine actions available at start time")
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

private struct RoutineOutcomeButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ViewThatFits(in: .horizontal) {
                Label(title, systemImage: systemImage)
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)

                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
            }
            .minimumScaleFactor(0.76)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
        }
        .missionLiquidButton(.prominent)
        .tint(tint)
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
        .background(MissionTheme.controlFill, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(MissionTheme.separator.opacity(0.68), lineWidth: 1)
        }
    }
}
