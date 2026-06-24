import SwiftData
import SwiftUI

struct TimetablePageView: View {
    @Environment(\.modelContext) private var modelContext

    let items: [ScheduleItem]
    let routineStates: [RoutineOccurrenceState]
    let onAddRoutine: (Date) -> Void
    let onEdit: (ScheduleItem, Date) -> Void
    let onMoveRoutine: (ScheduleItem, Date, Int) -> Void
    let onMarkRoutineDone: (ScheduleItem, Date) -> Void
    let onSkipRoutine: (ScheduleItem, Date) -> Void

    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var viewMode: TimetableViewMode = TimetableViewMode.storedValue()
    @State private var calendarTurnDirection = 1
    @State private var defersInitialTimelineScroll = false
    @State private var skipsNextSelectedDateTimelineScroll = false
    @State private var initialTimelineScrollWorkItem: DispatchWorkItem?

    private let calendar = Calendar.current
    private let viewModeTransitionDuration = 0.16
    private let deferredTimelineScrollDelay = 0.22

    private var routineSegments: [TimelineEventSegment] {
        let dayStart = selectedDayStart

        return items
            .routineOccurrenceProjections(
                displaying: dayStart,
                routineStates: routineStates,
                calendar: calendar
            )
            .compactMap { segment(for: $0, displayDate: dayStart) }
    }

    private var calendarItems: [ScheduleItem] {
        items
    }

    private var initialTimelineHour: Int {
        let currentHour = calendar.component(.hour, from: .now)
        let firstRoutineHour = routineSegments
            .map { max(0, $0.startMinute) / 60 }
            .min()
        let baseHour = calendar.isDateInToday(selectedDate) ? min(firstRoutineHour ?? currentHour, currentHour) : (firstRoutineHour ?? 8)

        return min(22, max(0, baseHour - 1))
    }

    private var dayStartHour: Int {
        0
    }

    private var dayEndHour: Int {
        24
    }

    private let scrollContentBottomPadding: CGFloat = 82

    private var weekDays: [Date] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
            return [selectedDate]
        }

        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: week.start).map(calendar.startOfDay(for:))
        }
    }

    private var monthDays: [Date] {
        guard
            let month = calendar.dateInterval(of: .month, for: selectedDate),
            let range = calendar.range(of: .day, in: .month, for: selectedDate)
        else {
            return [selectedDate]
        }

        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: month.start).map(calendar.startOfDay(for:))
        }
    }

    private var selectedDay: Binding<Date> {
        Binding(
            get: { calendar.startOfDay(for: selectedDate) },
            set: { setSelectedDate($0) }
        )
    }

    private var selectedDayStart: Date {
        calendar.startOfDay(for: selectedDate)
    }

    private var selectedWeekStart: Date {
        calendar
            .dateInterval(of: .weekOfYear, for: selectedDate)
            .map { calendar.startOfDay(for: $0.start) } ?? selectedDayStart
    }

    private var showsTodayNowMode: Bool {
        viewMode == .day && calendar.isDateInToday(selectedDate)
    }

    private var routineProgress: RoutineDayProgress {
        let segments = routineSegments
        let statuses = segments.map { segment in
            routineStates.state(for: segment.item, on: segment.occurrenceDate, calendar: calendar)?.status ?? .pending
        }
        let doneCount = statuses.filter { $0 == .done }.count
        let skippedCount = statuses.filter { $0 == .skipped }.count
        return RoutineDayProgress(total: segments.count, done: doneCount, skipped: skippedCount)
    }

    private var missionSummary: CalendarMissionSummary {
        let segments = routineSegments
        let plannedMinutes = segments.reduce(0) { total, segment in
            total + segment.durationMinutes
        }
        let completedMinutes = segments.reduce(0) { total, segment in
            let state = routineStates.state(for: segment.item, on: segment.occurrenceDate, calendar: calendar)
            return state?.status == .done ? total + segment.durationMinutes : total
        }
        let openTaskCount = items
            .oneOffTasksForToday(selectedDate, calendar: calendar)
            .filter { !$0.isCompleted }
            .count

        return CalendarMissionSummary(
            plannedMinutes: plannedMinutes,
            completedMinutes: completedMinutes,
            openTaskCount: openTaskCount
        )
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            MissionTheme.panel
                .ignoresSafeArea()

            timetableContent

            if viewMode == .day {
                Button {
                    onAddRoutine(selectedDayStart)
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(MissionTheme.floatingButtonSymbol)
                        .frame(width: 54, height: 54)
                }
                .missionLiquidButton(.prominent)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Add routine to selected day")
                .padding(.trailing, 16)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            loadViewMode()
        }
        .sensoryFeedback(.selection, trigger: selectedDate)
    }

    private var timetableContent: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                CalendarControlHeader(
                    selectedDate: selectedDate,
                    viewMode: viewMode,
                    onSetViewMode: setViewMode
                )

                ZStack(alignment: .top) {
                    switch viewMode {
                    case .day:
                        dayContent(proxy: proxy)
                            .transition(.opacity)
                    case .month:
                        monthContent
                            .transition(.opacity)
                    }
                }
                .animation(.easeOut(duration: viewModeTransitionDuration), value: viewMode)
            }
            .background(MissionTheme.panel)
            .onAppear {
                scrollToInitialTimelinePosition(proxy)
            }
            .onChange(of: selectedDate) { _, _ in
                if skipsNextSelectedDateTimelineScroll {
                    skipsNextSelectedDateTimelineScroll = false
                    return
                }

                guard !defersInitialTimelineScroll else {
                    return
                }

                scrollToInitialTimelinePosition(proxy)
            }
            .onChange(of: viewMode) { _, _ in
                if defersInitialTimelineScroll, viewMode == .day {
                    scrollToInitialTimelinePosition(
                        proxy,
                        animated: false,
                        delay: deferredTimelineScrollDelay
                    )
                    defersInitialTimelineScroll = false
                } else {
                    scrollToInitialTimelinePosition(proxy)
                }
            }
        }
    }

    private func dayContent(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 0) {
            CalendarDayStrip(days: weekDays, selectedDate: selectedDay)
                .calendarPageTurn(for: selectedWeekStart, direction: calendarTurnDirection)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    swipeGesture(for: .week)
                )

            if showsTodayNowMode {
                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                    CalendarNowModeCard(
                        candidate: nowCandidate(at: timeline.date),
                        progress: routineProgress,
                        summary: missionSummary,
                        onAddRoutine: {
                            onAddRoutine(selectedDayStart)
                        },
                        onDone: { routine, occurrenceDate in
                            onMarkRoutineDone(routine, occurrenceDate)
                        },
                        onSkip: { routine, occurrenceDate in
                            onSkipRoutine(routine, occurrenceDate)
                        },
                        onSelectVersion: { routine, occurrenceDate, version in
                            selectRoutineVersion(version, for: routine, on: occurrenceDate)
                        }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)
            }

            ScrollView {
                CalendarDayView(
                    date: selectedDate,
                    routineSegments: routineSegments,
                    routineStates: routineStates,
                    startHour: dayStartHour,
                    endHour: dayEndHour,
                    onEdit: { routine, occurrenceDate in
                        onEdit(routine, occurrenceDate)
                    },
                    onMove: { routine, startMinute in
                        onMoveRoutine(routine, selectedDayStart, startMinute)
                    }
                )
                .calendarPageTurn(for: selectedDayStart, direction: calendarTurnDirection)
                .padding(.bottom, scrollContentBottomPadding)
            }
            .simultaneousGesture(
                swipeGesture(for: .day)
            )
            .refreshable {
                returnToCurrentTime(proxy)
            }
            .background(MissionTheme.panel)
        }
        .background(MissionTheme.panel)
    }

    private var monthContent: some View {
        ScrollView {
            CalendarMonthView(
                selectedDate: selectedDate,
                monthDays: monthGridDays,
                items: calendarItems,
                routineStates: routineStates,
                onSelectDate: selectDateFromMonth
            )
            .contentShape(Rectangle())
            .simultaneousGesture(
                swipeGesture(for: .month)
            )
            .padding(.bottom, scrollContentBottomPadding)
        }
        .background(MissionTheme.panel)
    }

    private func returnToCurrentTime(_ proxy: ScrollViewProxy) {
        guard viewMode == .day else {
            return
        }

        let today = calendar.startOfDay(for: .now)
        guard calendar.isDate(selectedDate, inSameDayAs: today) else {
            setSelectedDate(today)
            return
        }

        DispatchQueue.main.async {
            withAnimation(.snappy(duration: 0.22)) {
                proxy.scrollTo(CalendarLayout.currentTimeID, anchor: .center)
            }
        }
    }

    private func scrollToInitialTimelinePosition(
        _ proxy: ScrollViewProxy,
        animated: Bool = true,
        delay: TimeInterval = 0
    ) {
        guard viewMode != .month else {
            return
        }

        let showsCurrentTime = calendar.isDateInToday(selectedDate)
        let targetID = showsCurrentTime ? CalendarLayout.currentTimeID : CalendarLayout.hourID(initialTimelineHour)
        let anchor: UnitPoint = showsCurrentTime ? .center : .top
        let scrollAction = {
            if animated {
                withAnimation(.snappy(duration: 0.18)) {
                    proxy.scrollTo(targetID, anchor: anchor)
                }
            } else {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    proxy.scrollTo(targetID, anchor: anchor)
                }
            }
        }

        initialTimelineScrollWorkItem?.cancel()

        if delay > 0 {
            let workItem = DispatchWorkItem(block: scrollAction)
            initialTimelineScrollWorkItem = workItem
            DispatchQueue.main.asyncAfter(
                deadline: .now() + .milliseconds(Int(delay * 1000)),
                execute: workItem
            )
        } else {
            DispatchQueue.main.async {
                scrollAction()
            }
        }
    }

    private func loadViewMode() {
        guard
            let rawValue = UserDefaults.standard.string(forKey: TimetableViewMode.defaultsKey),
            let storedMode = TimetableViewMode(rawValue: rawValue)
        else {
            return
        }

        viewMode = storedMode
    }

    private func setViewMode(_ mode: TimetableViewMode) {
        initialTimelineScrollWorkItem?.cancel()
        defersInitialTimelineScroll = viewMode == .month && mode == .day

        withAnimation(.easeOut(duration: viewModeTransitionDuration)) {
            viewMode = mode
        }

        UserDefaults.standard.set(mode.rawValue, forKey: TimetableViewMode.defaultsKey)
    }

    private func selectDateFromMonth(_ date: Date) {
        let nextDate = calendar.startOfDay(for: date)
        calendarTurnDirection = nextDate >= selectedDate ? 1 : -1
        defersInitialTimelineScroll = true
        skipsNextSelectedDateTimelineScroll = nextDate != selectedDate
        initialTimelineScrollWorkItem?.cancel()

        withAnimation(.easeOut(duration: viewModeTransitionDuration)) {
            selectedDate = nextDate
            viewMode = .day
        }

        UserDefaults.standard.set(TimetableViewMode.day.rawValue, forKey: TimetableViewMode.defaultsKey)
    }

    private func swipeGesture(for scope: CalendarSwipeScope) -> some Gesture {
        DragGesture(minimumDistance: scope.minimumDistance)
            .onEnded { value in
                handleSwipe(value, scope: scope)
            }
    }

    private func handleSwipe(_ value: DragGesture.Value, scope: CalendarSwipeScope) {
        guard let direction = horizontalSwipeDirection(for: value) else {
            return
        }

        moveSelectedDate(by: scope.component, value: direction * scope.step)
    }

    private func horizontalSwipeDirection(for value: DragGesture.Value) -> Int? {
        let horizontal = value.translation.width
        let vertical = value.translation.height

        guard abs(horizontal) > 56, abs(horizontal) > abs(vertical) * 1.25 else {
            return nil
        }

        return horizontal < 0 ? 1 : -1
    }

    private func moveSelectedDate(by component: Calendar.Component, value: Int) {
        guard let nextDate = calendar.date(byAdding: component, value: value, to: selectedDate) else {
            return
        }

        calendarTurnDirection = value >= 0 ? 1 : -1

        withAnimation(.snappy(duration: 0.18)) {
            selectedDate = calendar.startOfDay(for: nextDate)
        }
    }

    private func setSelectedDate(_ date: Date) {
        let nextDate = calendar.startOfDay(for: date)
        guard nextDate != selectedDate else {
            return
        }

        calendarTurnDirection = nextDate > selectedDate ? 1 : -1

        withAnimation(.snappy(duration: 0.18)) {
            selectedDate = nextDate
        }
    }

    private func nowCandidate(at now: Date) -> RoutineNowCandidate? {
        guard calendar.isDate(now, inSameDayAs: selectedDate) else {
            return nil
        }

        let currentMinute = calendar.minuteOfDay(for: now)
        let candidates = nowCandidates(currentMinute: currentMinute)
        let pendingCandidates = candidates.filter { !$0.status.isResolved }

        if let activeCandidate = pendingCandidates
            .filter({ $0.startMinute <= currentMinute && currentMinute < $0.endMinute })
            .min(by: { $0.endMinute < $1.endMinute }) {
            return activeCandidate.withPhase(.active)
        }

        if let nextCandidate = pendingCandidates
            .filter({ $0.startMinute >= currentMinute })
            .min(by: { $0.startMinute < $1.startMinute }) {
            return nextCandidate.withPhase(.next)
        }

        return pendingCandidates
            .filter { $0.endMinute <= currentMinute }
            .max(by: { $0.endMinute < $1.endMinute })?
            .withPhase(.missed)
    }

    private func nowCandidates(currentMinute: Int) -> [RoutineNowCandidate] {
        let dayStart = selectedDayStart

        return items
            .routineOccurrenceProjections(
                displaying: dayStart,
                routineStates: routineStates,
                calendar: calendar
            )
            .compactMap {
                candidate(for: $0, displayDayStart: dayStart, currentMinute: currentMinute)
            }
    }

    private func candidate(
        for occurrence: RoutineOccurrenceProjection,
        displayDayStart: Date,
        currentMinute: Int
    ) -> RoutineNowCandidate? {
        let routine = occurrence.item
        let state = occurrence.state
        let delayMinutes = state?.delayMinutes ?? 0
        let versionOptions = routine.routineVersionOptions(calendar: calendar)
        let selectedVersion = routine.routineVersion(for: state?.routineVersionID, calendar: calendar)
        let duration = occurrence.durationMinutes
        let startMinute = occurrence.displayStartMinute(on: displayDayStart, calendar: calendar)
        let endMinute = startMinute + duration
        let phase: RoutineNowPhase = endMinute <= currentMinute ? .missed : .next

        return RoutineNowCandidate(
            item: routine,
            occurrenceDate: occurrence.occurrenceDate,
            phase: phase,
            status: state?.status ?? .pending,
            startMinute: startMinute,
            endMinute: endMinute,
            delayMinutes: delayMinutes,
            plannedDurationMinutes: duration,
            selectedVersion: selectedVersion,
            versionOptions: versionOptions,
            calendar: calendar,
            dayStart: displayDayStart
        )
    }

    private func selectRoutineVersion(_ version: RoutineVersion, for routine: ScheduleItem, on date: Date) {
        let dayStart = calendar.startOfDay(for: date)
        let existingState = routineStates.state(for: routine, on: dayStart, calendar: calendar)
        let state = existingState ?? RoutineOccurrenceState(routineID: routine.id, dayStart: dayStart)

        if existingState == nil {
            modelContext.insert(state)
        }

        state.routineVersionID = version.id
        state.updatedAt = .now
        try? modelContext.save()

        AppDataSyncService.updateWidgetSnapshot(
            modelContext: modelContext,
            queryItems: items,
            queryRoutineStates: routineStates,
            replacing: state
        )
    }

    private func segment(
        for occurrence: RoutineOccurrenceProjection,
        displayDate: Date
    ) -> TimelineEventSegment? {
        let isCurrentDayOccurrence = calendar.isDate(occurrence.occurrenceDate, inSameDayAs: displayDate)
        let visibleWindow: RoutineOccurrenceDisplayWindow

        if isCurrentDayOccurrence {
            guard occurrence.startsBeforeNextDay else {
                return nil
            }

            visibleWindow = RoutineOccurrenceDisplayWindow(
                startMinute: occurrence.startMinute,
                durationMinutes: occurrence.durationMinutes
            )
        } else if let carryoverWindow = occurrence.visibleDisplayWindow(on: displayDate, calendar: calendar) {
            visibleWindow = carryoverWindow
        } else {
            return nil
        }

        return TimelineEventSegment(
            item: occurrence.item,
            occurrenceDate: occurrence.occurrenceDate,
            startMinute: visibleWindow.startMinute,
            durationMinutes: visibleWindow.durationMinutes,
            displayedTimeRangeText: timeRangeText(
                startMinute: visibleWindow.startMinute,
                durationMinutes: visibleWindow.durationMinutes,
                on: displayDate
            ),
            allowsMove: isCurrentDayOccurrence,
            identitySuffix: "\(isCurrentDayOccurrence ? "current" : "carryover")-\(Int(occurrence.occurrenceDate.timeIntervalSince1970))"
        )
    }

    private func timeRangeText(startMinute: Int, durationMinutes: Int, on date: Date) -> String {
        let endMinute = startMinute + max(1, durationMinutes)
        let suffix = endMinute >= ScheduleItem.minutesPerDay ? " +1d" : ""

        return "\(timeText(for: startMinute, on: date)) - \(timeText(for: endMinute, on: date))\(suffix)"
    }

    private func timeText(for minute: Int, on date: Date) -> String {
        let normalizedMinute = ((minute % ScheduleItem.minutesPerDay) + ScheduleItem.minutesPerDay) % ScheduleItem.minutesPerDay
        let hour = normalizedMinute / 60
        let minute = normalizedMinute % 60
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute

        return calendar.date(from: components)?.formatted(.dateTime.hour().minute()) ?? ""
    }

    private var monthGridDays: [Date?] {
        guard let month = calendar.dateInterval(of: .month, for: selectedDate) else {
            return [selectedDate]
        }

        let monthStart = calendar.startOfDay(for: month.start)
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let normalizedLeadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7
        let days = monthDays.map(Optional.some)
        let filledCount = normalizedLeadingBlanks + days.count
        let trailingBlanks = (7 - filledCount % 7) % 7

        return Array(repeating: nil, count: normalizedLeadingBlanks) + days + Array(repeating: nil, count: trailingBlanks)
    }
}
