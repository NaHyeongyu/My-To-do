import SwiftUI

enum AppSettingsKey {
    static let notificationsEnabled = "settings.notificationsEnabled"
    static let notificationPreferenceReconciled = "settings.notificationPreferenceReconciled.v1"
    static let themeMode = "settings.themeMode"
    static let customRoutineLabels = "settings.customRoutineLabels"
}

enum CustomRoutineLabelStore {
    static let emptyStorage = "[]"
    static let availableSymbolNames = [
        "tag.fill",
        "bolt.fill",
        "target",
        "brain.head.profile",
        "flame.fill",
        "clock.fill",
        "chart.bar.fill",
        "sparkles",
        "lock.fill",
        "star.fill",
        "flag.fill",
        "pin.fill",
        "paperclip",
        "folder.fill",
        "calendar",
        "alarm.fill",
        "bell.fill",
        "lightbulb.fill",
        "house.fill",
        "cart.fill",
        "creditcard.fill",
        "gift.fill",
        "camera.fill",
        "music.note",
        "figure.walk",
        "dumbbell.fill",
        "leaf.fill",
        "fork.knife",
        "cup.and.saucer.fill"
    ]

    static func labels(defaults: UserDefaults = .standard) -> [CustomRoutineLabel] {
        labels(from: defaults.string(forKey: AppSettingsKey.customRoutineLabels) ?? emptyStorage)
    }

    static func labels(from rawValue: String) -> [CustomRoutineLabel] {
        guard
            let data = rawValue.data(using: .utf8),
            let labels = try? JSONDecoder().decode([CustomRoutineLabel].self, from: data)
        else {
            return []
        }

        return sanitized(labels)
    }

    static func encoded(_ labels: [CustomRoutineLabel]) -> String {
        let sanitizedLabels = sanitized(labels)
        guard
            let data = try? JSONEncoder().encode(sanitizedLabels),
            let rawValue = String(data: data, encoding: .utf8)
        else {
            return emptyStorage
        }

        return rawValue
    }

    static func save(_ labels: [CustomRoutineLabel], defaults: UserDefaults = .standard) {
        defaults.set(encoded(labels), forKey: AppSettingsKey.customRoutineLabels)
    }

    private static func sanitized(_ labels: [CustomRoutineLabel]) -> [CustomRoutineLabel] {
        var seenIDs: Set<String> = []
        return labels.compactMap { label in
            let title = label.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, seenIDs.insert(label.id).inserted else {
                return nil
            }

            let symbolName = availableSymbolNames.contains(label.symbolName)
                ? label.symbolName
                : CustomRoutineLabel.defaultSymbolName
            return CustomRoutineLabel(id: label.id, title: title, symbolName: symbolName)
        }
    }
}

enum AppThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
