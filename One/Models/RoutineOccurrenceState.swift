import Foundation
import SwiftData

enum RoutineOccurrenceStatus: String, CaseIterable {
    case pending
    case done
    case skipped

    var title: String {
        switch self {
        case .pending: "Pending"
        case .done: "Done"
        case .skipped: "Skipped"
        }
    }

    var isResolved: Bool {
        switch self {
        case .pending:
            false
        case .done, .skipped:
            true
        }
    }
}

@Model
final class RoutineOccurrenceState: Identifiable {
    var id: UUID
    var routineID: UUID
    var dayStart: Date
    var statusRawValue: String
    var delayMinutes: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        routineID: UUID,
        dayStart: Date,
        status: RoutineOccurrenceStatus = .pending,
        delayMinutes: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.routineID = routineID
        self.dayStart = dayStart
        self.statusRawValue = status.rawValue
        self.delayMinutes = delayMinutes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension RoutineOccurrenceState {
    var status: RoutineOccurrenceStatus {
        get { RoutineOccurrenceStatus(rawValue: statusRawValue) ?? .pending }
        set {
            statusRawValue = newValue.rawValue
            updatedAt = .now
        }
    }

    var isResolved: Bool {
        status.isResolved
    }
}

extension Array where Element == RoutineOccurrenceState {
    func state(for routine: ScheduleItem, on date: Date, calendar: Calendar = .current) -> RoutineOccurrenceState? {
        let dayStart = calendar.startOfDay(for: date)
        return first {
            $0.routineID == routine.id && calendar.isDate($0.dayStart, inSameDayAs: dayStart)
        }
    }
}
