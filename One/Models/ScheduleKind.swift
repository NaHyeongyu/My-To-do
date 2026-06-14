import Foundation

enum ScheduleKind: String, CaseIterable, Identifiable {
    case routine
    case task

    var id: String { rawValue }

    var title: String {
        switch self {
        case .routine: "Routine"
        case .task: "Task"
        }
    }

    var symbolName: String {
        switch self {
        case .routine: "clock.arrow.circlepath"
        case .task: "checkmark.circle"
        }
    }
}
