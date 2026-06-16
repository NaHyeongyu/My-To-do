import SwiftUI

enum AppSettingsKey {
    static let notificationsEnabled = "settings.notificationsEnabled"
    static let themeMode = "settings.themeMode"

    static func routineLabelWeeklyTargetMinutes(_ label: RoutineLabel) -> String {
        "settings.routineLabelTargetMinutes.\(label.rawValue)"
    }
}

enum RoutineLabelTargetStore {
    static let maximumWeeklyTargetMinutes = 7 * 24 * 60
    static let targetStepMinutes = 30

    static func weeklyTargetMinutes(for label: RoutineLabel, defaults: UserDefaults = .standard) -> Int {
        let key = AppSettingsKey.routineLabelWeeklyTargetMinutes(label)
        guard defaults.object(forKey: key) != nil else {
            return 0
        }

        return max(0, defaults.integer(forKey: key))
    }

    static func setWeeklyTargetMinutes(_ minutes: Int, for label: RoutineLabel, defaults: UserDefaults = .standard) {
        let snappedMinutes = max(
            0,
            min(maximumWeeklyTargetMinutes, (minutes / targetStepMinutes) * targetStepMinutes)
        )
        defaults.set(snappedMinutes, forKey: AppSettingsKey.routineLabelWeeklyTargetMinutes(label))
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
