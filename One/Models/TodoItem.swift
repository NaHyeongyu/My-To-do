import Foundation
import SwiftData

@Model
final class ScheduleItem: Identifiable {
    var id: UUID = UUID()
    var kindRawValue: String = ScheduleKind.task.rawValue
    var title: String = ""
    var notes: String = ""
    var createdAt: Date = Date()
    var taskDate: Date?
    var completedAt: Date?
    var startTime: Date?
    var endTime: Date?
    var repeatWeekdayMask: Int = RepeatWeekdayMask.everyDay
    var activeFrom: Date?
    var activeUntil: Date?
    var routineLabelRawValue: String?
    var routineVersionsRawValue: String = ""

    init(
        id: UUID = UUID(),
        kind: ScheduleKind,
        title: String,
        notes: String = "",
        createdAt: Date = .now,
        taskDate: Date? = nil,
        completedAt: Date? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        repeatWeekdayMask: Int = RepeatWeekdayMask.everyDay,
        activeFrom: Date? = nil,
        activeUntil: Date? = nil,
        routineLabel: RoutineLabel? = nil,
        routineLabelRawValue: String? = nil,
        routineVersionsRawValue: String = ""
    ) {
        self.id = id
        self.kindRawValue = kind.rawValue
        self.title = title
        self.notes = notes
        self.createdAt = createdAt
        self.taskDate = taskDate
        self.completedAt = completedAt
        self.startTime = startTime
        self.endTime = endTime
        self.repeatWeekdayMask = repeatWeekdayMask
        self.activeFrom = activeFrom
        self.activeUntil = activeUntil
        self.routineLabelRawValue = kind == .routine ? (routineLabelRawValue ?? routineLabel?.rawValue) : nil
        self.routineVersionsRawValue = kind == .routine ? routineVersionsRawValue : ""
    }
}

enum RoutineLabel: String, CaseIterable, Identifiable, Hashable {
    case study
    case coding
    case work
    case life
    case play
    case hobby
    case rest
    case sleep
    case health
    case money
    case admin
    case social

    var id: String { rawValue }

    var title: String {
        switch self {
        case .study: "Study"
        case .coding: "Coding"
        case .work: "Work"
        case .life: "Life"
        case .play: "Play"
        case .hobby: "Hobby"
        case .rest: "Rest"
        case .sleep: "Sleep"
        case .health: "Health"
        case .money: "Money"
        case .admin: "Admin"
        case .social: "Social"
        }
    }

    var symbolName: String {
        switch self {
        case .study: "book.closed.fill"
        case .coding: "chevron.left.forwardslash.chevron.right"
        case .work: "briefcase.fill"
        case .life: "heart.fill"
        case .play: "gamecontroller.fill"
        case .hobby: "paintpalette.fill"
        case .rest: "pause.circle.fill"
        case .sleep: "bed.double.fill"
        case .health: "figure.run"
        case .money: "banknote.fill"
        case .admin: "tray.full.fill"
        case .social: "person.2.fill"
        }
    }
}

struct RoutineLabelOption: Identifiable, Hashable, Sendable {
    let rawValue: String
    let title: String
    let symbolName: String
    let isCustom: Bool

    var id: String { rawValue }

    static var builtIns: [RoutineLabelOption] {
        RoutineLabel.allCases.map(\.option)
    }

    static func options(customLabels: [CustomRoutineLabel]) -> [RoutineLabelOption] {
        let builtInRawValues = Set(RoutineLabel.allCases.map(\.rawValue))
        var seenCustomIDs: Set<String> = []
        let customOptions = customLabels.compactMap { label -> RoutineLabelOption? in
            guard !builtInRawValues.contains(label.id), seenCustomIDs.insert(label.id).inserted else {
                return nil
            }

            return label.option
        }

        return builtIns + customOptions
    }

    static func option(for rawValue: String?, customLabels: [CustomRoutineLabel]) -> RoutineLabelOption? {
        guard let rawValue else {
            return nil
        }

        if let builtInLabel = RoutineLabel(rawValue: rawValue) {
            return builtInLabel.option
        }

        return customLabels.first { $0.id == rawValue }?.option ?? fallback(for: rawValue)
    }

    static func fallback(for rawValue: String) -> RoutineLabelOption {
        RoutineLabelOption(
            rawValue: rawValue,
            title: "Custom",
            symbolName: CustomRoutineLabel.defaultSymbolName,
            isCustom: true
        )
    }
}

extension RoutineLabel {
    var option: RoutineLabelOption {
        RoutineLabelOption(
            rawValue: rawValue,
            title: title,
            symbolName: symbolName,
            isCustom: false
        )
    }
}

struct CustomRoutineLabel: Codable, Identifiable, Hashable, Sendable {
    static let defaultSymbolName = "tag.fill"

    var id: String
    var title: String
    var symbolName: String

    init(
        id: String = "custom.\(UUID().uuidString)",
        title: String,
        symbolName: String = Self.defaultSymbolName
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = id
        self.title = trimmedTitle.isEmpty ? "Label" : trimmedTitle
        self.symbolName = symbolName
    }

    var option: RoutineLabelOption {
        RoutineLabelOption(
            rawValue: id,
            title: title,
            symbolName: symbolName,
            isCustom: true
        )
    }
}

struct RoutineVersion: Codable, Identifiable, Hashable, Sendable {
    static let standardID = "standard"
    static let minimumID = "minimum"
    static let deepID = "deep"

    var id: String
    var title: String
    var durationMinutes: Int
    var isDefault: Bool

    init(
        id: String = "version.\(UUID().uuidString)",
        title: String,
        durationMinutes: Int,
        isDefault: Bool = false
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = id
        self.title = trimmedTitle.isEmpty ? "Version" : trimmedTitle
        self.durationMinutes = Self.normalizedDuration(durationMinutes)
        self.isDefault = isDefault
    }

    static func normalizedDuration(_ minutes: Int) -> Int {
        let clampedMinutes = min(ScheduleItem.minutesPerDay, max(5, minutes))
        return max(5, (clampedMinutes / 5) * 5)
    }
}

enum RoutineVersionStore {
    static func versions(from rawValue: String) -> [RoutineVersion] {
        guard
            !rawValue.isEmpty,
            let data = rawValue.data(using: .utf8),
            let versions = try? JSONDecoder().decode([RoutineVersion].self, from: data)
        else {
            return []
        }

        return normalizedVersions(versions, fallbackDuration: 60)
    }

    static func storageValue(for versions: [RoutineVersion], fallbackDuration: Int) -> String {
        let normalizedVersions = normalizedVersions(versions, fallbackDuration: fallbackDuration)
        guard
            let data = try? JSONEncoder().encode(normalizedVersions),
            let rawValue = String(data: data, encoding: .utf8)
        else {
            return ""
        }

        return rawValue
    }

    static func defaultVersions(for plannedMinutes: Int) -> [RoutineVersion] {
        let standardMinutes = RoutineVersion.normalizedDuration(plannedMinutes)
        let minimumMinutes = RoutineVersion.normalizedDuration(min(15, standardMinutes))
        let deepMinutes = RoutineVersion.normalizedDuration(min(ScheduleItem.minutesPerDay, max(standardMinutes + 30, standardMinutes * 2)))

        let candidates = [
            RoutineVersion(id: RoutineVersion.standardID, title: "Standard", durationMinutes: standardMinutes, isDefault: true),
            RoutineVersion(id: RoutineVersion.minimumID, title: "Minimum", durationMinutes: minimumMinutes),
            RoutineVersion(id: RoutineVersion.deepID, title: "Deep", durationMinutes: deepMinutes)
        ]

        return candidates
    }

    static func normalizedVersions(_ versions: [RoutineVersion], fallbackDuration: Int) -> [RoutineVersion] {
        let fallbackVersions = defaultVersions(for: fallbackDuration)
        let storedMinimum = versions.first { $0.id == RoutineVersion.minimumID }
        let storedDeep = versions.first { $0.id == RoutineVersion.deepID }

        return [
            fallbackVersions[0],
            RoutineVersion(
                id: RoutineVersion.minimumID,
                title: "Minimum",
                durationMinutes: storedMinimum?.durationMinutes ?? fallbackVersions[1].durationMinutes
            ),
            RoutineVersion(
                id: RoutineVersion.deepID,
                title: "Deep",
                durationMinutes: storedDeep?.durationMinutes ?? fallbackVersions[2].durationMinutes
            )
        ]
    }
}

extension ScheduleItem {
    static let minutesPerDay = 24 * 60

    var kind: ScheduleKind {
        get { ScheduleKind(rawValue: kindRawValue) ?? .task }
        set { kindRawValue = newValue.rawValue }
    }

    var routineLabel: RoutineLabel? {
        get {
            guard let routineLabelRawValue else {
                return nil
            }

            return RoutineLabel(rawValue: routineLabelRawValue)
        }
        set { routineLabelRawValue = newValue?.rawValue }
    }

    var routineVersions: [RoutineVersion] {
        get {
            RoutineVersionStore.versions(from: routineVersionsRawValue)
        }
        set {
            routineVersionsRawValue = kind == .routine
                ? RoutineVersionStore.storageValue(for: newValue, fallbackDuration: max(5, durationMinutes()))
                : ""
        }
    }

    var isCompleted: Bool {
        completedAt != nil
    }

    var repeatSummary: String {
        RepeatWeekdayMask.summary(for: repeatWeekdayMask)
    }

    func repeats(on date: Date, calendar: Calendar = .current) -> Bool {
        guard kind == .routine, isRoutineActive(on: date, calendar: calendar) else { return false }
        let weekdayNumber = calendar.component(.weekday, from: date)
        guard let weekday = RepeatWeekday(rawValue: weekdayNumber) else { return false }
        return RepeatWeekdayMask.contains(weekday, in: repeatWeekdayMask)
    }

    func isRoutineActive(on date: Date, calendar: Calendar = .current) -> Bool {
        guard kind == .routine else { return false }

        let dayStart = calendar.startOfDay(for: date)

        if let activeFrom, dayStart < calendar.startOfDay(for: activeFrom) {
            return false
        }

        if let activeUntil, dayStart >= calendar.startOfDay(for: activeUntil) {
            return false
        }

        return true
    }

    func canScheduleRoutineNotifications(now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard kind == .routine else { return false }

        if let activeUntil, calendar.startOfDay(for: activeUntil) <= calendar.startOfDay(for: now) {
            return false
        }

        return true
    }

    func isTodayTask(on date: Date = .now, calendar: Calendar = .current) -> Bool {
        guard kind == .task else { return false }
        return calendar.isDate(taskDate ?? createdAt, inSameDayAs: date)
    }

    func toggleCompleted(now: Date = .now) {
        guard kind == .task else { return }
        completedAt = isCompleted ? nil : now
    }

    func durationMinutes(calendar: Calendar = .current) -> Int {
        guard let startTime, let endTime else { return 0 }
        return Self.durationMinutes(startTime: startTime, endTime: endTime, calendar: calendar)
    }

    func crossesMidnight(calendar: Calendar = .current) -> Bool {
        guard let startTime, let endTime else { return false }
        return Self.crossesMidnight(startTime: startTime, endTime: endTime, calendar: calendar)
    }

    func normalizedEndMinute(calendar: Calendar = .current) -> Int? {
        guard let startTime, let endTime else { return nil }
        let startMinute = calendar.minuteOfDay(for: startTime)
        let endMinute = calendar.minuteOfDay(for: endTime)
        return endMinute > startMinute ? endMinute : endMinute + Self.minutesPerDay
    }

    func timeRangeText(calendar: Calendar = .current) -> String {
        guard let startTime, let endTime else { return "No time set" }

        let startText = startTime.formatted(.dateTime.hour().minute())
        let endText = endTime.formatted(.dateTime.hour().minute())
        let suffix = crossesMidnight(calendar: calendar) ? " +1d" : ""
        return "\(startText) - \(endText)\(suffix)"
    }

    func timeRangeText(durationMinutes: Int, calendar: Calendar = .current) -> String {
        guard let startTime else { return "No time set" }

        let startMinute = calendar.minuteOfDay(for: startTime)
        let endMinute = startMinute + max(1, durationMinutes)
        let startText = startTime.formatted(.dateTime.hour().minute())
        let endDate = calendar.date(byAdding: .minute, value: endMinute, to: calendar.startOfDay(for: startTime)) ?? startTime
        let suffix = endMinute >= Self.minutesPerDay ? " +1d" : ""

        return "\(startText) - \(endDate.formatted(.dateTime.hour().minute()))\(suffix)"
    }

    static func durationMinutes(startTime: Date, endTime: Date, calendar: Calendar = .current) -> Int {
        let startMinute = calendar.minuteOfDay(for: startTime)
        let endMinute = calendar.minuteOfDay(for: endTime)
        let normalizedEndMinute = endMinute > startMinute ? endMinute : endMinute + minutesPerDay
        return max(0, normalizedEndMinute - startMinute)
    }

    static func crossesMidnight(startTime: Date, endTime: Date, calendar: Calendar = .current) -> Bool {
        calendar.minuteOfDay(for: endTime) <= calendar.minuteOfDay(for: startTime)
    }

    func durationText(calendar: Calendar = .current) -> String {
        let minutes = durationMinutes(calendar: calendar)
        guard minutes > 0 else { return "No time set" }

        return minutes.readableDuration
    }

    func routineVersionOptions(calendar: Calendar = .current) -> [RoutineVersion] {
        let plannedMinutes = max(5, durationMinutes(calendar: calendar))
        let storedVersions = RoutineVersionStore.normalizedVersions(routineVersions, fallbackDuration: plannedMinutes)
        return storedVersions.isEmpty ? RoutineVersionStore.defaultVersions(for: plannedMinutes) : storedVersions
    }

    func routineVersion(for versionID: String?, calendar: Calendar = .current) -> RoutineVersion? {
        guard let versionID else {
            return nil
        }

        return routineVersionOptions(calendar: calendar).first { $0.id == versionID }
    }

    func plannedDurationMinutes(state: RoutineOccurrenceState?, calendar: Calendar = .current) -> Int {
        routineVersion(for: state?.routineVersionID, calendar: calendar)?.durationMinutes
            ?? durationMinutes(calendar: calendar)
    }
}

extension Int {
    var readableDuration: String {
        guard self > 0 else { return "0m" }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0, remainingMinutes > 0 {
            return "\(hours)h \(remainingMinutes)m"
        }

        if hours > 0 {
            return "\(hours)h"
        }

        return "\(remainingMinutes)m"
    }

    private var minutes: Int { self }
}
