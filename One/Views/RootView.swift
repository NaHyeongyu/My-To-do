import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ScheduleItem.createdAt, order: .reverse) private var items: [ScheduleItem]
    @Query(sort: \RoutineOccurrenceState.updatedAt, order: .reverse) private var routineStates: [RoutineOccurrenceState]

    @State private var selectedPage: AppPage = .timetable
    @State private var editorMode: EditorMode?

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
        .sheet(item: $editorMode) { mode in
            switch mode {
            case let .new(kind, initialDate):
                ScheduleItemEditorView(kind: kind, initialDate: initialDate)
            case let .edit(item):
                ScheduleItemEditorView(item: item)
            }
        }
        .onAppear {
            updateWidgetSnapshot()
        }
        .onChange(of: widgetSnapshotSignature) { _, _ in
            updateWidgetSnapshot()
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
                    item.activeUntil?.timeIntervalSince1970.description ?? ""
                ].joined(separator: "|")
            }
            .joined(separator: ";")
        let stateSignature = routineStates
            .map { state in
                [
                    state.routineID.uuidString,
                    state.dayStart.timeIntervalSince1970.description,
                    state.statusRawValue,
                    state.delayMinutes.description
                ].joined(separator: "|")
            }
            .joined(separator: ";")

        return "\(itemSignature)#\(stateSignature)"
    }

    private func updateWidgetSnapshot(replacing updatedState: RoutineOccurrenceState? = nil) {
        let states = routineStatesForWidget(replacing: updatedState)
        WidgetSnapshotWriter.save(items: items, routineStates: states)
    }

    @discardableResult
    private func upsertRoutineState(
        for routine: ScheduleItem,
        on date: Date,
        status: RoutineOccurrenceStatus
    ) -> RoutineOccurrenceState {
        let dayStart = Calendar.current.startOfDay(for: date)
        let state = routineStates.state(for: routine, on: dayStart) ?? {
            let newState = RoutineOccurrenceState(routineID: routine.id, dayStart: dayStart)
            modelContext.insert(newState)
            return newState
        }()

        state.status = status
        try? modelContext.save()
        updateWidgetSnapshot(replacing: state)
        return state
    }

    private func routineStatesForWidget(replacing updatedState: RoutineOccurrenceState?) -> [RoutineOccurrenceState] {
        guard let updatedState else {
            return routineStates
        }

        return routineStates.filter { state in
            state.routineID != updatedState.routineID
                || !Calendar.current.isDate(state.dayStart, inSameDayAs: updatedState.dayStart)
        } + [updatedState]
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
                    upsertRoutineState(for: routine, on: date, status: .skipped)
                }
            )
        case .tasks:
            TasksPageView(
                items: items
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

#Preview {
    RootView()
        .modelContainer(for: [ScheduleItem.self, RoutineOccurrenceState.self], inMemory: true)
}
