import SwiftData
import SwiftUI

@main
struct OneApp: App {
    @UIApplicationDelegateAdaptor(NotificationDelegate.self) private var notificationDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [ScheduleItem.self, RoutineOccurrenceState.self])
    }
}
