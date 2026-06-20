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
                controlHeader
                streakHeroCard
                StreakSignalMap(days: stats.days, mode: mode)
                if !stats.routineLabelTimeSummaries.isEmpty {
                    routineLabelPerformanceCard
                }
                if !stats.failReasonSummaries.isEmpty {
                    failurePatternCard
                }
                metricGrid
                historySection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 96)
        }
        .background(TaskListPalette.background)
        .sensoryFeedback(.selection, trigger: mode)
    }

    private var controlHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            modePicker

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Analysis")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TaskListPalette.secondaryText)
                        .lineLimit(1)

                    Text("Streak")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(TaskListPalette.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(period.title)
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
        .padding(14)
        .background(TaskListPalette.rowBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(TaskListPalette.separator.opacity(0.28), lineWidth: 0.5)
        }
    }

    private var modePicker: some View {
        Picker("Range", selection: $mode) {
            ForEach(StreakPeriodMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var timeControlCard: some View {
        StreakTimeControlCard(stats: stats)
    }

    private var streakHeroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    Label(stats.controlStateTitle, systemImage: stats.controlStateSymbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(stats.controlStateTint)
                        .lineLimit(1)

                    Text("\(stats.currentStreak)")
                        .font(.system(size: 46, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(TaskListPalette.primaryText)
                        .lineLimit(1)

                    Text(stats.currentStreak == 1 ? "day streak" : "day streak")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TaskListPalette.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 7) {
                    Text("Today")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TaskListPalette.tertiaryText)
                        .lineLimit(1)

                    Text(stats.todayStatusText)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(TaskListPalette.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(stats.todayActionText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(TaskListPalette.secondaryText)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                }
            }

            ProgressView(value: stats.completedTimeFraction)
                .tint(stats.controlStateTint)

            HStack(spacing: 8) {
                StreakControlMetric(title: "Spent", value: stats.completedRoutineTimeText, tint: MissionTheme.success)
                StreakControlMetric(title: "Failed", value: stats.exceptionRoutineTimeText, tint: MissionTheme.danger)
                StreakControlMetric(title: "Open", value: stats.openRoutineTimeText, tint: MissionTheme.info)
            }
        }
        .padding(16)
        .background(TaskListPalette.rowBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(TaskListPalette.separator.opacity(0.30), lineWidth: 0.5)
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
                title: "Active days",
                value: "\(stats.activeDays)",
                detail: "\(stats.bestStreak) best streak"
            )

            StreakMetricCard(
                title: "Tasks done",
                value: "\(stats.completedTasks.count)",
                detail: "completed in range"
            )

            StreakMetricCard(
                title: "Exceptions",
                value: "\(stats.exceptionRoutines)",
                detail: "\(stats.skippedRoutines) failed · \(stats.missedRoutines) missed"
            )
        }
    }

    private var timeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Captured time")
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

            Text("\(stats.completedRoutineTimeText) captured of \(stats.plannedRoutineTimeText) planned")
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

    private var routineLabelPerformanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Where your time went")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(TaskListPalette.primaryText)

                Spacer(minLength: 8)

                Text(stats.routineLabelTotalText)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(TaskListPalette.secondaryText)
                    .lineLimit(1)
            }

            VStack(spacing: 12) {
                ForEach(stats.routineLabelTimeSummaries) { summary in
                    StreakRoutineLabelTimeRow(summary: summary)
                }
            }

            Text(stats.labelInsightText)
                .font(.caption.weight(.medium))
                .foregroundStyle(TaskListPalette.secondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
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
                Text("Why routines failed")
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
        let component: Calendar.Component
        switch mode {
        case .week:
            component = .weekOfYear
        case .month:
            component = .month
        case .year:
            component = .year
        }

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
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
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
        case .year:
            let components = calendar.dateComponents([.year], from: date)
            let yearStart = calendar.date(from: components).map(calendar.startOfDay(for:)) ?? calendar.startOfDay(for: date)
            self.start = yearStart
            self.end = calendar.date(byAdding: .year, value: 1, to: yearStart) ?? yearStart
        }
    }

    var title: String {
        switch mode {
        case .week:
            let endDate = calendar.date(byAdding: .day, value: -1, to: end) ?? end
            return "\(start.formatted(.dateTime.month(.abbreviated).day())) - \(endDate.formatted(.dateTime.month(.abbreviated).day()))"
        case .month:
            return start.formatted(.dateTime.month(.wide).year())
        case .year:
            return start.formatted(.dateTime.year())
        }
    }

    var subtitle: String {
        switch mode {
        case .week:
            "Weekly routine operations"
        case .month:
            "Monthly time coverage"
        case .year:
            "Annual control surface"
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
    let routineLabelTimeSummaries: [RoutineLabelTimeSummary]
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
        let displayDates = Self.dates(from: period.start, to: period.end, calendar: calendar)
        let includedDates = Self.dates(from: period.start, to: analysisEnd, calendar: calendar)
        let labelTargetDates = period.mode == .week
            ? Self.dates(from: period.start, to: period.end, calendar: calendar)
            : includedDates

        var allOccurrences: [StreakRoutineOccurrence] = []
        var dailySummaries: [StreakDaySummary] = []
        var labelOccurrences: [StreakRoutineOccurrence] = []
        let customRoutineLabels = routineLabelOptions
            .filter(\.isCustom)
            .map { CustomRoutineLabel(id: $0.rawValue, title: $0.title, symbolName: $0.symbolName) }
        let stateLookup = RoutineOccurrenceStateLookup(states: routineStates, calendar: calendar)

        for date in displayDates {
            guard date < analysisEnd else {
                dailySummaries.append(StreakDaySummary(date: date, occurrences: [], calendar: calendar))
                continue
            }

            let routines = items.routines(on: date, routineStates: routineStates, calendar: calendar)
            let occurrences = routines.map { routine in
                Self.occurrence(
                    for: routine,
                    on: date,
                    todayStart: todayStart,
                    customRoutineLabels: customRoutineLabels,
                    stateLookup: stateLookup,
                    calendar: calendar
                )
            }

            allOccurrences.append(contentsOf: occurrences)
            dailySummaries.append(StreakDaySummary(date: date, occurrences: occurrences, calendar: calendar))
        }

        for date in labelTargetDates {
            let routines = items.routines(on: date, routineStates: routineStates, calendar: calendar)
            let occurrences = routines.map { routine in
                Self.occurrence(
                    for: routine,
                    on: date,
                    todayStart: todayStart,
                    customRoutineLabels: customRoutineLabels,
                    stateLookup: stateLookup,
                    calendar: calendar,
                    idPrefix: "label"
                )
            }

            labelOccurrences.append(contentsOf: occurrences)
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
        self.routineLabelTimeSummaries = routineLabelOptions.compactMap { label in
            let matchingOccurrences = labelOccurrences.filter { $0.label?.rawValue == label.rawValue }
            let plannedMinutes = matchingOccurrences.reduce(0) { $0 + $1.minutes }
            let completedMinutes = matchingOccurrences
                .filter { $0.status == .done }
                .reduce(0) { $0 + $1.minutes }
            let failedMinutes = matchingOccurrences
                .filter { $0.status == .skipped || $0.status == .missed }
                .reduce(0) { $0 + $1.minutes }

            guard plannedMinutes > 0 || completedMinutes > 0 || failedMinutes > 0 else {
                return nil
            }

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
        .sorted {
            if $0.plannedMinutes != $1.plannedMinutes {
                return $0.plannedMinutes > $1.plannedMinutes
            }

            return $0.label.title < $1.label.title
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

    var exceptionRoutines: Int {
        skippedRoutines + missedRoutines
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

    var currentStreak: Int {
        days
            .filter { $0.scheduled > 0 }
            .reversed()
            .prefix { $0.isSuccessDay }
            .count
    }

    var todaySummary: StreakDaySummary? {
        days.last { Calendar.current.isDateInToday($0.date) }
    }

    var todayStatusText: String {
        guard let todaySummary, todaySummary.scheduled > 0 else {
            return "No routines"
        }

        if todaySummary.isSuccessDay {
            return "Secured"
        }

        if todaySummary.open > 0 {
            return "\(todaySummary.open) left"
        }

        if todaySummary.hasException {
            return "Needs repair"
        }

        return "\(todaySummary.done)/\(todaySummary.scheduled)"
    }

    var todayActionText: String {
        guard let todaySummary, todaySummary.scheduled > 0 else {
            return "Nothing scheduled today."
        }

        if todaySummary.isSuccessDay {
            return "Your streak is protected today."
        }

        if todaySummary.open > 0 {
            return "Finish open routines to keep the streak."
        }

        if todaySummary.hasException {
            return "Review what broke the routine."
        }

        return "Keep today's plan moving."
    }

    var activeDays: Int {
        days.filter { $0.scheduled > 0 }.count
    }

    var plannedRoutineMinutes: Int {
        scheduledOccurrences.reduce(0) { $0 + $1.minutes }
    }

    var completedRoutineMinutes: Int {
        scheduledOccurrences
            .filter { $0.status == .done }
            .reduce(0) { $0 + $1.minutes }
    }

    var exceptionRoutineMinutes: Int {
        scheduledOccurrences
            .filter { $0.status == .skipped || $0.status == .missed }
            .reduce(0) { $0 + $1.minutes }
    }

    var openRoutineMinutes: Int {
        scheduledOccurrences
            .filter { $0.status == .open }
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

    var exceptionRoutineTimeText: String {
        exceptionRoutineMinutes.readableDuration
    }

    var openRoutineTimeText: String {
        openRoutineMinutes.readableDuration
    }

    var routineLabelTotalText: String {
        let completedMinutes = routineLabelTimeSummaries.reduce(0) { $0 + $1.completedMinutes }
        let plannedMinutes = routineLabelTimeSummaries.reduce(0) { $0 + $1.plannedMinutes }
        return "\(completedMinutes.readableDuration) / \(plannedMinutes.readableDuration)"
    }

    var labelInsightText: String {
        guard let mostTime = routineLabelTimeSummaries.max(by: { $0.completedMinutes < $1.completedMinutes }) else {
            return "Add labels to routines to see where your time goes."
        }

        if let weakest = routineLabelTimeSummaries
            .filter({ $0.plannedMinutes > 0 && $0.failedMinutes > 0 })
            .max(by: { $0.failedMinutes < $1.failedMinutes }) {
            if mostTime.completedMinutes > 0 {
                return "\(mostTime.label.title) has the most captured time. \(weakest.label.title) is where the most time was lost."
            }

            return "\(weakest.label.title) is where the most planned time was lost."
        }

        if mostTime.completedMinutes > 0 {
            return "\(mostTime.label.title) has the most captured time this period."
        }

        guard let mostPlanned = routineLabelTimeSummaries.max(by: { $0.plannedMinutes < $1.plannedMinutes }) else {
            return "Add labels to routines to see where your time goes."
        }

        return "\(mostPlanned.label.title) has the most planned time this period."
    }

    var controlStateTitle: String {
        if plannedRoutineMinutes == 0 {
            return "Idle"
        }

        if openRoutines > 0 {
            return "Live"
        }

        if exceptionRoutines > 0 {
            return "Exception"
        }

        return "Stable"
    }

    var controlStateSymbol: String {
        switch controlStateTitle {
        case "Live": "dot.radiowaves.left.and.right"
        case "Exception": "exclamationmark.triangle.fill"
        case "Stable": "checkmark.seal.fill"
        default: "circle.dashed"
        }
    }

    var controlStateTint: Color {
        switch controlStateTitle {
        case "Live":
            MissionTheme.info
        case "Exception":
            MissionTheme.danger
        case "Stable":
            MissionTheme.success
        default:
            TaskListPalette.tertiaryText
        }
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

    private static func occurrence(
        for routine: ScheduleItem,
        on date: Date,
        todayStart: Date,
        customRoutineLabels: [CustomRoutineLabel],
        stateLookup: RoutineOccurrenceStateLookup,
        calendar: Calendar,
        idPrefix: String? = nil
    ) -> StreakRoutineOccurrence {
        let state = stateLookup.state(for: routine, on: date)
        let effectiveStatus: StreakOccurrenceStatus
        switch state?.status ?? .pending {
        case .done:
            effectiveStatus = .done
        case .skipped:
            effectiveStatus = .skipped
        case .pending:
            effectiveStatus = date < todayStart ? .missed : .open
        }

        let idComponents = [
            idPrefix,
            routine.id.uuidString,
            date.timeIntervalSince1970.description
        ].compactMap(\.self)

        return StreakRoutineOccurrence(
            id: idComponents.joined(separator: "-"),
            routineID: routine.id,
            title: routine.title,
            label: RoutineLabelOption.option(for: routine.routineLabelRawValue, customLabels: customRoutineLabels),
            date: date,
            status: effectiveStatus,
            failReason: state?.failReason,
            minutes: max(5, routine.plannedDurationMinutes(state: state, calendar: calendar))
        )
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
    let plannedMinutes: Int
    let doneMinutes: Int
    let exceptionMinutes: Int

    init(date: Date, occurrences: [StreakRoutineOccurrence], calendar: Calendar) {
        self.id = calendar.startOfDay(for: date)
        self.date = calendar.startOfDay(for: date)
        self.scheduled = occurrences.count
        self.done = occurrences.filter { $0.status == .done }.count
        self.skipped = occurrences.filter { $0.status == .skipped }.count
        self.missed = occurrences.filter { $0.status == .missed }.count
        self.open = occurrences.filter { $0.status == .open }.count
        self.plannedMinutes = occurrences.reduce(0) { $0 + $1.minutes }
        self.doneMinutes = occurrences
            .filter { $0.status == .done }
            .reduce(0) { $0 + $1.minutes }
        self.exceptionMinutes = occurrences
            .filter { $0.status == .skipped || $0.status == .missed }
            .reduce(0) { $0 + $1.minutes }
    }

    var isSuccessDay: Bool {
        scheduled > 0 && done == scheduled
    }

    var completionFraction: Double {
        guard plannedMinutes > 0 else { return 0 }
        return min(1, Double(doneMinutes) / Double(plannedMinutes))
    }

    var hasException: Bool {
        skipped > 0 || missed > 0
    }

    var statusText: String {
        if scheduled == 0 { return "No routines" }
        if isSuccessDay { return "Done" }
        if open > 0 { return "\(open) open" }
        if missed > 0 { return "\(missed) missed" }
        if skipped > 0 { return "\(skipped) skipped" }
        return "\(done)/\(scheduled)"
    }

    var timeText: String {
        if plannedMinutes == 0 { return "0m" }
        return "\(doneMinutes.readableDuration) / \(plannedMinutes.readableDuration)"
    }
}

private struct RoutineOccurrenceStateLookup {
    private let statesByRoutineAndDay: [String: RoutineOccurrenceState]
    private let calendar: Calendar

    init(states: [RoutineOccurrenceState], calendar: Calendar) {
        self.calendar = calendar
        self.statesByRoutineAndDay = Dictionary(
            states.map { (Self.key(routineID: $0.routineID, dayStart: $0.dayStart, calendar: calendar), $0) },
            uniquingKeysWith: { lhs, rhs in
                lhs.updatedAt >= rhs.updatedAt ? lhs : rhs
            }
        )
    }

    func state(for routine: ScheduleItem, on date: Date) -> RoutineOccurrenceState? {
        statesByRoutineAndDay[
            Self.key(routineID: routine.id, dayStart: date, calendar: calendar)
        ]
    }

    private static func key(routineID: UUID, dayStart: Date, calendar: Calendar) -> String {
        "\(routineID.uuidString)-\(Int(calendar.startOfDay(for: dayStart).timeIntervalSince1970))"
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

    var failureFraction: Double {
        guard denominatorMinutes > 0 else { return 0 }
        return min(1, Double(failedMinutes) / Double(denominatorMinutes))
    }

    var successRateText: String {
        guard plannedMinutes > 0 else { return "0%" }
        return "\(Int((fraction * 100).rounded()))%"
    }

    var failureRateText: String {
        guard plannedMinutes > 0 else { return "0%" }
        return "\(Int((failureFraction * 100).rounded()))%"
    }

    var detailText: String {
        "Planned \(plannedMinutes.readableDuration) · Left \(remainingMinutes.readableDuration)"
    }

    var outcomeText: String {
        "\(completedMinutes.readableDuration) spent"
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

private struct StreakTimeControlCard: View {
    let stats: StreakStats

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Control status", systemImage: stats.controlStateSymbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(stats.controlStateTint)
                        .lineLimit(1)

                    Text(stats.completedRoutineTimeText)
                        .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(TaskListPalette.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text("of \(stats.plannedRoutineTimeText) planned")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(TaskListPalette.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(stats.controlStateTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(stats.controlStateTint)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(stats.controlStateTint.opacity(0.12), in: Capsule(style: .continuous))
            }

            ProgressView(value: stats.completedTimeFraction)
                .tint(stats.controlStateTint)

            HStack(spacing: 8) {
                StreakControlMetric(title: "Captured", value: stats.completedRoutineTimeText, tint: MissionTheme.success)
                StreakControlMetric(title: "Lost", value: stats.exceptionRoutineTimeText, tint: MissionTheme.danger)
                StreakControlMetric(title: "Live", value: stats.openRoutineTimeText, tint: MissionTheme.info)
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

private struct StreakControlMetric: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(TaskListPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.76)

            HStack(spacing: 5) {
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)

                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(TaskListPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TaskListPalette.fill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
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
            TaskListPalette.secondaryText
        case RoutineLabel.hobby.rawValue:
            MissionTheme.secondaryText
        case RoutineLabel.rest.rawValue:
            TaskListPalette.secondaryText
        case RoutineLabel.sleep.rawValue:
            TaskListPalette.secondaryText
        case RoutineLabel.health.rawValue:
            MissionTheme.success
        case RoutineLabel.money.rawValue:
            TaskListPalette.secondaryText
        case RoutineLabel.admin.rawValue:
            TaskListPalette.secondaryText
        case RoutineLabel.social.rawValue:
            TaskListPalette.secondaryText
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
            TaskListPalette.secondaryText
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 10) {
                RoutineLabelBadge(
                    label: summary.label,
                    fillsWidth: false,
                    fixedWidth: 116,
                    font: .caption.weight(.semibold),
                    iconSize: 12,
                    height: 30,
                    horizontalPadding: 9,
                    normalForeground: TaskListPalette.primaryText,
                    normalBackground: TaskListPalette.fill
                )

                Spacer(minLength: 8)

                Text(summary.outcomeText)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(TaskListPalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            GeometryReader { proxy in
                let width = proxy.size.width

                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(TaskListPalette.fill)

                    Capsule(style: .continuous)
                        .fill(MissionTheme.danger.opacity(0.28))
                        .frame(width: width * summary.failureFraction)

                    Capsule(style: .continuous)
                        .fill(summary.status == .idle ? tint : statusTint)
                        .frame(width: width * summary.fraction)
                }
            }
            .frame(height: 8)

            HStack(spacing: 8) {
                StreakLabelStatPill(title: "Success", value: summary.successRateText, tint: MissionTheme.success)
                StreakLabelStatPill(title: "Failed", value: summary.failureRateText, tint: MissionTheme.danger)
                Spacer(minLength: 0)
            }

            Text(summary.detailText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(TaskListPalette.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
    }
}

private struct StreakLabelStatPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(TaskListPalette.secondaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(TaskListPalette.fill, in: Capsule(style: .continuous))
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

private struct StreakSignalMap: View {
    let days: [StreakDaySummary]
    let mode: StreakPeriodMode

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        return calendar
    }

    private var alignedDays: [StreakDaySummary?] {
        guard let firstDay = days.first else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstDay.date)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leadingBlanks) + days.map(Optional.some)
    }

    private var title: String {
        switch mode {
        case .week:
            "Weekly signal"
        case .month:
            "Monthly signal"
        case .year:
            "Annual signal"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(TaskListPalette.primaryText)

                Spacer(minLength: 8)

                Text("\(days.filter { $0.isSuccessDay }.count) clean")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(TaskListPalette.secondaryText)
                    .lineLimit(1)
            }

            signalContent

            StreakSignalLegend()
        }
        .padding(14)
        .background(TaskListPalette.rowBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(TaskListPalette.separator.opacity(0.28), lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private var signalContent: some View {
        switch mode {
        case .week:
            HStack(spacing: 8) {
                ForEach(days) { day in
                    StreakSignalWeekCell(day: day)
                }
            }
        case .month:
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 7) {
                ForEach(alignedDays.indices, id: \.self) { index in
                    StreakSignalMonthCell(day: alignedDays[index])
                }
            }
        case .year:
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: Array(repeating: GridItem(.fixed(14), spacing: 4), count: 7), spacing: 4) {
                    ForEach(alignedDays.indices, id: \.self) { index in
                        StreakSignalYearCell(day: alignedDays[index])
                    }
                }
                .frame(height: 122)
                .padding(.vertical, 2)
            }
        }
    }
}

private struct StreakSignalWeekCell: View {
    let day: StreakDaySummary

    var body: some View {
        VStack(spacing: 6) {
            Text(day.date.formatted(.dateTime.weekday(.narrow)))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(TaskListPalette.tertiaryText)
                .lineLimit(1)

            ZStack {
                Circle()
                    .fill(StreakSignalColor.fill(for: day))
                    .overlay {
                        Circle()
                            .stroke(StreakSignalColor.stroke(for: day), lineWidth: 0.75)
                    }

                Text("\(Calendar.current.component(.day, from: day.date))")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(StreakSignalColor.foreground(for: day))
                    .lineLimit(1)
            }
            .frame(width: 38, height: 38)

            Text(day.timeText)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(TaskListPalette.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("\(day.date.formatted(.dateTime.weekday(.wide).month().day())), \(day.statusText), \(day.timeText)")
    }
}

private struct StreakSignalMonthCell: View {
    let day: StreakDaySummary?

    var body: some View {
        Group {
            if let day {
                VStack(spacing: 5) {
                    Text("\(Calendar.current.component(.day, from: day.date))")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(TaskListPalette.secondaryText)
                        .lineLimit(1)

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(StreakSignalColor.fill(for: day))
                        .overlay {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(StreakSignalColor.stroke(for: day), lineWidth: 0.5)
                        }
                        .frame(height: 12)
                }
                .frame(height: 34)
                .accessibilityLabel("\(day.date.formatted(.dateTime.month().day())), \(day.statusText), \(day.timeText)")
            } else {
                Color.clear
                    .frame(height: 34)
            }
        }
    }
}

private struct StreakSignalYearCell: View {
    let day: StreakDaySummary?

    var body: some View {
        Group {
            if let day {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(StreakSignalColor.fill(for: day))
                    .overlay {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(StreakSignalColor.stroke(for: day), lineWidth: 0.5)
                    }
                    .frame(width: 14, height: 14)
                    .accessibilityLabel("\(day.date.formatted(.dateTime.month().day())), \(day.statusText), \(day.timeText)")
            } else {
                Color.clear
                    .frame(width: 14, height: 14)
            }
        }
    }
}

private enum StreakSignalColor {
    static func fill(for day: StreakDaySummary) -> Color {
        if day.scheduled == 0 {
            return Color(uiColor: .tertiarySystemFill)
        }

        if day.hasException {
            return MissionTheme.danger.opacity(max(0.28, day.completionFraction * 0.45 + 0.28))
        }

        if day.open > 0 {
            return MissionTheme.info.opacity(max(0.22, day.completionFraction * 0.48 + 0.22))
        }

        if day.isSuccessDay {
            return MissionTheme.success
        }

        return MissionTheme.accent.opacity(max(0.18, day.completionFraction * 0.54 + 0.18))
    }

    static func foreground(for day: StreakDaySummary) -> Color {
        day.isSuccessDay ? MissionTheme.selectedText : TaskListPalette.primaryText
    }

    static func stroke(for day: StreakDaySummary) -> Color {
        if day.scheduled == 0 {
            return TaskListPalette.separator.opacity(0.34)
        }

        if day.hasException {
            return MissionTheme.danger.opacity(0.34)
        }

        if day.open > 0 {
            return MissionTheme.info.opacity(0.34)
        }

        if day.isSuccessDay {
            return MissionTheme.success.opacity(0.44)
        }

        return TaskListPalette.separator.opacity(0.38)
    }
}

private struct StreakSignalLegend: View {
    var body: some View {
        HStack(spacing: 10) {
            legendItem(title: "Captured", color: MissionTheme.success)
            legendItem(title: "Live", color: MissionTheme.info)
            legendItem(title: "Exception", color: MissionTheme.danger)
            legendItem(title: "Idle", color: Color(uiColor: .tertiarySystemFill))
        }
    }

    private func legendItem(title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .overlay {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .stroke(TaskListPalette.separator.opacity(0.36), lineWidth: 0.5)
                }
                .frame(width: 9, height: 9)

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(TaskListPalette.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
