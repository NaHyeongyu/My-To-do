import SwiftUI

struct TimetablePageView: View {
    let items: [ScheduleItem]
    let routineStates: [RoutineOccurrenceState]
    let onAddRoutine: (Date) -> Void
    let onEdit: (ScheduleItem) -> Void
    let onMarkRoutineDone: (ScheduleItem, Date) -> Void
    let onSkipRoutine: (ScheduleItem, Date) -> Void

    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var viewMode: TimetableViewMode = TimetableViewMode.storedValue()
    @State private var calendarTurnDirection = 1

    private let calendar = Calendar.current

    private var routines: [ScheduleItem] {
        items.routines(on: selectedDate, calendar: calendar)
    }

    private var initialTimelineHour: Int {
        let currentHour = calendar.component(.hour, from: .now)
        let firstRoutineHour = routines
            .compactMap(\.startTime)
            .map { calendar.minuteOfDay(for: $0) / 60 }
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
        let states = routines.compactMap { routineStates.state(for: $0, on: selectedDate, calendar: calendar) }
        let doneCount = states.filter { $0.status == .done }.count
        let skippedCount = states.filter { $0.status == .skipped }.count
        return RoutineDayProgress(total: routines.count, done: doneCount, skipped: skippedCount)
    }

    private var missionSummary: CalendarMissionSummary {
        let plannedMinutes = routines.reduce(0) { $0 + $1.durationMinutes(calendar: calendar) }
        let completedMinutes = routines.reduce(0) { total, routine in
            let state = routineStates.state(for: routine, on: selectedDate, calendar: calendar)
            return state?.status == .done ? total + routine.durationMinutes(calendar: calendar) : total
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

                switch viewMode {
                case .day:
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
                                onDone: {
                                    onMarkRoutineDone($0, selectedDayStart)
                                },
                                onSkip: {
                                    onSkipRoutine($0, selectedDayStart)
                                }
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 12)
                        .background(MissionTheme.panel)
                    }

                    ScrollView {
                        CalendarDayView(
                            date: selectedDate,
                            routines: routines,
                            routineStates: routineStates,
                            startHour: dayStartHour,
                            endHour: dayEndHour,
                            onEdit: onEdit
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
                case .month:
                    ScrollView {
                        CalendarMonthView(
                            selectedDate: selectedDate,
                            monthDays: monthGridDays,
                            items: items,
                            onSelectDate: {
                                setSelectedDate($0)
                                setViewMode(.day)
                            }
                        )
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            swipeGesture(for: .month)
                        )
                        .padding(.bottom, scrollContentBottomPadding)
                    }
                    .background(MissionTheme.panel)
                }
            }
            .background(MissionTheme.panel)
            .onAppear {
                scrollToInitialTimelinePosition(proxy)
            }
            .onChange(of: selectedDate) { _, _ in
                scrollToInitialTimelinePosition(proxy)
            }
            .onChange(of: viewMode) { _, _ in
                scrollToInitialTimelinePosition(proxy)
            }
        }
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

    private func scrollToInitialTimelinePosition(_ proxy: ScrollViewProxy) {
        guard viewMode != .month else {
            return
        }

        let showsCurrentTime = calendar.isDateInToday(selectedDate)
        let targetID = showsCurrentTime ? CalendarLayout.currentTimeID : CalendarLayout.hourID(initialTimelineHour)
        let anchor: UnitPoint = showsCurrentTime ? .center : .top

        DispatchQueue.main.async {
            withAnimation(.snappy(duration: 0.18)) {
                proxy.scrollTo(targetID, anchor: anchor)
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
        viewMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: TimetableViewMode.defaultsKey)
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
        let candidates = routines.map { routine in
            candidate(for: routine, currentMinute: currentMinute)
        }
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

    private func candidate(for routine: ScheduleItem, currentMinute: Int) -> RoutineNowCandidate {
        let state = routineStates.state(for: routine, on: selectedDate, calendar: calendar)
        let delayMinutes = state?.delayMinutes ?? 0
        let baseStartMinute = calendar.minuteOfDay(for: routine.startTime ?? selectedDate)
        let duration = max(5, routine.durationMinutes(calendar: calendar))
        let startMinute = baseStartMinute + delayMinutes
        let endMinute = startMinute + duration
        let phase: RoutineNowPhase = endMinute <= currentMinute ? .missed : .next

        return RoutineNowCandidate(
            item: routine,
            phase: phase,
            status: state?.status ?? .pending,
            startMinute: startMinute,
            endMinute: endMinute,
            delayMinutes: delayMinutes,
            calendar: calendar,
            dayStart: selectedDayStart
        )
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
