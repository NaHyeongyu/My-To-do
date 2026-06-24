import Foundation

extension Array where Element == ScheduleItem {
    func routineOccurrenceProjections(
        on date: Date,
        routineStates: [RoutineOccurrenceState],
        calendar: Calendar = .current
    ) -> [RoutineOccurrenceProjection] {
        let dayStart = calendar.startOfDay(for: date)

        return routines(on: dayStart, routineStates: routineStates, calendar: calendar)
            .compactMap { item in
                let state = routineStates.state(for: item, on: dayStart, calendar: calendar)
                return RoutineOccurrenceProjection(
                    item: item,
                    occurrenceDate: dayStart,
                    state: state,
                    calendar: calendar
                )
            }
    }

    func routineOccurrenceProjections(
        displaying date: Date,
        includingPreviousDayCarryovers: Bool = true,
        routineStates: [RoutineOccurrenceState],
        calendar: Calendar = .current
    ) -> [RoutineOccurrenceProjection] {
        let dayStart = calendar.startOfDay(for: date)
        let currentOccurrences = routineOccurrenceProjections(
            on: dayStart,
            routineStates: routineStates,
            calendar: calendar
        )

        guard includingPreviousDayCarryovers,
              let previousDay = calendar.date(byAdding: .day, value: -1, to: dayStart).map(calendar.startOfDay(for:))
        else {
            return currentOccurrences
        }

        let previousCarryovers = routineOccurrenceProjections(
            on: previousDay,
            routineStates: routineStates,
            calendar: calendar
        )
            .filter { $0.overlapsDisplayDay(dayStart, calendar: calendar) }

        return previousCarryovers + currentOccurrences
    }
}

struct RoutineOccurrenceProjection {
    let item: ScheduleItem
    let occurrenceDate: Date
    let state: RoutineOccurrenceState?
    let startMinute: Int
    let durationMinutes: Int

    init?(
        item: ScheduleItem,
        occurrenceDate: Date,
        state: RoutineOccurrenceState?,
        calendar: Calendar
    ) {
        guard let startTime = item.startTime else {
            return nil
        }

        self.item = item
        self.occurrenceDate = occurrenceDate
        self.state = state
        self.startMinute = calendar.minuteOfDay(for: startTime) + (state?.delayMinutes ?? 0)
        self.durationMinutes = max(5, item.plannedDurationMinutes(state: state, calendar: calendar))
    }

    var endMinute: Int {
        startMinute + durationMinutes
    }

    var startsBeforeNextDay: Bool {
        startMinute < ScheduleItem.minutesPerDay
    }

    func startDate(calendar: Calendar) -> Date {
        calendar.date(byAdding: .minute, value: startMinute, to: occurrenceDate) ?? occurrenceDate
    }

    func endDate(calendar: Calendar) -> Date {
        calendar.date(byAdding: .minute, value: endMinute, to: occurrenceDate) ?? occurrenceDate
    }

    func displayStartMinute(on displayDate: Date, calendar: Calendar) -> Int {
        startMinute + displayMinuteOffset(on: displayDate, calendar: calendar)
    }

    func displayEndMinute(on displayDate: Date, calendar: Calendar) -> Int {
        displayStartMinute(on: displayDate, calendar: calendar) + durationMinutes
    }

    func overlapsDisplayDay(_ displayDate: Date, calendar: Calendar) -> Bool {
        let displayStartMinute = displayStartMinute(on: displayDate, calendar: calendar)
        let displayEndMinute = displayStartMinute + durationMinutes

        return displayEndMinute > 0 && displayStartMinute < ScheduleItem.minutesPerDay
    }

    func visibleDisplayWindow(on displayDate: Date, calendar: Calendar) -> RoutineOccurrenceDisplayWindow? {
        let displayStartMinute = displayStartMinute(on: displayDate, calendar: calendar)
        let displayEndMinute = displayStartMinute + durationMinutes
        let visibleStartMinute = max(0, displayStartMinute)
        let visibleEndMinute = min(ScheduleItem.minutesPerDay, displayEndMinute)
        let visibleDurationMinutes = visibleEndMinute - visibleStartMinute

        guard visibleDurationMinutes > 0 else {
            return nil
        }

        return RoutineOccurrenceDisplayWindow(
            startMinute: visibleStartMinute,
            durationMinutes: visibleDurationMinutes
        )
    }

    private func displayMinuteOffset(on displayDate: Date, calendar: Calendar) -> Int {
        let occurrenceDayStart = calendar.startOfDay(for: occurrenceDate)
        let displayDayStart = calendar.startOfDay(for: displayDate)
        let dayOffset = calendar.dateComponents([.day], from: occurrenceDayStart, to: displayDayStart).day ?? 0

        return -dayOffset * ScheduleItem.minutesPerDay
    }
}

struct RoutineOccurrenceDisplayWindow {
    let startMinute: Int
    let durationMinutes: Int
}
