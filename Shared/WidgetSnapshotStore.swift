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
    let startDate: Date?
    let endDate: Date?
    let outcomeRawValue: String?

    init(
        id: UUID,
        title: String,
        startTimeText: String,
        endTimeText: String,
        startDate: Date? = nil,
        endDate: Date? = nil,
        outcome: WidgetRoutineOutcome = .pending
    ) {
        self.id = id
        self.title = title
        self.startTimeText = startTimeText
        self.endTimeText = endTimeText
        self.startDate = startDate
        self.endDate = endDate
        self.outcomeRawValue = outcome.rawValue
    }

    var outcome: WidgetRoutineOutcome {
        WidgetRoutineOutcome(rawValue: outcomeRawValue ?? "") ?? .pending
    }

    func withOutcome(_ outcome: WidgetRoutineOutcome) -> WidgetRoutineItem {
        WidgetRoutineItem(
            id: id,
            title: title,
            startTimeText: startTimeText,
            endTimeText: endTimeText,
            startDate: startDate,
            endDate: endDate,
            outcome: outcome
        )
    }

    func isOutcomeAvailable(at date: Date) -> Bool {
        guard !outcome.isResolved else {
            return false
        }

        guard let startDate else {
            return true
        }

        return date >= startDate
    }
}

struct WidgetRoutineOutcomeCommand: Codable, Hashable, Identifiable {
    let id: UUID
    let routineID: UUID
    let outcome: WidgetRoutineOutcome
    let occurredAt: Date
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
        case .pending: "Open"
        case .success: "Success"
        case .fail: "Failed"
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
    static let appGroupIdentifier = "group.com.onemytodo.app"

    private static let snapshotKey = "todayWidgetSnapshot"
    private static let pendingRoutineOutcomeKey = "pendingRoutineOutcomeCommands"
    private static let snapshotFileName = "today-widget-snapshot.json"
    private static let pendingRoutineOutcomeFileName = "pending-routine-outcomes.json"

    static func load() -> WidgetSnapshot {
        if let snapshot = read(WidgetSnapshot.self, from: snapshotFileURL) {
            return snapshot
        }

        guard
            let data = defaults?.data(forKey: snapshotKey),
            let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else {
            return .empty
        }

        return snapshot
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        write(data, to: snapshotFileURL)
        defaults?.set(data, forKey: snapshotKey)
        defaults?.synchronize()
    }

    static func updateRoutineOutcome(
        routineID: UUID,
        outcome: WidgetRoutineOutcome,
        at date: Date = .now,
        calendar: Calendar = .current
    ) {
        var snapshot = load()
        let commandDate: Date

        if let index = snapshot.routines.firstIndex(where: { $0.id == routineID }) {
            let routine = snapshot.routines[index]
            var routines = snapshot.routines
            commandDate = routine.startDate ?? date
            routines[index] = routine.withOutcome(outcome)
            snapshot = WidgetSnapshot(
                generatedAt: date,
                routines: routines,
                tasks: snapshot.tasks
            )
            save(snapshot)
        } else {
            commandDate = date
        }

        enqueuePendingRoutineOutcome(
            WidgetRoutineOutcomeCommand(
                id: UUID(),
                routineID: routineID,
                outcome: outcome,
                occurredAt: commandDate
            ),
            calendar: calendar
        )
    }

    static func consumePendingRoutineOutcomes() -> [WidgetRoutineOutcomeCommand] {
        let commands = pendingRoutineOutcomes()
        remove(pendingRoutineOutcomeFileURL)
        defaults?.removeObject(forKey: pendingRoutineOutcomeKey)
        defaults?.synchronize()
        return commands
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private static var appGroupContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    private static var snapshotFileURL: URL? {
        appGroupContainerURL?.appendingPathComponent(snapshotFileName, isDirectory: false)
    }

    private static var pendingRoutineOutcomeFileURL: URL? {
        appGroupContainerURL?.appendingPathComponent(pendingRoutineOutcomeFileName, isDirectory: false)
    }

    private static func pendingRoutineOutcomes() -> [WidgetRoutineOutcomeCommand] {
        if let commands = read([WidgetRoutineOutcomeCommand].self, from: pendingRoutineOutcomeFileURL) {
            return commands
        }

        guard
            let data = defaults?.data(forKey: pendingRoutineOutcomeKey),
            let commands = try? JSONDecoder().decode([WidgetRoutineOutcomeCommand].self, from: data)
        else {
            return []
        }

        return commands
    }

    private static func enqueuePendingRoutineOutcome(
        _ command: WidgetRoutineOutcomeCommand,
        calendar: Calendar
    ) {
        var commands = pendingRoutineOutcomes()
        commands.removeAll {
            $0.routineID == command.routineID
                && calendar.isDate($0.occurredAt, inSameDayAs: command.occurredAt)
        }
        commands.append(command)

        guard let data = try? JSONEncoder().encode(Array(commands.suffix(20))) else { return }
        write(data, to: pendingRoutineOutcomeFileURL)
        defaults?.set(data, forKey: pendingRoutineOutcomeKey)
        defaults?.synchronize()
    }

    private static func read<T: Decodable>(_ type: T.Type, from url: URL?) -> T? {
        guard
            let url,
            let data = try? Data(contentsOf: url)
        else {
            return nil
        }

        return try? JSONDecoder().decode(type, from: data)
    }

    private static func write(_ data: Data, to url: URL?) {
        guard let url else {
            return
        }

        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: url, options: [.atomic])
    }

    private static func remove(_ url: URL?) {
        guard let url else {
            return
        }

        try? FileManager.default.removeItem(at: url)
    }
}
