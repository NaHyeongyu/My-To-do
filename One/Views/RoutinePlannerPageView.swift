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
        ForEach(routines) { routine in
            RoutineDayEventBlock(
                weekday: weekday,
                item: routine
            ) {
                onEdit(routine)
            }
            .frame(
                width: max(TimelineLayout.eventMinWidth, width - TimelineLayout.timeColumnWidth - 14),
                height: TimelineLayout.eventHeight(for: routine, calendar: calendar)
            )
            .offset(
                x: TimelineLayout.timeColumnWidth + 12,
                y: TimelineLayout.topContentInset
                    + TimelineLayout.eventTop(for: routine, startHour: startHour, calendar: calendar)
            )
        }
    }
}

private struct RoutineDayEventBlock: View {
    let weekday: RepeatWeekday
    let item: ScheduleItem
    let onEdit: () -> Void

    private var startText: String {
        (item.startTime ?? .now).formatted(.dateTime.hour().minute())
    }

    private var endText: String {
        (item.endTime ?? .now).formatted(.dateTime.hour().minute())
    }

    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MissionTheme.graphite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Text("\(startText) - \(endText)")
                    .font(.caption2.weight(.medium).monospacedDigit())
                    .foregroundStyle(MissionTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(MissionTheme.elevatedPanel, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(MissionTheme.eventIndicator)
                    .frame(width: 3)
                    .padding(.vertical, 7)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.title), \(weekday.title), from \(startText) to \(endText)")
    }
}
