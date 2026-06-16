import SwiftData
import SwiftUI

@main
struct OneApp: App {
    @UIApplicationDelegateAdaptor(NotificationDelegate.self) private var notificationDelegate
    @AppStorage(AppSettingsKey.themeMode) private var themeModeRaw = AppThemeMode.system.rawValue
    private let modelContainer = OneModelContainer.make()

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme((AppThemeMode(rawValue: themeModeRaw) ?? .system).colorScheme)
        }
        .modelContainer(modelContainer)
    }
}

enum OneModelContainer {
    static let cloudKitContainerIdentifier = "iCloud.com.onemytodo.app"

    static func make() -> ModelContainer {
        let schema = Schema([
            ScheduleItem.self,
            RoutineOccurrenceState.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private(cloudKitContainerIdentifier)
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create SwiftData CloudKit container: \(error)")
        }
    }
}
