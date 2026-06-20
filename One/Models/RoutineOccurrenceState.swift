import Foundation
import SwiftData

enum RoutineOccurrenceStatus: String, CaseIterable {
    case pending
    case done
    case skipped

    var title: String {
        switch self {
        case .pending: "Open"
        case .done: "Done"
        case .skipped: "Failed"
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

enum RoutineFailReason: String, CaseIterable, Identifiable, Hashable {
    case noTime
    case lowEnergy
    case distracted
    case rescheduled
    case notImportant

    var id: String { rawValue }

    var title: String {
        switch self {
        case .noTime: "No time"
        case .lowEnergy: "Low energy"
        case .distracted: "Distracted"
        case .rescheduled: "Rescheduled"
        case .notImportant: "Not important"
        }
    }

    var symbolName: String {
        switch self {
        case .noTime: "clock"
        case .lowEnergy: "battery.25"
        case .distracted: "eye.slash"
        case .rescheduled: "arrow.clockwise"
        case .notImportant: "minus.circle"
        }
    }
}

@Model
final class RoutineOccurrenceState: Identifiable {
    var id: UUID = UUID()
    var routineID: UUID = UUID()
    var dayStart: Date = Date()
    var statusRawValue: String = RoutineOccurrenceStatus.pending.rawValue
    var failReasonRawValue: String?
    var delayMinutes: Int = 0
    var routineVersionID: String?
    var isHidden: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        routineID: UUID,
        dayStart: Date,
        status: RoutineOccurrenceStatus = .pending,
        failReason: RoutineFailReason? = nil,
        delayMinutes: Int = 0,
        routineVersionID: String? = nil,
        isHidden: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.routineID = routineID
        self.dayStart = dayStart
        self.statusRawValue = status.rawValue
        self.failReasonRawValue = status == .skipped ? failReason?.rawValue : nil
        self.delayMinutes = delayMinutes
        self.routineVersionID = routineVersionID
        self.isHidden = isHidden
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension RoutineOccurrenceState {
    var status: RoutineOccurrenceStatus {
        get { RoutineOccurrenceStatus(rawValue: statusRawValue) ?? .pending }
        set {
            statusRawValue = newValue.rawValue
            if newValue != .skipped {
                failReasonRawValue = nil
            }
            updatedAt = .now
        }
    }

    var failReason: RoutineFailReason? {
        get {
            guard let failReasonRawValue else {
                return nil
            }

            return RoutineFailReason(rawValue: failReasonRawValue)
        }
        set {
            failReasonRawValue = newValue?.rawValue
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
