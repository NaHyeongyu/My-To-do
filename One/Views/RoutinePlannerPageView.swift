import SwiftUI

struct RoutinePlannerPageView: View {
    let items: [ScheduleItem]
    let onEdit: (ScheduleItem) -> Void

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
                RoutineDayTimeline(
                    weekday: selectedWeekday,
                    routines: routines,
                    startHour: startHour,
                    endHour: endHour,
                    onEdit: onEdit
                )
                .padding(.bottom, 82)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MissionTheme.panel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(MissionTheme.panel)
        .sensoryFeedback(.selection, trigger: selectedWeekday)
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
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(MissionTheme.accent.opacity(0.48), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
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
