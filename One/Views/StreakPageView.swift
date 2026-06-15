import SwiftUI

struct StreakPageView: View {
    let items: [ScheduleItem]
    let routineStates: [RoutineOccurrenceState]

    @State private var mode: StreakPeriodMode = .week
    @State private var referenceDate = Calendar.current.startOfDay(for: .now)

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
                Text("Weekly routine hours")
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

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            historyGroup(
                title: "Completed tasks",
                emptyTitle: "No completed tasks",
                rows: stats.completedTasks.map { task in
                    StreakHistoryRowData(
                        id: "task-\(task.id.uuidString)",
                        title: task.title,
                        detail: (task.completedAt ?? task.createdAt).formatted(.dateTime.locale(.enUS).month(.abbreviated).day())
                    )
                }
            )

            historyGroup(
                title: "Completed routines",
                emptyTitle: "No completed routines",
                rows: stats.completedRoutineOccurrences.map { occurrence in
                    let dateText = occurrence.date.formatted(.dateTime.locale(.enUS).weekday(.abbreviated).month(.abbreviated).day())
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
            return "\(start.formatted(.dateTime.locale(.enUS).month(.abbreviated).day())) - \(endDate.formatted(.dateTime.locale(.enUS).month(.abbreviated).day()))"
        case .month:
            return start.formatted(.dateTime.locale(.enUS).month(.wide).year())
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

    private let scheduledOccurrences: [StreakRoutineOccurrence]

    init(
        items: [ScheduleItem],
        routineStates: [RoutineOccurrenceState],
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
                    label: routine.routineLabel,
                    date: date,
                    status: effectiveStatus,
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
                    label: routine.routineLabel,
                    date: date,
                    status: effectiveStatus,
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
        self.weeklyRoutineLabelSummaries = RoutineLabel.allCases.map { label in
            let labelOccurrences = weeklyLabelOccurrences.filter { $0.label == Optional(label) }
            let plannedMinutes = labelOccurrences.reduce(0) { $0 + $1.minutes }
            let completedMinutes = labelOccurrences
                .filter { $0.status == .done }
                .reduce(0) { $0 + $1.minutes }

            return RoutineLabelTimeSummary(
                label: label,
                plannedMinutes: plannedMinutes,
                completedMinutes: completedMinutes
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
    let label: RoutineLabel?
    let date: Date
    let status: StreakOccurrenceStatus
    let minutes: Int
}

private struct RoutineLabelTimeSummary: Identifiable {
    let label: RoutineLabel
    let plannedMinutes: Int
    let completedMinutes: Int

    var id: String { label.rawValue }

    var fraction: Double {
        guard plannedMinutes > 0 else { return 0 }
        return Double(completedMinutes) / Double(plannedMinutes)
    }

    var detailText: String {
        "\(completedMinutes.readableDuration) / \(plannedMinutes.readableDuration)"
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
        switch summary.label {
        case .study:
            MissionTheme.accent
        case .coding:
            TaskListPalette.secondaryText
        case .life:
            TaskListPalette.primaryText
        case .play:
            TaskListPalette.tertiaryText
        case .hobby:
            MissionTheme.secondaryText
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Label(summary.label.title, systemImage: summary.label.symbolName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TaskListPalette.primaryText)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(TaskListPalette.fill, in: Capsule(style: .continuous))

                Spacer(minLength: 8)

                Text(summary.detailText)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(TaskListPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            ProgressView(value: summary.fraction)
                .tint(tint)
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
            Text(day.date.formatted(.dateTime.locale(.enUS).weekday(.narrow)))
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
