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
                    routineSection
                    if !isDateAnchoredRoutine {
                        repeatSection
                    }
                case .task:
                    taskSection
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
    }

    private var routineSection: some View {
        Section("Time") {
            FiveMinuteTimePickerRow(title: "Start", selection: $startTime)
            FiveMinuteTimePickerRow(title: "End", selection: $endTime)

            if !hasValidRoutineTime {
                Text("End time must be after start time.")
                    .font(.footnote)
                    .foregroundStyle(MissionTheme.danger)
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
        return calendar.minuteOfDay(for: snappedEndTime) > calendar.minuteOfDay(for: snappedStartTime)
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

    private func save() {
        var notificationSchedule: RoutineNotificationSchedule?
        var notificationCancellationID: UUID?
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
                notificationCancellationID = item.id

                let newItem = ScheduleItem(
                    kind: .routine,
                    title: trimmedTitle,
                    notes: trimmedNotes,
                    taskDate: nil,
                    startTime: snappedStartTime,
                    endTime: snappedEndTime,
                    repeatWeekdayMask: routineRepeatWeekdayMask,
                    activeFrom: todayStart
                )
                modelContext.insert(newItem)
                moveCurrentRoutineStates(from: item.id, to: newItem.id, startingAt: todayStart)
                notificationSchedule = RoutineNotificationSchedule(item: newItem)
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
                case .task:
                    item.taskDate = taskDate
                    item.startTime = nil
                    item.endTime = nil
                    item.repeatWeekdayMask = 0
                    item.activeFrom = nil
                    item.activeUntil = nil
                    notificationCancellationID = item.id
                }

                notificationSchedule = RoutineNotificationSchedule(item: item)
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
                activeFrom: kind == .routine && routineDate == nil ? todayStart : nil
            )
            modelContext.insert(newItem)
            notificationSchedule = RoutineNotificationSchedule(item: newItem)
        }

        updateRoutineNotification(schedule: notificationSchedule, cancellationID: notificationCancellationID)
        dismiss()
    }

    private func updateRoutineNotification(schedule: RoutineNotificationSchedule?, cancellationID: UUID?) {
        Task {
            if let cancellationID {
                await RoutineNotificationScheduler.shared.cancelNotifications(for: cancellationID)
            }

            if let schedule {
                await RoutineNotificationScheduler.shared.scheduleNotifications(for: schedule)
            }
        }
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
}

#Preview {
    ScheduleItemEditorView(kind: .routine)
        .modelContainer(for: [ScheduleItem.self, RoutineOccurrenceState.self], inMemory: true)
}
