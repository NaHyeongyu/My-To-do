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
    @State private var routineLabelRawValue: String?
    @State private var routineVersions: [RoutineVersion]
    @State private var showsDeleteConfirmation = false

    @AppStorage(AppSettingsKey.customRoutineLabels) private var customRoutineLabelsRaw = CustomRoutineLabelStore.emptyStorage

    init(item: ScheduleItem? = nil, kind: ScheduleKind = .task, initialDate: Date? = nil) {
        let editorKind = item?.kind ?? kind
        self.item = item
        self.kind = editorKind
        self.isDateAnchoredRoutine = editorKind == .routine && (item?.taskDate != nil || initialDate != nil)

        let now = Date.now
        let calendar = Calendar.current
        let defaultStart = calendar.dateBySnappingToFiveMinute(now)
        let defaultEnd = calendar.date(byAdding: .hour, value: 1, to: defaultStart) ?? defaultStart
        let initialStartTime = calendar.dateBySnappingToFiveMinute(item?.startTime ?? defaultStart)
        let initialEndTime = calendar.dateBySnappingToFiveMinute(item?.endTime ?? defaultEnd)
        let initialRoutineDuration = ScheduleItem.durationMinutes(
            startTime: initialStartTime,
            endTime: initialEndTime,
            calendar: calendar
        )
        let defaultRepeatWeekdayMask: Int
        if let initialDate, editorKind == .routine {
            defaultRepeatWeekdayMask = RepeatWeekday.current(date: initialDate).bit
        } else {
            defaultRepeatWeekdayMask = RepeatWeekdayMask.everyDay
        }

        _title = State(initialValue: item?.title ?? "")
        _notes = State(initialValue: item?.notes ?? "")
        _taskDate = State(initialValue: item?.taskDate ?? initialDate ?? now)
        _startTime = State(initialValue: initialStartTime)
        _endTime = State(initialValue: initialEndTime)
        _repeatWeekdayMask = State(initialValue: item?.repeatWeekdayMask ?? defaultRepeatWeekdayMask)
        _routineLabelRawValue = State(initialValue: item?.routineLabelRawValue)
        _routineVersions = State(
            initialValue: editorKind == .routine
                ? (item?.routineVersionOptions(calendar: calendar) ?? RoutineVersionStore.defaultVersions(for: initialRoutineDuration))
                : []
        )
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
                    routineVersionsSection
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

    private var routineVersionsSection: some View {
        Section("Versions") {
            ForEach($routineVersions) { $version in
                RoutineVersionEditorRow(
                    version: $version,
                    baseDurationMinutes: currentRoutineDurationMinutes,
                    canDelete: version.id != RoutineVersion.standardID && routineVersions.count > 1
                ) {
                    deleteRoutineVersion(id: version.id)
                }
            }

            Button {
                addRoutineVersion()
            } label: {
                Label("Add Version", systemImage: "plus")
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
                ForEach(routineLabelOptions) { label in
                    Button {
                        withAnimation(.snappy(duration: 0.18)) {
                            routineLabelRawValue = routineLabelRawValue == label.rawValue ? nil : label.rawValue
                        }
                    } label: {
                        RoutineLabelBadge(label: label, isSelected: routineLabelRawValue == label.rawValue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(routineLabelRawValue == label.rawValue ? .isSelected : [])
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
        currentRoutineDurationMinutes > 0
    }

    private var currentRoutineDurationMinutes: Int {
        let calendar = Calendar.current
        let snappedStartTime = calendar.dateBySnappingToFiveMinute(startTime)
        let snappedEndTime = calendar.dateBySnappingToFiveMinute(endTime)
        return ScheduleItem.durationMinutes(
            startTime: snappedStartTime,
            endTime: snappedEndTime,
            calendar: calendar
        )
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

    private var customRoutineLabels: [CustomRoutineLabel] {
        CustomRoutineLabelStore.labels(from: customRoutineLabelsRaw)
    }

    private var routineLabelOptions: [RoutineLabelOption] {
        RoutineLabelOption.options(customLabels: customRoutineLabels)
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
        let savedRoutineVersions = kind == .routine
            ? normalizedRoutineVersions(fallbackDuration: currentRoutineDurationMinutes)
            : []

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
                    routineLabelRawValue: routineLabelRawValue
                )
                newItem.routineVersions = savedRoutineVersions
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
                    item.routineLabelRawValue = routineLabelRawValue
                    item.routineVersions = savedRoutineVersions
                case .task:
                    item.taskDate = taskDate
                    item.startTime = nil
                    item.endTime = nil
                    item.repeatWeekdayMask = 0
                    item.activeFrom = nil
                    item.activeUntil = nil
                    item.routineLabelRawValue = nil
                    item.routineVersionsRawValue = ""
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
                routineLabelRawValue: kind == .routine ? routineLabelRawValue : nil
            )
            if kind == .routine {
                newItem.routineVersions = savedRoutineVersions
            }
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

    private func normalizedRoutineVersions(fallbackDuration: Int) -> [RoutineVersion] {
        RoutineVersionStore.normalizedVersions(routineVersions, fallbackDuration: max(5, fallbackDuration))
    }

    private func addRoutineVersion() {
        let title = "Version \(routineVersions.count + 1)"
        let minutes = max(5, currentRoutineDurationMinutes)

        withAnimation(.snappy(duration: 0.18)) {
            routineVersions.append(RoutineVersion(title: title, durationMinutes: minutes))
        }
    }

    private func deleteRoutineVersion(id: String) {
        guard id != RoutineVersion.standardID, routineVersions.count > 1 else {
            return
        }

        withAnimation(.snappy(duration: 0.18)) {
            routineVersions.removeAll { $0.id == id }
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

private struct RoutineVersionEditorRow: View {
    @Binding var version: RoutineVersion

    let baseDurationMinutes: Int
    let canDelete: Bool
    let onDelete: () -> Void

    private var isStandardVersion: Bool {
        version.id == RoutineVersion.standardID
    }

    private var displayedDurationMinutes: Int {
        isStandardVersion ? max(5, baseDurationMinutes) : version.durationMinutes
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                TextField("Version", text: $version.title)
                    .font(.body)
                    .submitLabel(.done)

                Text(displayedDurationMinutes.readableDuration)
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .foregroundStyle(MissionTheme.secondaryText)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                if canDelete {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Delete version")
                }
            }

            if !isStandardVersion {
                Stepper(
                    value: $version.durationMinutes,
                    in: 5...ScheduleItem.minutesPerDay,
                    step: 5
                ) {
                    Label("Duration", systemImage: "clock")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(MissionTheme.secondaryText)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ScheduleItemEditorView(kind: .routine)
        .modelContainer(for: [ScheduleItem.self, RoutineOccurrenceState.self], inMemory: true)
}
