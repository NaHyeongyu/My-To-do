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
}

struct WidgetSnapshot: Codable, Hashable {
    let generatedAt: Date
    let routines: [WidgetRoutineItem]
    let tasks: [WidgetTaskItem]

    static let empty = WidgetSnapshot(generatedAt: .distantPast, routines: [], tasks: [])
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
