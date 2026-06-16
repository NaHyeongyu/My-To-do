import SwiftData
import SwiftUI

struct ScheduleItemEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let item: ScheduleItem?
    private let kind: ScheduleKind
    private let isDateAnchoredRoutine: Bool

    @State private var title: String
    @State private var notes: String
    @State private var taskDate: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var repeatWeekdayMask: Int
    @State private var routineLabel: RoutineLabel?
    @State private var showsDeleteConfirmation = false

    init(item: ScheduleItem? = nil, kind: ScheduleKind = .task, initialDate: Date? = nil) {
        let editorKind = item?.kind ?? kind
        self.item = item
        self.kind = editorKind
        self.isDateAnchoredRoutine = editorKind == .routine && (item?.taskDate != nil || initialDate != nil)

        let now = Date.now
        let calendar = Calendar.current
        let defaultStart = calendar.dateBySnappingToFiveMinute(now)
        let defaultEnd = calendar.date(byAdding: .hour, value: 1, to: defaultStart) ?? defaultStart
        let defaultRepeatWeekdayMask: Int
        if let initialDate, editorKind == .routine {
            defaultRepeatWeekdayMask = RepeatWeekday.current(date: initialDate).bit
        } else {
            defaultRepeatWeekdayMask = RepeatWeekdayMask.everyDay
        }

        _title = State(initialValue: item?.title ?? "")
        _notes = State(initialValue: item?.notes ?? "")
        _taskDate = State(initialValue: item?.taskDate ?? initialDate ?? now)
        _startTime = State(initialValue: calendar.dateBySnappingToFiveMinute(item?.startTime ?? defaultStart))
        _endTime = State(initialValue: calendar.dateBySnappingToFiveMinute(item?.endTime ?? defaultEnd))
        _repeatWeekdayMask = State(initialValue: item?.repeatWeekdayMask ?? defaultRepeatWeekdayMask)
        _routineLabel = State(initialValue: item?.routineLabel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(kind == .routine ? "Routine title" : "Task title", text: $title)
                        .font(.body)
                        .submitLabel(.done)

                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                        .foregroundStyle(MissionTheme.secondaryText)
                }

                switch kind {
                case .routine:
                    routineLabelSection
                    routineSection
                    if !isDateAnchoredRoutine {
                        repeatSection
                    }
                case .task:
                    taskSection
                }

                if canDeleteRoutine {
                    deleteRoutineSection
                }
            }
            .formStyle(.grouped)
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .tint(MissionTheme.accent)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        Text("Done")
                            .fontWeight(.semibold)
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .confirmationDialog(
            "Delete Routine?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Routine", role: .destructive) {
                deleteRoutine()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the routine and its check-in history.")
        }
    }

    private var routineSection: some View {
        Section("Time") {
            FiveMinuteTimePickerRow(title: "Start", selection: $startTime)
            FiveMinuteTimePickerRow(title: "End", selection: $endTime)

            if routineEndsNextDay {
                Text("Ends next day.")
                    .font(.footnote)
                    .foregroundStyle(MissionTheme.secondaryText)
            }
        }
    }

    private var routineLabelSection: some View {
        Section("Label") {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(RoutineLabel.allCases) { label in
                    Button {
                        withAnimation(.snappy(duration: 0.18)) {
                            routineLabel = routineLabel == label ? nil : label
                        }
                    } label: {
                        RoutineLabelBadge(label: label, isSelected: routineLabel == label)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(routineLabel == label ? .isSelected : [])
                }
            }
        }
    }

    private var repeatSection: some View {
        Section("Repeat Days") {
            WeekdaySelectionRow(mask: $repeatWeekdayMask)

            if repeatWeekdayMask == 0 {
                Text("Select at least one repeat day.")
                    .font(.footnote)
                    .foregroundStyle(MissionTheme.danger)
            }
        }
    }

    private var taskSection: some View {
        Section {
            DatePicker("Date", selection: $taskDate, displayedComponents: [.date])
        }
    }

    private var deleteRoutineSection: some View {
        Section {
            Button(role: .destructive) {
                showsDeleteConfirmation = true
            } label: {
                Label("Delete Routine", systemImage: "trash")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var navigationTitle: String {
        if item == nil {
            return kind == .routine ? "New Routine" : "New Task"
        }

        return kind == .routine ? "Edit Routine" : "Edit Task"
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNotes: String {
        notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasValidRoutineTime: Bool {
        let calendar = Calendar.current
        let snappedStartTime = calendar.dateBySnappingToFiveMinute(startTime)
        let snappedEndTime = calendar.dateBySnappingToFiveMinute(endTime)
        return ScheduleItem.durationMinutes(
            startTime: snappedStartTime,
            endTime: snappedEndTime,
            calendar: calendar
        ) > 0
    }

    private var routineEndsNextDay: Bool {
        let calendar = Calendar.current
        let snappedStartTime = calendar.dateBySnappingToFiveMinute(startTime)
        let snappedEndTime = calendar.dateBySnappingToFiveMinute(endTime)
        return ScheduleItem.crossesMidnight(
            startTime: snappedStartTime,
            endTime: snappedEndTime,
            calendar: calendar
        )
    }

    private var isSaveDisabled: Bool {
        if trimmedTitle.isEmpty {
            return true
        }

        if kind == .routine {
            return !hasValidRoutineTime || (!isDateAnchoredRoutine && repeatWeekdayMask == 0)
        }

        return false
    }

    private var canDeleteRoutine: Bool {
        item?.kind == .routine
    }

    private func save() {
        let calendar = Calendar.current
        let snappedStartTime = calendar.dateBySnappingToFiveMinute(startTime)
        let snappedEndTime = calendar.dateBySnappingToFiveMinute(endTime)
        let routineDate = isDateAnchoredRoutine ? taskDate : nil
        let routineRepeatWeekdayMask = isDateAnchoredRoutine
            ? 0
            : (repeatWeekdayMask == 0 ? RepeatWeekdayMask.everyDay : repeatWeekdayMask)
        let todayStart = calendar.startOfDay(for: .now)

        if let item {
            if shouldCreateRoutineVersion(for: item, todayStart: todayStart, calendar: calendar) {
                item.activeUntil = todayStart

                let newItem = ScheduleItem(
                    kind: .routine,
                    title: trimmedTitle,
                    notes: trimmedNotes,
                    taskDate: nil,
                    startTime: snappedStartTime,
                    endTime: snappedEndTime,
                    repeatWeekdayMask: routineRepeatWeekdayMask,
                    activeFrom: todayStart,
                    routineLabel: routineLabel
                )
                modelContext.insert(newItem)
                moveCurrentRoutineStates(from: item.id, to: newItem.id, startingAt: todayStart)
            } else {
                item.kind = kind
                item.title = trimmedTitle
                item.notes = trimmedNotes

                switch kind {
                case .routine:
                    item.taskDate = routineDate
                    item.completedAt = nil
                    item.startTime = snappedStartTime
                    item.endTime = snappedEndTime
                    item.repeatWeekdayMask = routineRepeatWeekdayMask
                    item.activeFrom = routineDate == nil ? (item.activeFrom ?? todayStart) : nil
                    item.activeUntil = nil
                    item.routineLabel = routineLabel
                case .task:
                    item.taskDate = taskDate
                    item.startTime = nil
                    item.endTime = nil
                    item.repeatWeekdayMask = 0
                    item.activeFrom = nil
                    item.activeUntil = nil
                    item.routineLabelRawValue = nil
                }
            }
        } else {
            let newItem = ScheduleItem(
                kind: kind,
                title: trimmedTitle,
                notes: trimmedNotes,
                taskDate: kind == .task ? taskDate : routineDate,
                startTime: kind == .routine ? snappedStartTime : nil,
                endTime: kind == .routine ? snappedEndTime : nil,
                repeatWeekdayMask: kind == .routine ? routineRepeatWeekdayMask : 0,
                activeFrom: kind == .routine && routineDate == nil ? todayStart : nil,
                routineLabel: kind == .routine ? routineLabel : nil
            )
            modelContext.insert(newItem)
        }

        try? modelContext.save()
        dismiss()
    }

    private func shouldCreateRoutineVersion(
        for item: ScheduleItem,
        todayStart: Date,
        calendar: Calendar
    ) -> Bool {
        guard kind == .routine, !isDateAnchoredRoutine, item.taskDate == nil else {
            return false
        }

        guard let activeFrom = item.activeFrom else {
            return true
        }

        return calendar.startOfDay(for: activeFrom) < todayStart
    }

    private func moveCurrentRoutineStates(from oldID: UUID, to newID: UUID, startingAt dayStart: Date) {
        let descriptor = FetchDescriptor<RoutineOccurrenceState>()
        guard let states = try? modelContext.fetch(descriptor) else {
            return
        }

        for state in states where state.routineID == oldID && state.dayStart >= dayStart {
            state.routineID = newID
        }
    }

    private func deleteRoutine() {
        guard let item, item.kind == .routine else {
            return
        }

        deleteRoutineStates(for: item.id)
        modelContext.delete(item)
        try? modelContext.save()
        dismiss()
    }

    private func deleteRoutineStates(for routineID: UUID) {
        let descriptor = FetchDescriptor<RoutineOccurrenceState>()
        guard let states = try? modelContext.fetch(descriptor) else {
            return
        }

        for state in states where state.routineID == routineID {
            modelContext.delete(state)
        }
    }
}

#Preview {
    ScheduleItemEditorView(kind: .routine)
        .modelContainer(for: [ScheduleItem.self, RoutineOccurrenceState.self], inMemory: true)
}
