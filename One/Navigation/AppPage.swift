import Foundation

enum AppPage: String, CaseIterable, Identifiable {
    case timetable
    case tasks
    case routines

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timetable: "Calendar"
        case .tasks: "Tasks"
        case .routines: "Routines"
        }
    }

    var symbolName: String {
        switch self {
        case .timetable: "calendar"
        case .tasks: "list.bullet"
        case .routines: "repeat"
        }
    }
}
