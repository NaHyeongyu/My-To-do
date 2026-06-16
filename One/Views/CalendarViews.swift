import SwiftUI

struct CalendarControlHeader: View {
    let selectedDate: Date
    let viewMode: TimetableViewMode
    let onSetViewMode: (TimetableViewMode) -> Void

    private var monthTitle: String {
        selectedDate.formatted(.dateTime.locale(.enUS).month(.wide).year())
    }

    var body: some View {
        ZStack {
            Text(monthTitle)
                .font(.title2.weight(.bold))
                .foregroundStyle(MissionTheme.graphite)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 64)

            HStack {
                Spacer()

                Menu {
                    ForEach(TimetableViewMode.allCases) { mode in
                        Button {
                            onSetViewMode(mode)
                        } label: {
                            Label(mode.title, systemImage: mode == viewMode ? "checkmark" : mode.systemImage)
                        }
                    }
                } label: {
                    Image(systemName: viewMode.systemImage)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(MissionTheme.accent)
                        .frame(width: 38, height: 38)
                }
                .missionLiquidButton()
                .buttonBorderShape(.circle)
                .controlSize(.regular)
                .accessibilityLabel("Change calendar view")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(MissionTheme.panel)
        .overlay(alignment: .bottom) {
            TimelineDivider(color: MissionTheme.separator, opacity: 0.52)
        }
    }
}

struct CalendarDayStrip: View {
    let days: [Date]
    @Binding var selectedDate: Date

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { date in
                    Button {
                        withAnimation(.snappy(duration: 0.18)) {
                            selectedDate = calendar.startOfDay(for: date)
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(date.formatted(.dateTime.locale(.enUS).weekday(.narrow)))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(calendar.isDateInToday(date) ? MissionTheme.accent : MissionTheme.secondaryText)
                                .lineLimit(1)

                            Text("\(calendar.component(.day, from: date))")
                                .font(.callout.weight(.semibold).monospacedDigit())
                                .foregroundStyle(isSelected(date) ? MissionTheme.selectedText : dayColor(for: date))
                                .frame(width: 30, height: 30)
                                .background {
                                    Circle()
                                        .fill(isSelected(date) ? MissionTheme.selection : Color.clear)
                                }
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(date.formatted(.dateTime.locale(.enUS).weekday(.wide).month().day()))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)
        }
        .background(MissionTheme.panel)
        .overlay(alignment: .bottom) {
            TimelineDivider(color: MissionTheme.separator, opacity: 0.72)
        }
    }

    private func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private func dayColor(for date: Date) -> Color {
        calendar.isDateInToday(date) ? MissionTheme.accent : MissionTheme.graphite
    }
}

struct CalendarDayView: View {
    let date: Date
    let routines: [ScheduleItem]
    let routineStates: [RoutineOccurrenceState]
    let startHour: Int
    let endHour: Int
    let onEdit: (ScheduleItem) -> Void

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                    ZStack(alignment: .topLeading) {
                        TimelineHourLines(
                            startHour: startHour,
                            endHour: endHour,
                            width: proxy.size.width,
                            labelColor: MissionTheme.secondaryText,
                            separatorColor: MissionTheme.separator,
                            separatorOpacity: 0.38,
                            addsScrollTargets: true
                        )

                        ForEach(eventLayouts(width: proxy.size.width)) { layout in
                            CalendarEventBlock(
                                item: layout.item,
                                occurrenceState: routineStates.state(for: layout.item, on: date, calendar: calendar),
                                isCompact: layout.isCompact
                            ) {
                                onEdit(layout.item)
                            }
                            .frame(
                                width: layout.width,
                                height: layout.height
                            )
                            .offset(
                                x: layout.x,
                                y: layout.top
                            )
                        }

                        if let currentTimeTop = currentTimeTop(for: timeline.date) {
                            CalendarCurrentTimeIndicator(
                                now: timeline.date
                            )
                            .offset(y: TimelineLayout.topContentInset + currentTimeTop - CalendarCurrentTimeIndicator.verticalCenterOffset)
                            .id(CalendarLayout.currentTimeID)
                        }
                    }
                }
            }
            .frame(height: TimelineLayout.contentHeight(startHour: startHour, endHour: endHour))
        }
        .background(MissionTheme.panel)
    }

    private func currentTimeTop(for now: Date) -> CGFloat? {
        guard calendar.isDate(now, inSameDayAs: date) else {
            return nil
        }

        return TimelineLayout.currentTimeTop(now: now, startHour: startHour, endHour: endHour, calendar: calendar)
    }

    private func eventLayouts(width: CGFloat) -> [TimelineEventLayout] {
        TimelineLayout.eventLayouts(
            for: routines,
            in: width,
            startHour: startHour,
            calendar: calendar,
            fallbackDate: date
        ) { routine in
            routineStates.state(for: routine, on: date, calendar: calendar)?.delayMinutes ?? 0
        }
    }
}

private struct CalendarCurrentTimeIndicator: View {
    static let verticalCenterOffset: CGFloat = 11
    private static let leadingPadding: CGFloat = 12

    let now: Date

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(now.formatted(.dateTime.hour().minute()))
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(MissionTheme.selectedText)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(MissionTheme.accent, in: Capsule(style: .continuous))

            Circle()
                .fill(MissionTheme.accent)
                .frame(width: 7, height: 7)

            Rectangle()
                .fill(MissionTheme.accent.opacity(0.72))
                .frame(height: 1)
        }
        .padding(.leading, Self.leadingPadding)
        .frame(height: Self.verticalCenterOffset * 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CalendarMonthView: View {
    let selectedDate: Date
    let monthDays: [Date?]
    let items: [ScheduleItem]
    let onSelectDate: (Date) -> Void

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let startIndex = max(0, calendar.firstWeekday - 1)
        return Array(symbols[startIndex...]) + Array(symbols[..<startIndex])
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(weekdaySymbols.indices, id: \.self) { index in
                    Text(weekdaySymbols[index])
                        .font(.caption.weight(.medium))
                        .foregroundStyle(MissionTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(MissionTheme.panel)
            .overlay(alignment: .bottom) {
                TimelineDivider(color: MissionTheme.separator, opacity: 0.42)
            }

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        CalendarMonthDayCell(
                            date: date,
                            routines: items.routines(on: date, calendar: calendar),
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date)
                        ) {
                            onSelectDate(date)
                        }
                    } else {
                        CalendarMonthBlankCell()
                    }
                }
            }
        }
        .background(MissionTheme.panel)
    }
}

private struct CalendarMonthDayCell: View {
    let date: Date
    let routines: [ScheduleItem]
    let isSelected: Bool
    let isToday: Bool
    let onSelect: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                dayBadge

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(routines.prefix(3))) { routine in
                        MonthEventPreview(item: routine)
                    }

                    if routines.count > 3 {
                        Text("+\(routines.count - 3) more")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(MissionTheme.tertiaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            }
            .padding(.top, 10)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: CalendarMonthLayout.cellHeight)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                TimelineDivider(color: MissionTheme.separator, opacity: 0.28)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var dayBadge: some View {
        Text("\(calendar.component(.day, from: date))")
            .font(.callout.weight(isSelected ? .semibold : .regular).monospacedDigit())
            .foregroundStyle(dayTextColor)
            .frame(width: 32, height: 32)
            .background {
                if isSelected {
                    Circle()
                        .fill(MissionTheme.selection)
                } else if isToday {
                    Circle()
                        .stroke(MissionTheme.selection.opacity(0.72), lineWidth: 1)
                }
            }
    }

    private var dayTextColor: Color {
        if isSelected {
            return MissionTheme.selectedText
        }

        return isToday ? MissionTheme.accent : MissionTheme.graphite
    }
}

private struct CalendarMonthBlankCell: View {
    var body: some View {
        MissionTheme.panel
            .frame(height: CalendarMonthLayout.cellHeight)
            .overlay(alignment: .bottom) {
                TimelineDivider(color: MissionTheme.separator, opacity: 0.28)
            }
    }
}

private struct MonthEventPreview: View {
    let item: ScheduleItem

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(MissionTheme.eventIndicator)
                .frame(width: 6, height: 6)

            Text(item.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(MissionTheme.graphite)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum CalendarMonthLayout {
    static let cellHeight: CGFloat = 112
}

private struct CalendarEventBlock: View {
    let item: ScheduleItem
    let occurrenceState: RoutineOccurrenceState?
    let isCompact: Bool
    let onEdit: () -> Void

    private var timeRangeText: String {
        item.timeRangeText()
    }

    private var status: RoutineOccurrenceStatus {
        occurrenceState?.status ?? .pending
    }

    var body: some View {
        Button(action: onEdit) {
            ViewThatFits(in: .vertical) {
                fullContent
                compactContent
            }
            .padding(.vertical, isCompact ? 5 : 7)
            .padding(.leading, status.isResolved ? 12 : (isCompact ? 7 : 9))
            .padding(.trailing, showsStatusBadge ? 24 : (isCompact ? 7 : 9))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(eventBackground, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(statusTint.opacity(status.isResolved ? 0.92 : 0.58))
                    .frame(width: 3)
                    .padding(.vertical, 7)
            }
            .overlay(alignment: .topTrailing) {
                if showsStatusBadge {
                    statusBadge
                        .padding(.top, 5)
                        .padding(.trailing, 6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.title), \(status.title), \(timeRangeText)")
    }

    private var fullContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            titleRow

            timeText
        }
    }

    private var compactContent: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                compactTitle
                timeText
                    .fixedSize(horizontal: true, vertical: false)
            }

            titleRow
        }
    }

    private var titleRow: some View {
        compactTitle
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var compactTitle: some View {
        Text(item.title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(eventForeground)
            .lineLimit(1)
            .minimumScaleFactor(0.56)
            .allowsTightening(true)
            .layoutPriority(1)
    }

    private var timeText: some View {
        Text(timeRangeText)
            .font(.caption2.weight(.medium).monospacedDigit())
            .foregroundStyle(MissionTheme.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.64)
            .allowsTightening(true)
    }

    private var showsStatusBadge: Bool {
        status.isResolved && !isCompact
    }

    private var statusBadge: some View {
        Image(systemName: status == .done ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(statusTint)
            .frame(width: 16, height: 16)
            .background(MissionTheme.panel.opacity(0.82), in: Circle())
    }

    private var eventBackground: Color {
        switch status {
        case .pending:
            MissionTheme.eventBackground
        case .done:
            MissionTheme.success.opacity(0.18)
        case .skipped:
            MissionTheme.danger.opacity(0.18)
        }
    }

    private var eventForeground: Color {
        switch status {
        case .pending:
            MissionTheme.eventForeground
        case .done, .skipped:
            MissionTheme.graphite
        }
    }

    private var statusTint: Color {
        switch status {
        case .pending:
            MissionTheme.secondaryText
        case .done:
            MissionTheme.success
        case .skipped:
            MissionTheme.danger
        }
    }
}
