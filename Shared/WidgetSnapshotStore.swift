import Foundation

struct WidgetTaskItem: Codable, Hashable, Identifiable {
    let id: UUID
    let title: String
}

struct WidgetRoutineItem: Codable, Hashable, Identifiable {
    let id: UUID
    let title: String
    let startTimeText: String
    let endTimeText: String
    let outcomeRawValue: String?

    init(
        id: UUID,
        title: String,
        startTimeText: String,
        endTimeText: String,
        outcome: WidgetRoutineOutcome = .pending
    ) {
        self.id = id
        self.title = title
        self.startTimeText = startTimeText
        self.endTimeText = endTimeText
        self.outcomeRawValue = outcome.rawValue
    }

    var outcome: WidgetRoutineOutcome {
        WidgetRoutineOutcome(rawValue: outcomeRawValue ?? "") ?? .pending
    }
}

struct WidgetSnapshot: Codable, Hashable {
    let generatedAt: Date
    let routines: [WidgetRoutineItem]
    let tasks: [WidgetTaskItem]

    static let empty = WidgetSnapshot(generatedAt: .distantPast, routines: [], tasks: [])
}

enum WidgetRoutineOutcome: String, Codable, Hashable {
    case pending
    case success
    case fail

    var title: String {
        switch self {
        case .pending: "Pending"
        case .success: "Success"
        case .fail: "Fail"
        }
    }

    var symbolName: String {
        switch self {
        case .pending: "circle"
        case .success: "checkmark.circle.fill"
        case .fail: "xmark.circle.fill"
        }
    }

    var isResolved: Bool {
        self != .pending
    }
}

enum OneWidgetDeepLink {
    static let calendar = URL(string: "one://calendar")!
    static let success = URL(string: "one://calendar?outcome=success")!
    static let fail = URL(string: "one://calendar?outcome=fail")!
}

enum WidgetSnapshotStore {
    static let appGroupIdentifier = "group.com.nahyeongyu.One"

    private static let snapshotKey = "todayWidgetSnapshot"

    static func load() -> WidgetSnapshot {
        guard
            let data = defaults.data(forKey: snapshotKey),
            let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else {
            return .empty
        }

        return snapshot
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }
}
