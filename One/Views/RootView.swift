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
            syncRoutineNotificationsIfAuthorized()
        }
        .onChange(of: widgetSnapshotSignature) { _, _ in
            updateWidgetSnapshot()
        }
        .onChange(of: routineNotificationSignature) { _, _ in
            syncRoutineNotificationsIfAuthorized()
        }
    }

    private var widgetSnapshotSignature: String {
        items
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
                    item.repeatWeekdayMask.description
                ].joined(separator: "|")
            }
            .joined(separator: ";")
    }

    private func updateWidgetSnapshot() {
        WidgetSnapshotWriter.save(items: items)
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
                    item.repeatWeekdayMask.description
                ].joined(separator: "|")
            }
            .joined(separator: ";")
    }

    private func syncRoutineNotificationsIfAuthorized() {
        let schedules = items.compactMap(RoutineNotificationSchedule.init(item:))

        Task {
            await RoutineNotificationScheduler.shared.syncNotificationsIfAuthorized(for: schedules)
        }
    }

    private func upsertRoutineState(
        for routine: ScheduleItem,
        on date: Date,
        status: RoutineOccurrenceStatus
    ) {
        let dayStart = Calendar.current.startOfDay(for: date)
        let state = routineStates.state(for: routine, on: dayStart) ?? {
            let newState = RoutineOccurrenceState(routineID: routine.id, dayStart: dayStart)
            modelContext.insert(newState)
            return newState
        }()

        state.status = status
        try? modelContext.save()
    }

    private func delayRoutine(_ routine: ScheduleItem, on date: Date, by minutes: Int) {
        let dayStart = Calendar.current.startOfDay(for: date)
        let state = routineStates.state(for: routine, on: dayStart) ?? {
            let newState = RoutineOccurrenceState(routineID: routine.id, dayStart: dayStart)
            modelContext.insert(newState)
            return newState
        }()

        state.status = .pending
        state.delayMinutes = min(180, max(0, state.delayMinutes + minutes))
        state.updatedAt = .now
        try? modelContext.save()
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
                },
                onDelayRoutine: { routine, date in
                    delayRoutine(routine, on: date, by: 10)
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
