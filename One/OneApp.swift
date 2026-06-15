import SwiftData
import SwiftUI

@main
struct OneApp: App {
    @UIApplicationDelegateAdaptor(NotificationDelegate.self) private var notificationDelegate
    @AppStorage(AppSettingsKey.themeMode) private var themeModeRaw = AppThemeMode.system.rawValue

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme((AppThemeMode(rawValue: themeModeRaw) ?? .system).colorScheme)
        }
        .modelContainer(for: [ScheduleItem.self, RoutineOccurrenceState.self])
    }
}
