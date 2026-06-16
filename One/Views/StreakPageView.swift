import SwiftUI

struct StreakPageView: View {
    let items: [ScheduleItem]
    let routineStates: [RoutineOccurrenceState]

    @State private var mode: StreakPeriodMode = .week
    @State private var referenceDate = Calendar.current.startOfDay(for: .now)

    @AppStorage(AppSettingsKey.customRoutineLabels) private var customRoutineLabelsRaw = CustomRoutineLabelStore.emptyStorage

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        return calendar
    }

    private var period: StreakPeriod {
        StreakPeriod(mode: mode, containing: referenceDate, calendar: calendar)
    }

    private var stats: StreakStats {
        StreakStats(
            items: items,
            routineStates: routineStates,
            routineLabelOptions: routineLabelOptions,
            period: period,
            now: .now,
            calendar: calendar
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                modePicker
                periodHeader
                metricGrid
                StreakDayRail(days: stats.days)
                timeCard
                if mode == .week {
                    routineLabelTimeCard
                }
                if !stats.failReasonSummaries.isEmpty {
                    failurePatternCard
                }
                historySection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 96)
        }
        .background(TaskListPalette.background)
        .sensoryFeedback(.selection, trigger: mode)
    }

    private var modePicker: some View {
        Picker("Range", selection: $mode) {
            ForEach(StreakPeriodMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var periodHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(period.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(TaskListPalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(mode == .week ? "Resets Sunday" : "Month view")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(TaskListPalette.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Button {
                    movePeriod(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Previous \(mode.title.lowercased())")

                Button {
                    movePeriod(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Next \(mode.title.lowercased())")
            }
            .tint(MissionTheme.accent)
        }
    }

    private var metricGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            StreakMetricCard(
                title: "Routine success",
                value: stats.successRateText,
                detail: "\(stats.doneRoutines) of \(stats.scheduledRoutines) done"
            )

            StreakMetricCard(
                title: "Best streak",
                value: "\(stats.bestStreak)",
                detail: stats.bestStreak == 1 ? "success day" : "success days"
            )

            StreakMetricCard(
                title: "Tasks done",
                value: "\(stats.completedTasks.count)",
                detail: "completed in range"
            )

            StreakMetricCard(
                title: "Open routines",
                value: "\(stats.openRoutines)",
                detail: "\(stats.skippedRoutines) skipped · \(stats.missedRoutines) missed"
            )
        }
    }

    private var timeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Routine time")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(TaskListPalette.primaryText)

                Spacer(minLength: 8)

                Text(stats.completedRoutineTimeText)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(TaskListPalette.secondaryText)
                    .lineLimit(1)
            }

            ProgressView(value: stats.completedTimeFraction)
                .tint(MissionTheme.accent)

            Text("\(stats.completedRoutineTimeText) completed of \(stats.plannedRoutineTimeText) planned")
                .font(.caption.weight(.medium))
                .foregroundStyle(TaskListPalette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(14)
        .background(TaskListPalette.rowBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(TaskListPalette.separator.opacity(0.28), lineWidth: 0.5)
        }
    }

    private var routineLabelTimeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Label command center")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(TaskListPalette.primaryText)

                Spacer(minLength: 8)

                Text(stats.weeklyRoutineLabelTotalText)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(TaskListPalette.secondaryText)
                    .lineLimit(1)
            }

            VStack(spacing: 12) {
                ForEach(stats.weeklyRoutineLabelSummaries) { summary in
                    StreakRoutineLabelTimeRow(summary: summary)
                }
            }
        }
        .padding(14)
        .background(TaskListPalette.rowBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(TaskListPalette.separator.opacity(0.28), lineWidth: 0.5)
        }
    }

    private var failurePatternCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Failure pattern")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(TaskListPalette.primaryText)

                Spacer(minLength: 8)

                Text(stats.failReasonTotalText)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(TaskListPalette.secondaryText)
                    .lineLimit(1)
            }

            VStack(spacing: 10) {
                ForEach(stats.failReasonSummaries) { summary in
                    StreakFailReasonRow(summary: summary)
                }
            }
        }
        .padding(14)
        .background(TaskListPalette.rowBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(TaskListPalette.separator.opacity(0.28), lineWidth: 0.5)
        }
    }


    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            historyGroup(
                title: "Completed tasks",
                emptyTitle: "No completed tasks",
                rows: stats.completedTasks.map { task in
                    StreakHistoryRowData(
                        id: "task-\(task.id.uuidString)",
                        title: task.title,
                        detail: (task.completedAt ?? task.createdAt).formatted(.dateTime.month(.abbreviated).day())
                    )
                }
            )

            historyGroup(
                title: "Completed routines",
                emptyTitle: "No completed routines",
                rows: stats.completedRoutineOccurrences.map { occurrence in
                    let dateText = occurrence.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    let detailText = [occurrence.label?.title, dateText]
                        .compactMap(\.self)
                        .joined(separator: " · ")

                    return StreakHistoryRowData(
                        id: occurrence.id,
                        title: occurrence.title,
                        detail: detailText
                    )
                }
            )
        }
    }

    private func historyGroup(
        title: String,
        emptyTitle: String,
        rows: [StreakHistoryRowData]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(TaskListPalette.primaryText)

            if rows.isEmpty {
                Text(emptyTitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TaskListPalette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(TaskListPalette.rowBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(rows.prefix(8)) { row in
                        StreakHistoryRow(row: row)

                        if row.id != rows.prefix(8).last?.id {
                            Divider()
                                .padding(.leading, 14)
                        }
                    }
                }
                .background(TaskListPalette.rowBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(TaskListPalette.separator.opacity(0.28), lineWidth: 0.5)
                }
            }
        }
    }

    private func movePeriod(by value: Int) {
        let component: Calendar.Component = mode == .week ? .weekOfYear : .month
        guard let nextDate = calendar.date(byAdding: component, value: value, to: referenceDate) else {
            return
        }

        withAnimation(.snappy(duration: 0.18)) {
            referenceDate = calendar.startOfDay(for: nextDate)
        }
    }

    private var customRoutineLabels: [CustomRoutineLabel] {
        CustomRoutineLabelStore.labels(from: customRoutineLabelsRaw)
    }

    private var routineLabelOptions: [RoutineLabelOption] {
        RoutineLabelOption.options(customLabels: customRoutineLabels)
    }
}

private enum StreakPeriodMode: String, CaseIterable, Identifiable {
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: "Week"
        case .month: "Month"
        }
    }
}

private struct StreakPeriod {
    let mode: StreakPeriodMode
    let start: Date
    let end: Date
    let calendar: Calendar

    init(mode: StreakPeriodMode, containing date: Date, calendar: Calendar) {
        self.mode = mode
        self.calendar = calendar

        switch mode {
        case .week:
            let dayStart = calendar.startOfDay(for: date)
            let weekday = calendar.component(.weekday, from: dayStart)
            let daysFromSunday = max(0, weekday - 1)
            let weekStart = calendar.date(byAdding: .day, value: -daysFromSunday, to: dayStart) ?? dayStart
            self.start = weekStart
            self.end = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        case .month:
            let components = calendar.dateComponents([.year, .month], from: date)
            let monthStart = calendar.date(from: components).map(calendar.startOfDay(for:)) ?? calendar.startOfDay(for: date)
            self.start = monthStart
            self.end = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        }
    }

    var title: String {
        switch mode {
        case .week:
            let endDate = calendar.date(byAdding: .day, value: -1, to: end) ?? end
            return "\(start.formatted(.dateTime.month(.abbreviated).day())) - \(endDate.formatted(.dateTime.month(.abbreviated).day()))"
        case .month:
            return start.formatted(.dateTime.month(.wide).year())
        }
    }

    func contains(_ date: Date) -> Bool {
        date >= start && date < end
    }
}

private struct StreakStats {
    let days: [StreakDaySummary]
    let completedTasks: [ScheduleItem]
    let completedRoutineOccurrences: [StreakRoutineOccurrence]
    let weeklyRoutineLabelSummaries: [RoutineLabelTimeSummary]
    let failReasonSummaries: [RoutineFailReasonSummary]

    private let scheduledOccurrences: [StreakRoutineOccurrence]

    init(
        items: [ScheduleItem],
        routineStates: [RoutineOccurrenceState],
        routineLabelOptions: [RoutineLabelOption],
        period: StreakPeriod,
        now: Date,
        calendar: Calendar
    ) {
        let todayStart = calendar.startOfDay(for: now)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? now
        let analysisEnd = min(period.end, tomorrowStart)
        let routineItems = items.filter { $0.kind == .routine }
        let includedDates = Self.dates(from: period.start, to: analysisEnd, calendar: calendar)
        let weeklyTargetDates = period.mode == .week
            ? Self.dates(from: period.start, to: period.end, calendar: calendar)
            : includedDates

        var allOccurrences: [StreakRoutineOccurrence] = []
        var dailySummaries: [StreakDaySummary] = []
        var weeklyLabelOccurrences: [StreakRoutineOccurrence] = []
        let customRoutineLabels = routineLabelOptions
            .filter(\.isCustom)
            .map { CustomRoutineLabel(id: $0.rawValue, title: $0.title, symbolName: $0.symbolName) }

        for date in includedDates {
            let routines = routineItems
                .filter { Self.isRoutine($0, scheduledOn: date, calendar: calendar) }
                .sorted {
                    calendar.minuteOfDay(for: $0.startTime ?? .distantFuture)
                        < calendar.minuteOfDay(for: $1.startTime ?? .distantFuture)
                }

            let occurrences = routines.map { routine in
                let state = routineStates.state(for: routine, on: date, calendar: calendar)
                let status = state?.status ?? .pending
                let effectiveStatus: StreakOccurrenceStatus

                switch status {
                case .done:
                    effectiveStatus = .done
                case .skipped:
                    effectiveStatus = .skipped
                case .pending:
                    effectiveStatus = date < todayStart ? .missed : .open
                }

                return StreakRoutineOccurrence(
                    id: "\(routine.id.uuidString)-\(date.timeIntervalSince1970)",
                    routineID: routine.id,
                    title: routine.title,
                    label: RoutineLabelOption.option(for: routine.routineLabelRawValue, customLabels: customRoutineLabels),
                    date: date,
                    status: effectiveStatus,
                    failReason: state?.failReason,
                    minutes: routine.durationMinutes(calendar: calendar)
                )
            }

            allOccurrences.append(contentsOf: occurrences)
            dailySummaries.append(StreakDaySummary(date: date, occurrences: occurrences, calendar: calendar))
        }

        for date in weeklyTargetDates {
            let routines = routineItems
                .filter { $0.taskDate == nil && Self.isRoutine($0, scheduledOn: date, calendar: calendar) }
                .sorted {
                    calendar.minuteOfDay(for: $0.startTime ?? .distantFuture)
                        < calendar.minuteOfDay(for: $1.startTime ?? .distantFuture)
                }

            let occurrences = routines.map { routine in
                let state = routineStates.state(for: routine, on: date, calendar: calendar)
                let status = state?.status ?? .pending
                let effectiveStatus: StreakOccurrenceStatus

                switch status {
                case .done:
                    effectiveStatus = .done
                case .skipped:
                    effectiveStatus = .skipped
                case .pending:
                    effectiveStatus = date < todayStart ? .missed : .open
                }

                return StreakRoutineOccurrence(
                    id: "label-\(routine.id.uuidString)-\(date.timeIntervalSince1970)",
                    routineID: routine.id,
                    title: routine.title,
                    label: RoutineLabelOption.option(for: routine.routineLabelRawValue, customLabels: customRoutineLabels),
                    date: date,
                    status: effectiveStatus,
                    failReason: state?.failReason,
                    minutes: routine.durationMinutes(calendar: calendar)
                )
            }

            weeklyLabelOccurrences.append(contentsOf: occurrences)
        }

        self.scheduledOccurrences = allOccurrences
        self.days = dailySummaries
        self.completedRoutineOccurrences = allOccurrences
            .filter { $0.status == .done }
            .sorted { $0.date > $1.date }
        self.completedTasks = items
            .filter { item in
                guard item.kind == .task, let completedAt = item.completedAt else { return false }
                return period.contains(completedAt)
            }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        self.failReasonSummaries = Self.failReasonSummaries(from: allOccurrences)
        self.weeklyRoutineLabelSummaries = routineLabelOptions.map { label in
            let labelOccurrences = weeklyLabelOccurrences.filter { $0.label?.rawValue == label.rawValue }
            let plannedMinutes = labelOccurrences.reduce(0) { $0 + $1.minutes }
            let completedMinutes = labelOccurrences
                .filter { $0.status == .done }
                .reduce(0) { $0 + $1.minutes }
            let failedMinutes = labelOccurrences
                .filter { $0.status == .skipped || $0.status == .missed }
                .reduce(0) { $0 + $1.minutes }

            return RoutineLabelTimeSummary(
                label: label,
                plannedMinutes: plannedMinutes,
                completedMinutes: completedMinutes,
                failedMinutes: failedMinutes,
                periodStart: period.start,
                periodEnd: period.end,
                now: now,
                calendar: calendar
            )
        }
    }

    var scheduledRoutines: Int {
        scheduledOccurrences.count
    }

    var doneRoutines: Int {
        scheduledOccurrences.filter { $0.status == .done }.count
    }

    var skippedRoutines: Int {
        scheduledOccurrences.filter { $0.status == .skipped }.count
    }

    var missedRoutines: Int {
        scheduledOccurrences.filter { $0.status == .missed }.count
    }

    var openRoutines: Int {
        scheduledOccurrences.filter { $0.status == .open }.count
    }

    var successRate: Double {
        guard scheduledRoutines > 0 else { return 0 }
        return Double(doneRoutines) / Double(scheduledRoutines)
    }

    var successRateText: String {
        "\(Int((successRate * 100).rounded()))%"
    }

    var bestStreak: Int {
        days.reduce((best: 0, current: 0)) { result, day in
            let current = day.isSuccessDay ? result.current + 1 : 0
            return (max(result.best, current), current)
        }.best
    }

    var plannedRoutineMinutes: Int {
        scheduledOccurrences.reduce(0) { $0 + $1.minutes }
    }

    var completedRoutineMinutes: Int {
        scheduledOccurrences
            .filter { $0.status == .done }
            .reduce(0) { $0 + $1.minutes }
    }

    var completedTimeFraction: Double {
        guard plannedRoutineMinutes > 0 else { return 0 }
        return Double(completedRoutineMinutes) / Double(plannedRoutineMinutes)
    }

    var plannedRoutineTimeText: String {
        plannedRoutineMinutes.readableDuration
    }

    var completedRoutineTimeText: String {
        completedRoutineMinutes.readableDuration
    }

    var weeklyRoutineLabelTotalText: String {
        let completedMinutes = weeklyRoutineLabelSummaries.reduce(0) { $0 + $1.completedMinutes }
        let plannedMinutes = weeklyRoutineLabelSummaries.reduce(0) { $0 + $1.plannedMinutes }
        return "\(completedMinutes.readableDuration) / \(plannedMinutes.readableDuration)"
    }

    var failReasonTotalText: String {
        let minutes = failReasonSummaries.reduce(0) { $0 + $1.minutes }
        return minutes.readableDuration
    }

    private static func dates(from start: Date, to end: Date, calendar: Calendar) -> [Date] {
        var dates: [Date] = []
        var current = calendar.startOfDay(for: start)

        while current < end {
            dates.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else {
                break
            }
            current = next
        }

        return dates
    }

    private static func isRoutine(_ routine: ScheduleItem, scheduledOn date: Date, calendar: Calendar) -> Bool {
        guard routine.isRoutineActive(on: date, calendar: calendar) else {
            return false
        }

        if let taskDate = routine.taskDate {
            return calendar.isDate(taskDate, inSameDayAs: date)
        }

        return routine.repeats(on: date, calendar: calendar)
    }

    private static func failReasonSummaries(from occurrences: [StreakRoutineOccurrence]) -> [RoutineFailReasonSummary] {
        let failedOccurrences = occurrences.filter { $0.status == .skipped }
        let groupedOccurrences = Dictionary(grouping: failedOccurrences, by: \.failReason)

        return groupedOccurrences
            .map { reason, occurrences in
                RoutineFailReasonSummary(
                    reason: reason,
                    count: occurrences.count,
                    minutes: occurrences.reduce(0) { $0 + $1.minutes }
                )
            }
            .sorted {
                if $0.minutes != $1.minutes {
                    return $0.minutes > $1.minutes
                }

                return $0.title < $1.title
            }
    }
}

private struct StreakDaySummary: Identifiable {
    let id: Date
    let date: Date
    let scheduled: Int
    let done: Int
    let skipped: Int
    let missed: Int
    let open: Int

    init(date: Date, occurrences: [StreakRoutineOccurrence], calendar: Calendar) {
        self.id = calendar.startOfDay(for: date)
        self.date = calendar.startOfDay(for: date)
        self.scheduled = occurrences.count
        self.done = occurrences.filter { $0.status == .done }.count
        self.skipped = occurrences.filter { $0.status == .skipped }.count
        self.missed = occurrences.filter { $0.status == .missed }.count
        self.open = occurrences.filter { $0.status == .open }.count
    }

    var isSuccessDay: Bool {
        scheduled > 0 && done == scheduled
    }

    var statusText: String {
        if scheduled == 0 { return "No routines" }
        if isSuccessDay { return "Done" }
        if open > 0 { return "\(open) open" }
        if missed > 0 { return "\(missed) missed" }
        if skipped > 0 { return "\(skipped) skipped" }
        return "\(done)/\(scheduled)"
    }
}

private struct StreakRoutineOccurrence: Identifiable {
    let id: String
    let routineID: UUID
    let title: String
    let label: RoutineLabelOption?
    let date: Date
    let status: StreakOccurrenceStatus
    let failReason: RoutineFailReason?
    let minutes: Int
}

private struct RoutineFailReasonSummary: Identifiable {
    let reason: RoutineFailReason?
    let count: Int
    let minutes: Int

    var id: String {
        reason?.rawValue ?? "none"
    }

    var title: String {
        reason?.title ?? "No reason"
    }

    var detailText: String {
        "\(count)x · \(minutes.readableDuration)"
    }
}

private struct RoutineLabelTimeSummary: Identifiable {
    let label: RoutineLabelOption
    let plannedMinutes: Int
    let completedMinutes: Int
    let failedMinutes: Int

    var id: String { label.rawValue }

    init(
        label: RoutineLabelOption,
        plannedMinutes: Int,
        completedMinutes: Int,
        failedMinutes: Int,
        periodStart: Date,
        periodEnd: Date,
        now: Date,
        calendar: Calendar
    ) {
        self.label = label
        self.plannedMinutes = plannedMinutes
        self.completedMinutes = completedMinutes
        self.failedMinutes = failedMinutes
    }

    var denominatorMinutes: Int {
        plannedMinutes
    }

    var remainingMinutes: Int {
        max(0, denominatorMinutes - completedMinutes)
    }

    var fraction: Double {
        guard denominatorMinutes > 0 else { return 0 }
        return min(1, Double(completedMinutes) / Double(denominatorMinutes))
    }

    var detailText: String {
        "Plan \(plannedMinutes.readableDuration) · Left \(remainingMinutes.readableDuration)"
    }

    var outcomeText: String {
        "S \(completedMinutes.readableDuration) · F \(failedMinutes.readableDuration)"
    }

    var status: RoutineLabelControlStatus {
        if plannedMinutes == 0 {
            return .idle
        }

        if completedMinutes >= plannedMinutes {
            return .onTrack
        }

        if failedMinutes > 0 {
            return .behind
        }

        return .tracked
    }
}

private enum RoutineLabelControlStatus: Equatable {
    case onTrack
    case behind
    case tracked
    case idle

    var title: String {
        switch self {
        case .onTrack: "On Track"
        case .behind: "Behind"
        case .tracked: "Tracked"
        case .idle: "Idle"
        }
    }
}

private enum StreakOccurrenceStatus {
    case done
    case skipped
    case missed
    case open
}

private struct StreakMetricCard: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(TaskListPalette.secondaryText)
                .lineLimit(1)

            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
                .foregroundStyle(TaskListPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(detail)
                .font(.caption2.weight(.medium))
                .foregroundStyle(TaskListPalette.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TaskListPalette.rowBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(TaskListPalette.separator.opacity(0.28), lineWidth: 0.5)
        }
    }
}

private struct StreakRoutineLabelTimeRow: View {
    let summary: RoutineLabelTimeSummary

    private var tint: Color {
        switch summary.label.rawValue {
        case RoutineLabel.study.rawValue:
            MissionTheme.accent
        case RoutineLabel.coding.rawValue:
            TaskListPalette.secondaryText
        case RoutineLabel.work.rawValue:
            TaskListPalette.primaryText
        case RoutineLabel.life.rawValue:
            TaskListPalette.primaryText
        case RoutineLabel.play.rawValue:
            TaskListPalette.tertiaryText
        case RoutineLabel.hobby.rawValue:
            MissionTheme.secondaryText
        case RoutineLabel.rest.rawValue:
            TaskListPalette.secondaryText
        case RoutineLabel.sleep.rawValue:
            Color(uiColor: .systemTeal)
        case RoutineLabel.health.rawValue:
            MissionTheme.success
        case RoutineLabel.money.rawValue:
            Color(uiColor: .systemYellow)
        case RoutineLabel.admin.rawValue:
            TaskListPalette.secondaryText
        case RoutineLabel.social.rawValue:
            Color(uiColor: .systemBlue)
        default:
            MissionTheme.accent
        }
    }

    private var statusTint: Color {
        switch summary.status {
        case .onTrack, .tracked:
            MissionTheme.success
        case .behind:
            MissionTheme.danger
        case .idle:
            TaskListPalette.tertiaryText
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                RoutineLabelBadge(
                    label: summary.label,
                    fillsWidth: false,
                    fixedWidth: 108,
                    font: .caption.weight(.semibold),
                    iconSize: 12,
                    height: 30,
                    horizontalPadding: 9,
                    normalForeground: TaskListPalette.primaryText,
                    normalBackground: TaskListPalette.fill
                )

                Text(summary.status.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(statusTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(statusTint.opacity(0.12), in: Capsule(style: .continuous))

                Spacer(minLength: 8)

                Text(summary.outcomeText)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(TaskListPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            ProgressView(value: summary.fraction)
                .tint(summary.status == .idle ? tint : statusTint)

            Text(summary.detailText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(TaskListPalette.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
    }
}

private struct StreakFailReasonRow: View {
    let summary: RoutineFailReasonSummary

    private var symbolName: String {
        summary.reason?.symbolName ?? "questionmark.circle"
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MissionTheme.danger)
                .frame(width: 24, height: 24)
                .background(MissionTheme.danger.opacity(0.1), in: Circle())

            Text(summary.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(TaskListPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 8)

            Text(summary.detailText)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(TaskListPalette.secondaryText)
                .lineLimit(1)
        }
    }
}

private struct StreakDayRail: View {
    let days: [StreakDaySummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Daily streak")
                .font(.headline.weight(.semibold))
                .foregroundStyle(TaskListPalette.primaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(days) { day in
                        StreakDayCell(day: day)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(14)
        .background(TaskListPalette.rowBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(TaskListPalette.separator.opacity(0.28), lineWidth: 0.5)
        }
    }
}

private struct StreakDayCell: View {
    let day: StreakDaySummary

    private var fill: Color {
        if day.isSuccessDay {
            return MissionTheme.accent
        }

        if day.scheduled == 0 {
            return Color(uiColor: .tertiarySystemFill)
        }

        return Color(uiColor: .secondarySystemFill)
    }

    private var foreground: Color {
        day.isSuccessDay ? MissionTheme.selectedText : TaskListPalette.secondaryText
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(day.date.formatted(.dateTime.weekday(.narrow)))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(TaskListPalette.tertiaryText)
                .lineLimit(1)

            Text("\(Calendar.current.component(.day, from: day.date))")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(foreground)
                .frame(width: 34, height: 34)
                .background(fill, in: Circle())

            Text(day.statusText)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(TaskListPalette.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 54)
        }
    }
}

private struct StreakHistoryRowData: Identifiable {
    let id: String
    let title: String
    let detail: String
}

private struct StreakHistoryRow: View {
    let row: StreakHistoryRowData

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(row.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TaskListPalette.primaryText)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(row.detail)
                .font(.caption.weight(.medium))
                .foregroundStyle(TaskListPalette.secondaryText)
                .lineLimit(1)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
    }
}
