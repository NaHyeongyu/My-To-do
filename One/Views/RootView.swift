import SwiftData
import SwiftUI
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppSettingsKey.notificationsEnabled) private var notificationsEnabled = false

    @Query(sort: \ScheduleItem.createdAt, order: .reverse) private var items: [ScheduleItem]
    @Query(sort: \RoutineOccurrenceState.updatedAt, order: .reverse) private var routineStates: [RoutineOccurrenceState]

    @State private var selectedPage: AppPage = .timetable
    @State private var editorMode: EditorMode?
    @State private var pendingFailRequest: RoutineFailRequest?

    var body: some View {
        TabView(selection: $selectedPage) {
            page(for: .timetable)
                .tabItem { Label(AppPage.timetable.title, systemImage: AppPage.timetable.symbolName) }
                .tag(AppPage.timetable)

            page(for: .tasks)
                .tabItem { Label(AppPage.tasks.title, systemImage: AppPage.tasks.symbolName) }
                .tag(AppPage.tasks)

            page(for: .routines)
                .tabItem { Label(AppPage.routines.title, systemImage: AppPage.routines.symbolName) }
                .tag(AppPage.routines)

            page(for: .streak)
                .tabItem { Label(AppPage.streak.title, systemImage: AppPage.streak.symbolName) }
                .tag(AppPage.streak)

            page(for: .settings)
                .tabItem { Label(AppPage.settings.title, systemImage: AppPage.settings.symbolName) }
                .tag(AppPage.settings)
        }
        .tint(MissionTheme.accent)
        .sheet(
            item: $editorMode,
            onDismiss: {
                saveAndUpdateWidgetSnapshot()
            }
        ) { mode in
            switch mode {
            case let .new(kind, initialDate):
                ScheduleItemEditorView(kind: kind, initialDate: initialDate)
            case let .edit(item):
                ScheduleItemEditorView(item: item)
            }
        }
        .confirmationDialog(
            "Why did this fail?",
            isPresented: failReasonDialogBinding,
            titleVisibility: .visible
        ) {
            ForEach(RoutineFailReason.allCases) { reason in
                Button(reason.title) {
                    resolvePendingFail(with: reason)
                }
            }

            Button("Fail without reason", role: .destructive) {
                resolvePendingFail(with: nil)
            }

            Button("Cancel", role: .cancel) {
                pendingFailRequest = nil
            }
        } message: {
            Text(pendingFailRequest?.routine.title ?? "Select a reason.")
        }
        .onAppear {
            checkNotificationPermissionOnLaunch()
            applyPendingWidgetRoutineOutcomes()
            saveAndUpdateWidgetSnapshot()
            syncRoutineNotifications()
        }
        .onChange(of: widgetSnapshotSignature) { _, _ in
            updateWidgetSnapshot(deferred: true)
        }
        .onChange(of: routineNotificationSignature) { _, _ in
            syncRoutineNotifications()
        }
        .onChange(of: notificationsEnabled) { _, _ in
            syncRoutineNotifications()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                applyPendingWidgetRoutineOutcomes()
            }

            if phase == .active || phase == .background {
                saveAndUpdateWidgetSnapshot(deferred: false)
            }
            if phase == .active {
                syncRoutineNotifications()
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    private var widgetSnapshotSignature: String {
        let itemSignature = items
            .map { item in
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
                    item.routineLabelRawValue ?? ""
                ].joined(separator: "|")
            }
            .joined(separator: ";")
        let stateSignature = routineStates
            .map { state in
                [
                    state.routineID.uuidString,
                    state.dayStart.timeIntervalSince1970.description,
                    state.statusRawValue,
                    state.failReasonRawValue ?? "",
                    state.delayMinutes.description
                ].joined(separator: "|")
            }
            .joined(separator: ";")

        return "\(itemSignature)#\(stateSignature)"
    }

    private var routineNotificationSignature: String {
        items
            .filter { $0.kind == .routine }
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
                    item.activeUntil?.timeIntervalSince1970.description ?? ""
                ].joined(separator: "|")
            }
            .joined(separator: ";")
    }

    private func saveAndUpdateWidgetSnapshot(deferred: Bool = false) {
        try? modelContext.save()
        updateWidgetSnapshot(deferred: deferred)
        syncRoutineNotifications()
    }

    private func checkNotificationPermissionOnLaunch() {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()

            switch settings.authorizationStatus {
            case .notDetermined:
                let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
                let updatedSettings = await center.notificationSettings()

                await MainActor.run {
                    notificationsEnabled = granted && updatedSettings.authorizationStatus.allowsLaunchNotifications
                }
            case .authorized, .provisional, .ephemeral:
                await MainActor.run {
                    if UserDefaults.standard.object(forKey: AppSettingsKey.notificationsEnabled) == nil {
                        notificationsEnabled = true
                    }
                }
            case .denied:
                await MainActor.run {
                    notificationsEnabled = false
                }
                await RoutineNotificationScheduler.shared.cancelRoutineNotifications()
            @unknown default:
                break
            }
        }
    }

    private func syncRoutineNotifications() {
        let schedules = items.compactMap(RoutineNotificationSchedule.init(item:))
        #if canImport(UIKit)
        let backgroundTaskID = scenePhase == .background
            ? UIApplication.shared.beginBackgroundTask(withName: "SyncRoutineNotifications", expirationHandler: nil)
            : UIBackgroundTaskIdentifier.invalid
        #endif

        Task {
            await RoutineNotificationScheduler.shared.syncNotifications(
                enabled: notificationsEnabled,
                for: schedules
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

    private func updateWidgetSnapshot(
        replacing updatedState: RoutineOccurrenceState? = nil,
        deferred: Bool = false
    ) {
        let writeSnapshot = {
            let states = routineStatesForWidget(replacing: updatedState)
            WidgetSnapshotWriter.save(items: itemsForWidgetSnapshot(), routineStates: states)
        }

        if deferred {
            DispatchQueue.main.async {
                writeSnapshot()
            }
        } else {
            writeSnapshot()
        }
    }

    @discardableResult
    private func upsertRoutineState(
        for routine: ScheduleItem,
        on date: Date,
        status: RoutineOccurrenceStatus,
        failReason: RoutineFailReason? = nil,
        updatesWidget: Bool = true
    ) -> RoutineOccurrenceState {
        let dayStart = Calendar.current.startOfDay(for: date)
        let existingStates = fetchedRoutineStates()
        let state = existingStates.state(for: routine, on: dayStart) ?? {
            let newState = RoutineOccurrenceState(routineID: routine.id, dayStart: dayStart)
            modelContext.insert(newState)
            return newState
        }()

        state.status = status
        state.failReason = status == .skipped ? failReason : nil
        try? modelContext.save()
        if updatesWidget {
            updateWidgetSnapshot(replacing: state)
        }
        return state
    }

    private var failReasonDialogBinding: Binding<Bool> {
        Binding {
            pendingFailRequest != nil
        } set: { isPresented in
            if !isPresented {
                pendingFailRequest = nil
            }
        }
    }

    private func resolvePendingFail(with reason: RoutineFailReason?) {
        guard let request = pendingFailRequest else {
            return
        }

        pendingFailRequest = nil
        upsertRoutineState(
            for: request.routine,
            on: request.date,
            status: .skipped,
            failReason: reason
        )
    }

    private func routineStatesForWidget(replacing updatedState: RoutineOccurrenceState?) -> [RoutineOccurrenceState] {
        let states = fetchedRoutineStates()

        guard let updatedState else {
            return states
        }

        return states.filter { state in
            state.routineID != updatedState.routineID
                || !Calendar.current.isDate(state.dayStart, inSameDayAs: updatedState.dayStart)
        } + [updatedState]
    }

    private func itemsForWidgetSnapshot() -> [ScheduleItem] {
        let descriptor = FetchDescriptor<ScheduleItem>()
        return (try? modelContext.fetch(descriptor)) ?? items
    }

    private func fetchedRoutineStates() -> [RoutineOccurrenceState] {
        let descriptor = FetchDescriptor<RoutineOccurrenceState>()
        return (try? modelContext.fetch(descriptor)) ?? routineStates
    }

    private func applyPendingWidgetRoutineOutcomes() {
        let commands = WidgetSnapshotStore.consumePendingRoutineOutcomes()
        guard !commands.isEmpty else {
            return
        }

        let routines = itemsForWidgetSnapshot().filter { $0.kind == .routine }

        for command in commands {
            guard let routine = routines.first(where: { $0.id == command.routineID }) else {
                continue
            }

            let status: RoutineOccurrenceStatus
            switch command.outcome {
            case .success:
                status = .done
            case .fail:
                status = .skipped
            case .pending:
                continue
            }

            upsertRoutineState(
                for: routine,
                on: command.occurredAt,
                status: status,
                updatesWidget: false
            )
        }

        try? modelContext.save()
        updateWidgetSnapshot()
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == "one" else {
            return
        }

        switch url.host?.lowercased() {
        case "calendar", "timetable":
            selectedPage = .timetable
            applyWidgetOutcomeIfNeeded(from: url)
        case "tasks":
            selectedPage = .tasks
        case "routines":
            selectedPage = .routines
        case "streak":
            selectedPage = .streak
        case "settings":
            selectedPage = .settings
        default:
            selectedPage = .timetable
        }
    }

    private func applyWidgetOutcomeIfNeeded(from url: URL) {
        guard
            let outcomeValue = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "outcome" })?
                .value?
                .lowercased()
        else {
            return
        }

        let status: RoutineOccurrenceStatus
        switch outcomeValue {
        case "success":
            status = .done
        case "fail":
            status = .skipped
        default:
            return
        }

        guard let routine = routineForWidgetOutcome() else {
            return
        }

        upsertRoutineState(for: routine, on: .now, status: status)
    }

    private func routineForWidgetOutcome(now: Date = .now, calendar: Calendar = .current) -> ScheduleItem? {
        let today = calendar.startOfDay(for: now)
        let currentMinute = calendar.minuteOfDay(for: now)
        let candidates: [(routine: ScheduleItem, startMinute: Int, endMinute: Int)] = items
            .routines(on: today, calendar: calendar)
            .compactMap { routine in
                let state = routineStates.state(for: routine, on: today, calendar: calendar)
                guard state?.isResolved != true else {
                    return nil
                }

                let delayMinutes = state?.delayMinutes ?? 0
                let startMinute = calendar.minuteOfDay(for: routine.startTime ?? today) + delayMinutes
                let endMinute = startMinute + max(5, routine.durationMinutes(calendar: calendar))
                return (routine, startMinute, endMinute)
            }

        if let active = candidates
            .filter({ $0.startMinute <= currentMinute && currentMinute < $0.endMinute })
            .min(by: { $0.endMinute < $1.endMinute }) {
            return active.routine
        }

        return candidates
            .filter { $0.endMinute <= currentMinute }
            .max(by: { $0.endMinute < $1.endMinute })?
            .routine
    }

    @ViewBuilder
    private func page(for page: AppPage) -> some View {
        NavigationStack {
            pageContent(for: page)
                .background(MissionTheme.appBackground)
                .navigationTitle(page.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if page == .routines {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                editorMode = .new(.routine, nil)
                            } label: {
                                Image(systemName: "plus")
                            }
                            .accessibilityLabel("Add routine")
                        }
                    }
                }
                .toolbar(page == .timetable ? .hidden : .visible, for: .navigationBar)
        }
    }

    @ViewBuilder
    private func pageContent(for page: AppPage) -> some View {
        switch page {
        case .timetable:
            TimetablePageView(
                items: items,
                routineStates: routineStates,
                onAddRoutine: { editorMode = .new(.routine, $0) },
                onEdit: { editorMode = .edit($0) },
                onMarkRoutineDone: { routine, date in
                    upsertRoutineState(for: routine, on: date, status: .done)
                },
                onSkipRoutine: { routine, date in
                    pendingFailRequest = RoutineFailRequest(routine: routine, date: date)
                }
            )
        case .tasks:
            TasksPageView(
                items: items,
                onItemsChanged: {
                    saveAndUpdateWidgetSnapshot()
                }
            )
        case .routines:
            RoutinePlannerPageView(
                items: items,
                onEdit: { editorMode = .edit($0) }
            )
        case .streak:
            StreakPageView(
                items: items,
                routineStates: routineStates
            )
        case .settings:
            SettingsPageView()
        }
    }
}

private enum EditorMode: Identifiable {
    case new(ScheduleKind, Date?)
    case edit(ScheduleItem)

    var id: String {
        switch self {
        case let .new(kind, initialDate):
            "new-\(kind.rawValue)-\(initialDate?.timeIntervalSince1970.description ?? "default")"
        case let .edit(item):
            "edit-\(item.id.uuidString)"
        }
    }
}

private struct RoutineFailRequest: Identifiable {
    let id = UUID()
    let routine: ScheduleItem
    let date: Date
}

#Preview {
    RootView()
        .modelContainer(for: [ScheduleItem.self, RoutineOccurrenceState.self], inMemory: true)
}

private extension UNAuthorizationStatus {
    var allowsLaunchNotifications: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            true
        case .notDetermined, .denied:
            false
        @unknown default:
            false
        }
    }
}
