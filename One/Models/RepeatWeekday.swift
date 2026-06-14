import Foundation

enum RepeatWeekday: Int, CaseIterable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .sunday: "Sunday"
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        }
    }

    var shortTitle: String {
        switch self {
        case .sunday: "Sun"
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        case .saturday: "Sat"
        }
    }

    var compactTitle: String {
        switch self {
        case .sunday: "Su"
        case .monday: "Mo"
        case .tuesday: "Tu"
        case .wednesday: "We"
        case .thursday: "Th"
        case .friday: "Fr"
        case .saturday: "Sa"
        }
    }

    var bit: Int {
        1 << rawValue
    }

    static func current(calendar: Calendar = .current, date: Date = .now) -> RepeatWeekday {
        let weekdayNumber = calendar.component(.weekday, from: date)
        return RepeatWeekday(rawValue: weekdayNumber) ?? .monday
    }
}

enum RepeatWeekdayMask {
    static let weekdays = RepeatWeekday.allCases
        .filter { $0 != .sunday && $0 != .saturday }
        .reduce(0) { $0 | $1.bit }

    static let weekends = RepeatWeekday.allCases
        .filter { $0 == .sunday || $0 == .saturday }
        .reduce(0) { $0 | $1.bit }

    static let everyDay = RepeatWeekday.allCases.reduce(0) { $0 | $1.bit }

    static func contains(_ weekday: RepeatWeekday, in mask: Int) -> Bool {
        mask & weekday.bit != 0
    }

    static func toggled(_ weekday: RepeatWeekday, in mask: Int) -> Int {
        contains(weekday, in: mask) ? mask & ~weekday.bit : mask | weekday.bit
    }

    static func summary(for mask: Int) -> String {
        switch mask {
        case everyDay:
            "Every day"
        case weekdays:
            "Weekdays"
        case weekends:
            "Weekends"
        case 0:
            "No repeat days"
        default:
            RepeatWeekday.allCases
                .filter { contains($0, in: mask) }
                .map(\.shortTitle)
                .joined(separator: ", ")
        }
    }
}
