import SwiftData
import SwiftUI
import UserNotifications

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
        .dialogBackdrop(isPresented: pendingFailRequest != nil)
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
            case let .editOccurrence(item, date):
                ScheduleItemEditorView(item: item, occurrenceDate: date)
            }
        }
        .confirmationDialog(
            "Failure reason",
            isPresented: failReasonDialogBinding,
            titleVisibility: .visible
        ) {
            ForEach(RoutineFailReason.allCases) { reason in
                Button(reason.title) {
                    resolvePendingFail(with: reason)
                }
            }

            Button("Fail without reason") {
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
            saveAndUpdateWidgetSnapshot(syncNotifications: false)
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
        AppDataSyncService.widgetSnapshotSignature(items: items, routineStates: routineStates)
    }

    private var routineNotificationSignature: String {
        AppDataSyncService.routineNotificationSignature(items: items, routineStates: routineStates)
    }

    private func saveAndUpdateWidgetSnapshot(
        deferred: Bool = false,
        syncNotifications shouldSyncNotifications: Bool = true
    ) {
        AppDataSyncService.saveAndSync(
            modelContext: modelContext,
            queryItems: items,
            queryRoutineStates: routineStates,
            notificationsEnabled: notificationsEnabled,
            scenePhase: scenePhase,
            deferredWidget: deferred,
            syncNotifications: shouldSyncNotifications
        )
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
                    UserDefaults.standard.set(true, forKey: AppSettingsKey.notificationPreferenceReconciled)
                    syncRoutineNotifications()
                }
            case .authorized, .provisional, .ephemeral:
                await MainActor.run {
                    let defaults = UserDefaults.standard
                    let hasStoredPreference = defaults.object(forKey: AppSettingsKey.notificationsEnabled) != nil
                    let hasReconciledPreference = defaults.bool(forKey: AppSettingsKey.notificationPreferenceReconciled)
                    if !hasStoredPreference || !hasReconciledPreference {
                        notificationsEnabled = true
                        defaults.set(true, forKey: AppSettingsKey.notificationPreferenceReconciled)
                    }
                    syncRoutineNotifications()
                }
            case .denied:
                await MainActor.run {
                    notificationsEnabled = false
                    UserDefaults.standard.set(true, forKey: AppSettingsKey.notificationPreferenceReconciled)
                }
                await RoutineNotificationScheduler.shared.cancelRoutineNotifications()
            @unknown default:
                break
            }
        }
    }

    private func syncRoutineNotifications() {
        AppDataSyncService.syncRoutineNotifications(
            enabled: notificationsEnabled,
            items: items,
            routineStates: routineStates,
            scenePhase: scenePhase
        )
    }

    private func updateWidgetSnapshot(
        replacing updatedState: RoutineOccurrenceState? = nil,
        deferred: Bool = false
    ) {
        AppDataSyncService.updateWidgetSnapshot(
            modelContext: modelContext,
            queryItems: items,
            queryRoutineStates: routineStates,
            replacing: updatedState,
            deferred: deferred
        )
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

    private func moveRoutine(_ routine: ScheduleItem, on date: Date, toStartMinute startMinute: Int) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let durationMinutes = max(5, routine.durationMinutes(calendar: calendar))
        let latestStartMinute = max(0, ScheduleItem.minutesPerDay - durationMinutes)
        let normalizedStartMinute = min(latestStartMinute, max(0, startMinute))
        let newStartTime = calendar.date(byAdding: .minute, value: normalizedStartMinute, to: dayStart) ?? dayStart
        let newEndTime = calendar.date(byAdding: .minute, value: normalizedStartMinute + durationMinutes, to: dayStart) ?? newStartTime

        if routine.taskDate != nil {
            routine.taskDate = dayStart
            routine.startTime = newStartTime
            routine.endTime = newEndTime
            routine.activeFrom = nil
            routine.activeUntil = nil
            resetRoutineDelay(for: routine.id, on: dayStart)
            saveAndUpdateWidgetSnapshot()
            return
        }

        let existingOccurrence = existingRoutineOccurrenceOverride(for: routine.id, on: dayStart)
        let occurrence = existingOccurrence
            ?? ScheduleItem(
                kind: .routine,
                title: routine.title,
                notes: routine.notes,
                taskDate: dayStart,
                startTime: newStartTime,
                endTime: newEndTime,
                repeatWeekdayMask: 0,
                routineLabelRawValue: routine.routineLabelRawValue,
                routineVersionsRawValue: routine.routineVersionsRawValue,
                sourceRoutineID: routine.id
            )

        if existingOccurrence == nil {
            modelContext.insert(occurrence)
        }

        occurrence.kind = .routine
        occurrence.title = routine.title
        occurrence.notes = routine.notes
        occurrence.taskDate = dayStart
        occurrence.startTime = newStartTime
        occurrence.endTime = newEndTime
        occurrence.repeatWeekdayMask = 0
        occurrence.activeFrom = nil
        occurrence.activeUntil = nil
        occurrence.routineLabelRawValue = routine.routineLabelRawValue
        occurrence.routineVersionsRawValue = routine.routineVersionsRawValue
        occurrence.sourceRoutineID = routine.id

        moveRoutineState(from: routine.id, to: occurrence.id, on: dayStart)
        resetRoutineDelay(for: occurrence.id, on: dayStart)
        saveAndUpdateWidgetSnapshot()
    }

    private func existingRoutineOccurrenceOverride(for sourceRoutineID: UUID, on dayStart: Date) -> ScheduleItem? {
        itemsForWidgetSnapshot().first { candidate in
            candidate.kind == .routine
                && candidate.sourceRoutineID == sourceRoutineID
                && candidate.taskDate.map { Calendar.current.isDate($0, inSameDayAs: dayStart) } == true
        }
    }

    private func moveRoutineState(from oldID: UUID, to newID: UUID, on dayStart: Date) {
        for state in fetchedRoutineStates()
            where state.routineID == oldID && Calendar.current.isDate(state.dayStart, inSameDayAs: dayStart) {
            state.routineID = newID
            state.delayMinutes = 0
            state.isHidden = false
            state.updatedAt = .now
        }
    }

    private func resetRoutineDelay(for routineID: UUID, on dayStart: Date) {
        for state in fetchedRoutineStates()
            where state.routineID == routineID && Calendar.current.isDate(state.dayStart, inSameDayAs: dayStart) {
            state.delayMinutes = 0
            state.updatedAt = .now
        }
    }

    private func itemsForWidgetSnapshot() -> [ScheduleItem] {
        AppDataSyncService.fetchedItems(modelContext: modelContext, fallback: items)
    }

    private func fetchedRoutineStates() -> [RoutineOccurrenceState] {
        AppDataSyncService.fetchedRoutineStates(modelContext: modelContext, fallback: routineStates)
    }

    private func applyPendingWidgetRoutineOutcomes() {
        let commands = WidgetSnapshotStore.consumePendingRoutineOutcomes()
        guard !commands.isEmpty else {
            return
        }

        let snapshotItems = itemsForWidgetSnapshot()
        let states = fetchedRoutineStates()

        for command in commands {
            let routines = snapshotItems.routines(
                on: command.occurredAt,
                routineStates: states,
                calendar: .current
            )
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
            .routines(on: today, routineStates: routineStates, calendar: calendar)
            .compactMap { routine in
                let state = routineStates.state(for: routine, on: today, calendar: calendar)
                guard state?.isResolved != true else {
                    return nil
                }

                let delayMinutes = state?.delayMinutes ?? 0
                let startMinute = calendar.minuteOfDay(for: routine.startTime ?? today) + delayMinutes
                let endMinute = startMinute + max(5, routine.plannedDurationMinutes(state: state, calendar: calendar))
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
                onEdit: { routine, date in
                    editorMode = .editOccurrence(routine, date)
                },
                onMoveRoutine: { routine, date, startMinute in
                    moveRoutine(routine, on: date, toStartMinute: startMinute)
                },
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
                onEdit: { editorMode = .edit($0) },
                onItemsChanged: {
                    saveAndUpdateWidgetSnapshot()
                }
            )
        case .routines:
            RoutinePlannerPageView(
                items: items,
                onAdd: { weekday in
                    editorMode = .new(.routine, nextDate(for: weekday))
                },
                onEdit: { editorMode = .edit($0) },
                onDuplicate: duplicateRoutine,
                onPause: pauseRoutine,
                onDelete: deleteRoutine
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

    private func nextDate(for weekday: RepeatWeekday) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let currentWeekday = calendar.component(.weekday, from: today)
        let offset = (weekday.rawValue - currentWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: offset, to: today) ?? today
    }

    private func duplicateRoutine(_ routine: ScheduleItem) {
        let duplicate = ScheduleItem(
            kind: .routine,
            title: "\(routine.title) Copy",
            notes: routine.notes,
            taskDate: routine.taskDate,
            startTime: routine.startTime,
            endTime: routine.endTime,
            repeatWeekdayMask: routine.repeatWeekdayMask,
            activeFrom: routine.activeFrom,
            activeUntil: routine.activeUntil,
            routineLabelRawValue: routine.routineLabelRawValue,
            routineVersionsRawValue: routine.routineVersionsRawValue,
            sourceRoutineID: routine.sourceRoutineID
        )

        modelContext.insert(duplicate)
        saveAndUpdateWidgetSnapshot()
    }

    private func pauseRoutine(_ routine: ScheduleItem, weekday: RepeatWeekday) {
        guard routine.taskDate == nil else {
            modelContext.delete(routine)
            saveAndUpdateWidgetSnapshot()
            return
        }

        routine.repeatWeekdayMask = routine.repeatWeekdayMask & ~weekday.bit
        saveAndUpdateWidgetSnapshot()
    }

    private func deleteRoutine(_ routine: ScheduleItem) {
        modelContext.delete(routine)
        saveAndUpdateWidgetSnapshot()
    }
}

private enum EditorMode: Identifiable {
    case new(ScheduleKind, Date?)
    case edit(ScheduleItem)
    case editOccurrence(ScheduleItem, Date)

    var id: String {
        switch self {
        case let .new(kind, initialDate):
            "new-\(kind.rawValue)-\(initialDate?.timeIntervalSince1970.description ?? "default")"
        case let .edit(item):
            "edit-\(item.id.uuidString)"
        case let .editOccurrence(item, date):
            "edit-occurrence-\(item.id.uuidString)-\(date.timeIntervalSince1970)"
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
