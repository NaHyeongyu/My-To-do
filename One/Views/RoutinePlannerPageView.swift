import SwiftUI

struct RoutinePlannerPageView: View {
    let items: [ScheduleItem]
    let onAdd: (RepeatWeekday) -> Void
    let onEdit: (ScheduleItem) -> Void
    let onDuplicate: (ScheduleItem) -> Void
    let onPause: (ScheduleItem, RepeatWeekday) -> Void
    let onDelete: (ScheduleItem) -> Void

    @State private var selectedWeekday = RepeatWeekday.current()

    private let calendar = Calendar.current
    private let weekdays = RepeatWeekday.allCases
    private let startHour = 0
    private let endHour = 24

    private var routines: [ScheduleItem] {
        items.routines(repeating: selectedWeekday, calendar: calendar)
    }

    var body: some View {
        VStack(spacing: 0) {
            RoutineWeekdaySelector(
                weekdays: weekdays,
                selectedWeekday: $selectedWeekday
            )

            ScrollView {
                if routines.isEmpty {
                    RoutineEmptyDayView(weekday: selectedWeekday) {
                        onAdd(selectedWeekday)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 22)
                    .padding(.bottom, 82)
                } else {
                    RoutineDayTimeline(
                        weekday: selectedWeekday,
                        routines: routines,
                        startHour: startHour,
                        endHour: endHour,
                        onEdit: onEdit,
                        onDuplicate: onDuplicate,
                        onPause: { routine in
                            onPause(routine, selectedWeekday)
                        },
                        onDelete: onDelete
                    )
                    .padding(.bottom, 82)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MissionTheme.panel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(MissionTheme.panel)
        .gesture(weekdaySwipeGesture)
        .sensoryFeedback(.selection, trigger: selectedWeekday)
    }

    private var weekdaySwipeGesture: some Gesture {
        DragGesture(minimumDistance: 28)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height),
                      abs(value.translation.width) > 34 else {
                    return
                }

                moveWeekday(by: value.translation.width < 0 ? 1 : -1)
            }
    }

    private func moveWeekday(by offset: Int) {
        guard let currentIndex = weekdays.firstIndex(of: selectedWeekday) else {
            return
        }

        let nextIndex = (currentIndex + offset + weekdays.count) % weekdays.count
        withAnimation(.snappy(duration: 0.2)) {
            selectedWeekday = weekdays[nextIndex]
        }
    }
}

private struct RoutineWeekdaySelector: View {
    let weekdays: [RepeatWeekday]
    @Binding var selectedWeekday: RepeatWeekday

    var body: some View {
        HStack(spacing: 4) {
            ForEach(weekdays) { weekday in
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        selectedWeekday = weekday
                    }
                } label: {
                    Text(weekday.shortTitle)
                        .font(.caption.weight(weekday == selectedWeekday ? .semibold : .regular))
                        .foregroundStyle(weekday == selectedWeekday ? MissionTheme.graphite : MissionTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background {
                            if weekday == selectedWeekday {
                                Capsule()
                                    .fill(MissionTheme.controlFill)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(weekday.title)
                .accessibilityAddTraits(weekday == selectedWeekday ? .isSelected : [])
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(MissionTheme.panel)
        .overlay(alignment: .bottom) {
            TimelineDivider(color: MissionTheme.separator, opacity: 0.42)
        }
    }
}

private struct RoutineDayTimeline: View {
    let weekday: RepeatWeekday
    let routines: [ScheduleItem]
    let startHour: Int
    let endHour: Int
    let onEdit: (ScheduleItem) -> Void
    let onDuplicate: (ScheduleItem) -> Void
    let onPause: (ScheduleItem) -> Void
    let onDelete: (ScheduleItem) -> Void

    private let calendar = Calendar.current

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                hourLines(width: proxy.size.width)
                eventBlocks(width: proxy.size.width)
            }
        }
        .frame(height: TimelineLayout.contentHeight(startHour: startHour, endHour: endHour))
        .background(MissionTheme.panel)
    }

    @ViewBuilder
    private func hourLines(width: CGFloat) -> some View {
        TimelineHourLines(
            startHour: startHour,
            endHour: endHour,
            width: width,
            labelColor: MissionTheme.secondaryText,
            separatorColor: MissionTheme.separator,
            separatorOpacity: 0.34
        )
    }

    @ViewBuilder
    private func eventBlocks(width: CGFloat) -> some View {
        ForEach(eventLayouts(width: width)) { layout in
            RoutineDayEventBlock(
                weekday: weekday,
                item: layout.item,
                isCompact: layout.isCompact
            ) {
                onEdit(layout.item)
            } onDuplicate: {
                onDuplicate(layout.item)
            } onPause: {
                onPause(layout.item)
            } onDelete: {
                onDelete(layout.item)
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
    }

    private func eventLayouts(width: CGFloat) -> [TimelineEventLayout] {
        TimelineLayout.eventLayouts(
            for: routines,
            in: width,
            startHour: startHour,
            calendar: calendar
        )
    }
}

private struct RoutineDayEventBlock: View {
    let weekday: RepeatWeekday
    let item: ScheduleItem
    let isCompact: Bool
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onPause: () -> Void
    let onDelete: () -> Void

    private var timeRangeText: String {
        item.timeRangeText()
    }

    var body: some View {
        Button(action: onEdit) {
            ViewThatFits(in: .vertical) {
                fullContent
                compactContent
            }
            .padding(.vertical, isCompact ? 5 : 7)
            .padding(.horizontal, isCompact ? 7 : 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(MissionTheme.eventBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(MissionTheme.eventIndicator)
                    .frame(width: 3)
                    .padding(.vertical, 7)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }

            Button(action: onDuplicate) {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }

            Button(action: onPause) {
                Label("Pause \(weekday.shortTitle)", systemImage: "pause.circle")
            }

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityLabel("\(item.title), \(weekday.title), \(timeRangeText)")
    }

    private var fullContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            titleText

            timeText
        }
    }

    private var compactContent: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                titleText
                timeText
                    .fixedSize(horizontal: true, vertical: false)
            }

            titleText
        }
    }

    private var titleText: some View {
        Text(item.title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(MissionTheme.eventForeground)
            .lineLimit(1)
            .minimumScaleFactor(0.64)
    }

    private var timeText: some View {
        Text(timeRangeText)
            .font(.caption2.weight(.medium).monospacedDigit())
            .foregroundStyle(MissionTheme.eventSecondaryForeground)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .allowsTightening(true)
    }
}

private struct RoutineEmptyDayView: View {
    let weekday: RepeatWeekday
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(MissionTheme.accent)

                Text("Add routine for \(weekday.title)")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(MissionTheme.graphite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text("Build this day directly from the routine timeline.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(MissionTheme.secondaryText)
                    .lineLimit(2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .missionCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add routine for \(weekday.title)")
    }
}
