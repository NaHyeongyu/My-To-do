import UIKit
import SwiftData
import UserNotifications

final class NotificationDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    @MainActor private var cachedModelContainer: ModelContainer?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        RoutineNotificationAction.register(on: center)
        center.delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            handleNotificationResponse(response)
            completionHandler()
        }
    }

    @MainActor
    private func handleNotificationResponse(_ response: UNNotificationResponse) {
        guard
            response.actionIdentifier == RoutineNotificationAction.successIdentifier
                || response.actionIdentifier == RoutineNotificationAction.failIdentifier
                || response.actionIdentifier == RoutineNotificationAction.snoozeIdentifier,
            let routineID = routineID(from: response)
        else {
            return
        }

        guard
            let context = makeModelContext(),
            let update = routineUpdateContext(for: routineID, modelContext: context)
        else {
            return
        }

        switch response.actionIdentifier {
        case RoutineNotificationAction.successIdentifier:
            update.state.status = .done
        case RoutineNotificationAction.failIdentifier:
            update.state.status = .skipped
        case RoutineNotificationAction.snoozeIdentifier:
            update.state.status = .pending
            update.state.delayMinutes = min(
                180,
                max(0, update.state.delayMinutes + RoutineNotificationAction.snoozeMinutes)
            )
            update.state.updatedAt = .now
            scheduleSnoozedNotification(from: response, routineID: routineID)
        default:
            return
        }

        try? context.save()
        WidgetSnapshotWriter.save(items: update.items, routineStates: update.statesForSnapshot)
    }

    @MainActor
    private func makeModelContext() -> ModelContext? {
        if cachedModelContainer == nil {
            let schema = Schema([ScheduleItem.self, RoutineOccurrenceState.self])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            cachedModelContainer = try? ModelContainer(for: schema, configurations: [configuration])
        }

        return cachedModelContainer.map(ModelContext.init)
    }

    @MainActor
    private func routineUpdateContext(
        for routineID: UUID,
        modelContext: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> RoutineNotificationUpdateContext? {
        let items = (try? modelContext.fetch(FetchDescriptor<ScheduleItem>())) ?? []
        let states = (try? modelContext.fetch(FetchDescriptor<RoutineOccurrenceState>())) ?? []
        let today = calendar.startOfDay(for: now)

        guard let routine = items.first(where: {
            $0.id == routineID && $0.isRoutineActive(on: today, calendar: calendar)
        }) else {
            return nil
        }

        let state = states.first {
            $0.routineID == routineID && calendar.isDate($0.dayStart, inSameDayAs: today)
        } ?? {
            let newState = RoutineOccurrenceState(routineID: routine.id, dayStart: today)
            modelContext.insert(newState)
            return newState
        }()

        let statesForSnapshot = states.filter {
            $0.routineID != state.routineID
                || !calendar.isDate($0.dayStart, inSameDayAs: state.dayStart)
        } + [state]

        return RoutineNotificationUpdateContext(
            items: items,
            state: state,
            statesForSnapshot: statesForSnapshot
        )
    }

    private func routineID(from response: UNNotificationResponse) -> UUID? {
        guard
            let routineIDString = response.notification.request.content.userInfo[RoutineNotificationAction.routineIDKey] as? String
        else {
            return nil
        }

        return UUID(uuidString: routineIDString)
    }

    private func scheduleSnoozedNotification(from response: UNNotificationResponse, routineID: UUID) {
        guard
            let content = response.notification.request.content.mutableCopy() as? UNMutableNotificationContent
        else {
            return
        }

        content.body = "Snoozed for \(RoutineNotificationAction.snoozeMinutes) minutes."
        content.categoryIdentifier = RoutineNotificationAction.categoryIdentifier
        content.userInfo = [RoutineNotificationAction.routineIDKey: routineID.uuidString]
        content.sound = UNNotificationSound(named: UNNotificationSoundName("one_signal.wav"))

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(RoutineNotificationAction.snoozeMinutes * 60),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: "routine-notification-\(routineID.uuidString)-snooze-\(Int(Date.now.timeIntervalSince1970))",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }
}

private struct RoutineNotificationUpdateContext {
    let items: [ScheduleItem]
    let state: RoutineOccurrenceState
    let statesForSnapshot: [RoutineOccurrenceState]
}
