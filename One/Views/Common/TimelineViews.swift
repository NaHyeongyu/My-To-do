import SwiftUI

enum TimelineLayout {
    static let hourHeight: CGFloat = 62
    static let timeColumnWidth: CGFloat = 54
    static let topContentInset: CGFloat = 22
    static let eventMinWidth: CGFloat = 120
    static let eventMinHeight: CGFloat = 42

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
        max(eventMinHeight, CGFloat(max(30, item.durationMinutes(calendar: calendar))) / 60 * hourHeight - 6)
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
