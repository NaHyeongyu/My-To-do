import SwiftUI

private struct CalendarPageTurnEffect<Value: Equatable>: ViewModifier {
    let value: Value
    let direction: Int

    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .opacity(opacity)
            .onChange(of: value) { _, _ in
                offset = direction >= 0 ? 28 : -28
                opacity = 0.86

                DispatchQueue.main.async {
                    withAnimation(.snappy(duration: 0.24)) {
                        offset = 0
                        opacity = 1
                    }
                }
            }
    }
}

extension View {
    func calendarPageTurn<Value: Equatable>(for value: Value, direction: Int) -> some View {
        modifier(CalendarPageTurnEffect(value: value, direction: direction))
    }
}

enum CalendarSwipeScope {
    case day
    case week
    case month

    var component: Calendar.Component {
        switch self {
        case .day, .week:
            .day
        case .month:
            .month
        }
    }

    var step: Int {
        switch self {
        case .day, .month:
            1
        case .week:
            7
        }
    }

    var minimumDistance: CGFloat {
        switch self {
        case .day:
            46
        case .week, .month:
            12
        }
    }
}

enum TimetableViewMode: String, CaseIterable, Identifiable {
    case day
    case month

    static let defaultsKey = "timetableViewMode"

    var id: String { rawValue }

    static func storedValue() -> TimetableViewMode {
        guard
            let rawValue = UserDefaults.standard.string(forKey: defaultsKey),
            let mode = TimetableViewMode(rawValue: rawValue)
        else {
            return .day
        }

        return mode
    }

    var title: String {
        switch self {
        case .day: "Day"
        case .month: "Month"
        }
    }

    var systemImage: String {
        switch self {
        case .day: "calendar.day.timeline.left"
        case .month: "calendar"
        }
    }
}
