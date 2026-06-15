import SwiftUI

enum TimelineLayout {
    static let hourHeight: CGFloat = 62
    static let timeColumnWidth: CGFloat = 54
    static let topContentInset: CGFloat = 22
    static let eventMinWidth: CGFloat = 120
    static let eventMinimumVisibleHeight: CGFloat = 1
    static let eventLeadingInset: CGFloat = timeColumnWidth + 12
    static let eventTrailingInset: CGFloat = 12
    static let eventColumnSpacing: CGFloat = 4
    static let eventVerticalGap: CGFloat = 6

    static func contentHeight(startHour: Int, endHour: Int) -> CGFloat {
        topContentInset + CGFloat(endHour - startHour) * hourHeight
    }

    static func eventTop(
        for item: ScheduleItem,
        startHour: Int,
        calendar: Calendar,
        fallbackDate: Date = .now
    ) -> CGFloat {
        let startMinute = calendar.minuteOfDay(for: item.startTime ?? fallbackDate)
        return CGFloat(max(0, startMinute - startHour * 60)) / 60 * hourHeight + 3
    }

    static func eventHeight(for item: ScheduleItem, calendar: Calendar) -> CGFloat {
        let startMinute = calendar.minuteOfDay(for: item.startTime ?? .now)
        let visibleMinutes = min(
            item.durationMinutes(calendar: calendar),
            max(0, ScheduleItem.minutesPerDay - startMinute)
        )

        return max(eventMinimumVisibleHeight, CGFloat(max(1, visibleMinutes)) / 60 * hourHeight - eventVerticalGap)
    }

    static func eventLayouts(
        for items: [ScheduleItem],
        in width: CGFloat,
        startHour: Int,
        calendar: Calendar,
        fallbackDate: Date = .now,
        delayMinutes: (ScheduleItem) -> Int = { _ in 0 }
    ) -> [TimelineEventLayout] {
        let rawEvents = items.compactMap { item -> RawTimelineEvent? in
            let startMinute = calendar.minuteOfDay(for: item.startTime ?? fallbackDate) + delayMinutes(item)
            guard startMinute < ScheduleItem.minutesPerDay, startMinute < startHour * 60 + ScheduleItem.minutesPerDay else {
                return nil
            }

            let durationMinutes = item.durationMinutes(calendar: calendar)
            let endMinute = min(ScheduleItem.minutesPerDay, startMinute + max(1, durationMinutes))
            let top = topContentInset
                + CGFloat(max(0, startMinute - startHour * 60)) / 60 * hourHeight
                + 3
            let height = eventHeight(startMinute: startMinute, durationMinutes: durationMinutes)
            return RawTimelineEvent(
                item: item,
                startMinute: startMinute,
                endMinute: endMinute,
                top: top,
                height: height
            )
        }
        .sorted {
            if $0.startMinute != $1.startMinute {
                return $0.startMinute < $1.startMinute
            }

            return $0.endMinute > $1.endMinute
        }

        let groups = grouped(rawEvents)
        let availableWidth = max(44, width - eventLeadingInset - eventTrailingInset)

        return groups.flatMap { group in
            columned(group, availableWidth: availableWidth)
        }
    }

    private static func eventHeight(startMinute: Int, durationMinutes: Int) -> CGFloat {
        let visibleMinutes = min(
            durationMinutes,
            max(0, ScheduleItem.minutesPerDay - startMinute)
        )

        return max(eventMinimumVisibleHeight, CGFloat(max(1, visibleMinutes)) / 60 * hourHeight - eventVerticalGap)
    }

    private static func grouped(_ events: [RawTimelineEvent]) -> [[RawTimelineEvent]] {
        var groups: [[RawTimelineEvent]] = []
        var currentGroup: [RawTimelineEvent] = []
        var currentEndMinute = 0

        for event in events {
            if currentGroup.isEmpty || event.startMinute < currentEndMinute {
                currentGroup.append(event)
                currentEndMinute = max(currentEndMinute, event.endMinute)
            } else {
                groups.append(currentGroup)
                currentGroup = [event]
                currentEndMinute = event.endMinute
            }
        }

        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }

        return groups
    }

    private static func columned(_ group: [RawTimelineEvent], availableWidth: CGFloat) -> [TimelineEventLayout] {
        var active: [(column: Int, endMinute: Int)] = []
        var assigned: [(event: RawTimelineEvent, column: Int)] = []
        var maxColumn = 0

        for event in group {
            active.removeAll { $0.endMinute <= event.startMinute }

            let occupiedColumns = Set(active.map(\.column))
            let column = (0...group.count).first { !occupiedColumns.contains($0) } ?? 0
            active.append((column: column, endMinute: event.endMinute))
            maxColumn = max(maxColumn, column)
            assigned.append((event: event, column: column))
        }

        let columnCount = maxColumn + 1
        let totalSpacing = eventColumnSpacing * CGFloat(max(0, columnCount - 1))
        let columnWidth = max(44, (availableWidth - totalSpacing) / CGFloat(columnCount))

        return assigned.map { assignment in
            let x = eventLeadingInset + CGFloat(assignment.column) * (columnWidth + eventColumnSpacing)
            return TimelineEventLayout(
                item: assignment.event.item,
                top: assignment.event.top,
                width: columnWidth,
                height: assignment.event.height,
                x: x
            )
        }
    }

    static func currentTimeTop(now: Date, startHour: Int, endHour: Int, calendar: Calendar) -> CGFloat? {
        let currentMinute = calendar.minuteOfDay(for: now)
        let startMinute = startHour * 60
        let endMinute = endHour * 60

        guard currentMinute >= startMinute, currentMinute <= endMinute else {
            return nil
        }

        return CGFloat(currentMinute - startMinute) / 60 * hourHeight
    }
}

struct TimelineEventLayout: Identifiable {
    let item: ScheduleItem
    let top: CGFloat
    let width: CGFloat
    let height: CGFloat
    let x: CGFloat

    var id: UUID {
        item.id
    }

    var isCompact: Bool {
        height < 62 || width < 136
    }
}

private struct RawTimelineEvent {
    let item: ScheduleItem
    let startMinute: Int
    let endMinute: Int
    let top: CGFloat
    let height: CGFloat
}

struct TimelineHourLines: View {
    let startHour: Int
    let endHour: Int
    let width: CGFloat?
    let labelColor: Color
    let separatorColor: Color
    let separatorOpacity: Double
    let addsScrollTargets: Bool

    init(
        startHour: Int,
        endHour: Int,
        width: CGFloat? = nil,
        labelColor: Color,
        separatorColor: Color,
        separatorOpacity: Double,
        addsScrollTargets: Bool = false
    ) {
        self.startHour = startHour
        self.endHour = endHour
        self.width = width
        self.labelColor = labelColor
        self.separatorColor = separatorColor
        self.separatorOpacity = separatorOpacity
        self.addsScrollTargets = addsScrollTargets
    }

    var body: some View {
        ForEach(startHour...endHour, id: \.self) { hour in
            line(for: hour)
        }
    }

    @ViewBuilder
    private func line(for hour: Int) -> some View {
        let row = HStack(alignment: .top, spacing: 10) {
            Text(CalendarLayout.hourTitle(hour))
                .font(.caption2.weight(.regular).monospacedDigit())
                .foregroundStyle(labelColor)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(width: TimelineLayout.timeColumnWidth, alignment: .trailing)
                .offset(y: -7)

            Rectangle()
                .fill(separatorColor.opacity(separatorOpacity))
                .frame(height: 0.5)
                .frame(maxWidth: .infinity)
        }
        .frame(width: width)
        .offset(y: TimelineLayout.topContentInset + CGFloat(hour - startHour) * TimelineLayout.hourHeight)

        if addsScrollTargets {
            row.id(CalendarLayout.hourID(hour))
        } else {
            row
        }
    }
}

struct TimelineDivider: View {
    let color: Color
    let opacity: Double

    var body: some View {
        Rectangle()
            .fill(color.opacity(opacity))
            .frame(height: 0.5)
    }
}

enum CalendarLayout {
    static let currentTimeID = "calendar-current-time"

    static func hourID(_ hour: Int) -> String {
        "calendar-hour-\(hour)"
    }

    static func hourTitle(_ hour: Int) -> String {
        let normalizedHour = hour % 24
        let displayHour = normalizedHour % 12 == 0 ? 12 : normalizedHour % 12
        let suffix = normalizedHour < 12 ? "AM" : "PM"
        return "\(displayHour) \(suffix)"
    }
}
