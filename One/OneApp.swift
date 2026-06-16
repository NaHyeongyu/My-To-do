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
            return fallbackContainer(for: schema, cloudKitError: error)
        }
    }

    private static func fallbackContainer(for schema: Schema, cloudKitError: Error) -> ModelContainer {
        let localConfiguration = ModelConfiguration(schema: schema)

        do {
            return try ModelContainer(for: schema, configurations: [localConfiguration])
        } catch {
            assertionFailure(
                "Failed to create SwiftData containers. CloudKit error: \(cloudKitError). Local error: \(error)"
            )
            let memoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [memoryConfiguration])
            } catch {
                preconditionFailure("Failed to create in-memory SwiftData container: \(error)")
            }
        }
    }
}
