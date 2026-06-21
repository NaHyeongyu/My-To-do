import SwiftData
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

@MainActor
enum AppDataSyncService {
    static func widgetSnapshotSignature(
        items: [ScheduleItem],
        routineStates: [RoutineOccurrenceState]
    ) -> String {
        let itemSignature = items
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map(widgetSnapshotItemSignature)
            .joined(separator: ";")
        let stateSignature = routineStates
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map(widgetSnapshotStateSignature)
            .joined(separator: ";")

        return "\(itemSignature)#\(stateSignature)"
    }

    static func routineNotificationSignature(
        items: [ScheduleItem],
        routineStates: [RoutineOccurrenceState]
    ) -> String {
        let itemSignatures = items
            .filter { $0.kind == .routine }
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { item in
                [
                    item.id.uuidString,
                    item.title,
                    item.notes,
                    item.taskDate?.timeIntervalSince1970.description ?? "",
                    item.startTime?.timeIntervalSince1970.description ?? "",
                    item.endTime?.timeIntervalSince1970.description ?? "",
                    item.repeatWeekdayMask.description,
                    item.activeFrom?.timeIntervalSince1970.description ?? "",
                    item.activeUntil?.timeIntervalSince1970.description ?? "",
                    item.sourceRoutineID?.uuidString ?? ""
                ].joined(separator: "|")
            }
        let stateSignatures = routineStates
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { state in
                [
                    state.routineID.uuidString,
                    state.dayStart.timeIntervalSince1970.description,
                    state.isHidden.description
                ].joined(separator: "|")
            }

        return (itemSignatures + stateSignatures).joined(separator: ";")
    }

    static func saveAndSync(
        modelContext: ModelContext,
        queryItems: [ScheduleItem],
        queryRoutineStates: [RoutineOccurrenceState],
        notificationsEnabled: Bool,
        scenePhase: ScenePhase,
        deferredWidget: Bool = false,
        syncNotifications shouldSyncNotifications: Bool = true
    ) {
        try? modelContext.save()
        updateWidgetSnapshot(
            modelContext: modelContext,
            queryItems: queryItems,
            queryRoutineStates: queryRoutineStates,
            deferred: deferredWidget
        )

        if shouldSyncNotifications {
            syncRoutineNotifications(
                enabled: notificationsEnabled,
                items: queryItems,
                routineStates: queryRoutineStates,
                scenePhase: scenePhase
            )
        }
    }

    static func updateWidgetSnapshot(
        modelContext: ModelContext,
        queryItems: [ScheduleItem],
        queryRoutineStates: [RoutineOccurrenceState],
        replacing updatedState: RoutineOccurrenceState? = nil,
        deferred: Bool = false
    ) {
        let writeSnapshot = {
            let states = routineStatesForWidget(
                modelContext: modelContext,
                queryRoutineStates: queryRoutineStates,
                replacing: updatedState
            )
            WidgetSnapshotWriter.save(
                items: fetchedItems(modelContext: modelContext, fallback: queryItems),
                routineStates: states
            )
        }

        if deferred {
            Task { @MainActor in
                writeSnapshot()
            }
        } else {
            writeSnapshot()
        }
    }

    static func syncRoutineNotifications(
        enabled: Bool,
        items: [ScheduleItem],
        routineStates: [RoutineOccurrenceState],
        scenePhase: ScenePhase
    ) {
        let schedules = items.compactMap(RoutineNotificationSchedule.init(item:))
        let notificationStates = routineStates.map(RoutineNotificationOccurrenceState.init(state:))
        #if canImport(UIKit)
        let backgroundTaskID = scenePhase == .background
            ? UIApplication.shared.beginBackgroundTask(withName: "SyncRoutineNotifications", expirationHandler: nil)
            : UIBackgroundTaskIdentifier.invalid
        #endif

        Task {
            await RoutineNotificationScheduler.shared.syncNotifications(
                enabled: enabled,
                for: schedules,
                routineStates: notificationStates
            )
            #if canImport(UIKit)
            await MainActor.run {
                if backgroundTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                }
            }
            #endif
        }
    }

    static func fetchedItems(
        modelContext: ModelContext,
        fallback: [ScheduleItem]
    ) -> [ScheduleItem] {
        let descriptor = FetchDescriptor<ScheduleItem>()
        return (try? modelContext.fetch(descriptor)) ?? fallback
    }

    static func fetchedRoutineStates(
        modelContext: ModelContext,
        fallback: [RoutineOccurrenceState]
    ) -> [RoutineOccurrenceState] {
        let descriptor = FetchDescriptor<RoutineOccurrenceState>()
        return (try? modelContext.fetch(descriptor)) ?? fallback
    }

    private static func routineStatesForWidget(
        modelContext: ModelContext,
        queryRoutineStates: [RoutineOccurrenceState],
        replacing updatedState: RoutineOccurrenceState?
    ) -> [RoutineOccurrenceState] {
        let states = fetchedRoutineStates(modelContext: modelContext, fallback: queryRoutineStates)

        guard let updatedState else {
            return states
        }

        return states.filter { state in
            state.routineID != updatedState.routineID
                || !Calendar.current.isDate(state.dayStart, inSameDayAs: updatedState.dayStart)
        } + [updatedState]
    }

    private static func widgetSnapshotItemSignature(for item: ScheduleItem) -> String {
        [
            item.id.uuidString,
            item.kindRawValue,
            item.title,
            item.createdAt.timeIntervalSince1970.description,
            item.taskDate?.timeIntervalSince1970.description ?? "",
            item.completedAt?.timeIntervalSince1970.description ?? "",
            item.startTime?.timeIntervalSince1970.description ?? "",
            item.endTime?.timeIntervalSince1970.description ?? "",
            item.repeatWeekdayMask.description,
            item.activeFrom?.timeIntervalSince1970.description ?? "",
            item.activeUntil?.timeIntervalSince1970.description ?? "",
            item.routineLabelRawValue ?? "",
            item.routineVersionsRawValue,
            item.sourceRoutineID?.uuidString ?? ""
        ].joined(separator: "|")
    }

    private static func widgetSnapshotStateSignature(for state: RoutineOccurrenceState) -> String {
        [
            state.routineID.uuidString,
            state.dayStart.timeIntervalSince1970.description,
            state.statusRawValue,
            state.failReasonRawValue ?? "",
            state.delayMinutes.description,
            state.routineVersionID ?? "",
            state.isHidden.description
        ].joined(separator: "|")
    }
}
