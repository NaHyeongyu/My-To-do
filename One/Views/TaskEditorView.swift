import SwiftData
import SwiftUI

struct ScheduleItemEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let item: ScheduleItem?
    private let kind: ScheduleKind
    private let isDateAnchoredRoutine: Bool
    private let occurrenceDate: Date?
    private let editsRoutineOccurrenceOnly: Bool

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

    init(
        item: ScheduleItem? = nil,
        kind: ScheduleKind = .task,
        initialDate: Date? = nil,
        occurrenceDate: Date? = nil
    ) {
        let editorKind = item?.kind ?? kind
        self.item = item
        self.kind = editorKind
        self.occurrenceDate = occurrenceDate
        self.editsRoutineOccurrenceOnly = editorKind == .routine && item?.taskDate == nil && occurrenceDate != nil
        self.isDateAnchoredRoutine = editorKind == .routine && (item?.taskDate != nil || initialDate != nil || occurrenceDate != nil)

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
        _taskDate = State(initialValue: item?.taskDate ?? occurrenceDate ?? initialDate ?? now)
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
                    if !isDateAnchoredRoutine {
                        repeatSection
                    }
                    routineVersionsSection
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
        .dialogBackdrop(isPresented: showsDeleteConfirmation)
        .confirmationDialog(
            deleteDialogTitle,
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(deleteConfirmationActionTitle, role: .destructive) {
                deleteRoutine()
            }

            Button("Cancel", role: .cancel) {
                showsDeleteConfirmation = false
            }
        } message: {
            Text(deleteDialogMessage)
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
                    baseDurationMinutes: currentRoutineDurationMinutes
                )
            }
        }
    }

    private var routineLabelSection: some View {
        Section("Label") {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ],
                spacing: 8
            ) {
                ForEach(routineLabelOptions) { label in
                    Button {
                        withAnimation(.snappy(duration: 0.18)) {
                            routineLabelRawValue = routineLabelRawValue == label.rawValue ? nil : label.rawValue
                        }
                    } label: {
                        RoutineLabelBadge(
                            label: label,
                            isSelected: routineLabelRawValue == label.rawValue,
                            font: .caption.weight(.semibold),
                            iconSize: 12,
                            height: 34,
                            horizontalPadding: 8
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(routineLabelRawValue == label.rawValue ? .isSelected : [])
                }
            }
        }
    }

    private var repeatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Repeat Days")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(MissionTheme.secondaryText)
                .textCase(.uppercase)

            WeekdaySelectionRow(mask: $repeatWeekdayMask)

            if repeatWeekdayMask == 0 {
                Text("Select at least one repeat day.")
                    .font(.footnote)
                    .foregroundStyle(MissionTheme.danger)
            }
        }
        .padding(.vertical, 8)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
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
                Label {
                    Text(deleteTriggerTitle)
                        .font(.body.weight(.semibold))
                } icon: {
                    Image(systemName: "trash.fill")
                        .font(.body.weight(.semibold))
                        .symbolRenderingMode(.hierarchical)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
            }
            .tint(MissionTheme.danger)
            .controlSize(.large)
            .missionLiquidButton()
            .accessibilityLabel(deleteTriggerTitle)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 10, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private var navigationTitle: String {
        if item == nil {
            return kind == .routine ? "New Routine" : "New Task"
        }

        if shouldScopeDeleteToOccurrence {
            return "Edit Today"
        }

        return kind == .routine ? "Edit Routine" : "Edit Task"
    }

    private var deleteDialogTitle: String {
        shouldScopeDeleteToOccurrence ? "Delete From Today?" : "Delete Routine?"
    }

    private var deleteTriggerTitle: String {
        shouldScopeDeleteToOccurrence ? "Delete From Today" : "Delete Routine"
    }

    private var deleteConfirmationActionTitle: String {
        shouldScopeDeleteToOccurrence ? "Delete From Today" : "Delete"
    }

    private var deleteDialogMessage: String {
        shouldScopeDeleteToOccurrence
            ? "This deletes only today's routine entry. The repeating routine stays unchanged."
            : "This removes the routine and its check-in history."
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

    private var shouldScopeDeleteToOccurrence: Bool {
        kind == .routine && (editsRoutineOccurrenceOnly || item?.taskDate != nil)
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

        if editsRoutineOccurrenceOnly, let item {
            saveRoutineOccurrenceOverride(
                for: item,
                dayStart: calendar.startOfDay(for: taskDate),
                startTime: snappedStartTime,
                endTime: snappedEndTime,
                routineVersions: savedRoutineVersions
            )
            try? modelContext.save()
            dismiss()
            return
        }

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
                    routineLabelRawValue: routineLabelRawValue,
                    sourceRoutineID: item.sourceRoutineID
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
                    item.sourceRoutineID = item.taskDate == nil ? nil : item.sourceRoutineID
                case .task:
                    item.taskDate = taskDate
                    item.startTime = nil
                    item.endTime = nil
                    item.repeatWeekdayMask = 0
                    item.activeFrom = nil
                    item.activeUntil = nil
                    item.routineLabelRawValue = nil
                    item.routineVersionsRawValue = ""
                    item.sourceRoutineID = nil
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

    private func saveRoutineOccurrenceOverride(
        for sourceRoutine: ScheduleItem,
        dayStart: Date,
        startTime: Date,
        endTime: Date,
        routineVersions: [RoutineVersion]
    ) {
        let existingOccurrence = existingRoutineOccurrenceOverride(for: sourceRoutine.id, on: dayStart)
        let occurrence = existingOccurrence
            ?? ScheduleItem(
                kind: .routine,
                title: trimmedTitle,
                notes: trimmedNotes,
                taskDate: dayStart,
                startTime: startTime,
                endTime: endTime,
                repeatWeekdayMask: 0,
                routineLabelRawValue: routineLabelRawValue,
                sourceRoutineID: sourceRoutine.id
            )

        if existingOccurrence == nil {
            modelContext.insert(occurrence)
        }

        occurrence.kind = .routine
        occurrence.title = trimmedTitle
        occurrence.notes = trimmedNotes
        occurrence.taskDate = dayStart
        occurrence.startTime = startTime
        occurrence.endTime = endTime
        occurrence.repeatWeekdayMask = 0
        occurrence.activeFrom = nil
        occurrence.activeUntil = nil
        occurrence.routineLabelRawValue = routineLabelRawValue
        occurrence.sourceRoutineID = sourceRoutine.id
        occurrence.routineVersions = routineVersions

        moveRoutineState(from: sourceRoutine.id, to: occurrence.id, on: dayStart)
    }

    private func existingRoutineOccurrenceOverride(for sourceRoutineID: UUID, on dayStart: Date) -> ScheduleItem? {
        let descriptor = FetchDescriptor<ScheduleItem>()
        let calendar = Calendar.current
        return ((try? modelContext.fetch(descriptor)) ?? []).first { candidate in
            candidate.kind == .routine
                && candidate.sourceRoutineID == sourceRoutineID
                && candidate.taskDate.map { calendar.isDate($0, inSameDayAs: dayStart) } == true
        }
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

    private func moveRoutineState(from oldID: UUID, to newID: UUID, on dayStart: Date) {
        let descriptor = FetchDescriptor<RoutineOccurrenceState>()
        let calendar = Calendar.current
        guard let states = try? modelContext.fetch(descriptor) else {
            return
        }

        for state in states where state.routineID == oldID && calendar.isDate(state.dayStart, inSameDayAs: dayStart) {
            state.routineID = newID
            state.isHidden = false
            state.updatedAt = .now
        }
    }

    private func normalizedRoutineVersions(fallbackDuration: Int) -> [RoutineVersion] {
        RoutineVersionStore.normalizedVersions(routineVersions, fallbackDuration: max(5, fallbackDuration))
    }

    private func deleteRoutine() {
        guard let item, item.kind == .routine else {
            return
        }

        if shouldScopeDeleteToOccurrence {
            deleteRoutineOccurrence(item)
            try? modelContext.save()
            dismiss()
            return
        }

        deleteRoutineStates(for: item.id)
        modelContext.delete(item)
        try? modelContext.save()
        dismiss()
    }

    private func deleteRoutineOccurrence(_ item: ScheduleItem) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: item.taskDate ?? occurrenceDate ?? .now)

        if let sourceRoutineID = item.sourceRoutineID ?? (editsRoutineOccurrenceOnly ? item.id : nil) {
            hideRoutineOccurrence(sourceRoutineID, on: dayStart)
        }

        if item.taskDate != nil {
            deleteRoutineStates(for: item.id)
            modelContext.delete(item)
        }
    }

    private func hideRoutineOccurrence(_ routineID: UUID, on dayStart: Date) {
        let descriptor = FetchDescriptor<RoutineOccurrenceState>()
        let calendar = Calendar.current
        let states = (try? modelContext.fetch(descriptor)) ?? []
        let existingState = states.first {
            $0.routineID == routineID && calendar.isDate($0.dayStart, inSameDayAs: dayStart)
        }
        let state = existingState ?? RoutineOccurrenceState(routineID: routineID, dayStart: dayStart)

        if existingState == nil {
            modelContext.insert(state)
        }

        state.isHidden = true
        state.updatedAt = .now
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

    private var isStandardVersion: Bool {
        version.id == RoutineVersion.standardID
    }

    private var displayedDurationMinutes: Int {
        isStandardVersion ? max(5, baseDurationMinutes) : version.durationMinutes
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text(version.title)
                    .font(.body)
                    .foregroundStyle(MissionTheme.graphite)

                Text(displayedDurationMinutes.readableDuration)
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .foregroundStyle(MissionTheme.secondaryText)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            if !isStandardVersion {
                Stepper(
                    value: $version.durationMinutes,
                    in: 5...ScheduleItem.minutesPerDay,
                    step: 5
                ) {
                    EmptyView()
                }
                .labelsHidden()
                .accessibilityLabel("\(version.title) duration")
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ScheduleItemEditorView(kind: .routine)
        .modelContainer(for: [ScheduleItem.self, RoutineOccurrenceState.self], inMemory: true)
}
