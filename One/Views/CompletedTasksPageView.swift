import SwiftData
import SwiftUI

struct CompletedTasksPageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScheduleItem.createdAt, order: .reverse) private var items: [ScheduleItem]

    let onItemsChanged: () -> Void

    @State private var isFilteringByDate = false
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var editorItem: ScheduleItem?

    private let calendar = Calendar.current
    private let horizontalPadding: CGFloat = 16

    init(onItemsChanged: @escaping () -> Void = {}) {
        self.onItemsChanged = onItemsChanged
    }

    private var completedTasks: [ScheduleItem] {
        items.completedTasks()
    }

    private var visibleCompletedTasks: [ScheduleItem] {
        guard isFilteringByDate else {
            return completedTasks
        }

        return completedTasks.filter { item in
            calendar.isDate(item.completedAt ?? item.createdAt, inSameDayAs: selectedDate)
        }
    }

    private var visibleCompletedTaskIDs: [UUID] {
        visibleCompletedTasks.map(\.id)
    }

    var body: some View {
        List {
            CompletedFilterTabs(isFilteringByDate: $isFilteringByDate)
                .listRowInsets(EdgeInsets(top: 8, leading: horizontalPadding, bottom: 6, trailing: horizontalPadding))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if isFilteringByDate {
                CompletedDateFilterRow(selectedDate: $selectedDate)
                    .listRowInsets(EdgeInsets(top: 2, leading: horizontalPadding, bottom: 8, trailing: horizontalPadding))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if visibleCompletedTasks.isEmpty {
                CompletedEmptyRow()
                    .listRowInsets(EdgeInsets(top: 10, leading: horizontalPadding, bottom: 10, trailing: horizontalPadding))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(visibleCompletedTasks) { item in
                    CompletedTaskRowView(
                        item: item,
                        onEdit: {
                            editorItem = item
                        },
                        onReactivate: {
                            reactivate(item)
                        }
                    )
                        .listRowInsets(EdgeInsets(top: 4, leading: horizontalPadding, bottom: 4, trailing: horizontalPadding))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                delete(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(MissionTheme.danger)
                        }
                }
            }
        }
        .navigationTitle("Completed")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 42)
        .animation(.snappy(duration: 0.18), value: isFilteringByDate)
        .animation(.snappy(duration: 0.18), value: selectedDate)
        .animation(.snappy(duration: 0.18), value: visibleCompletedTaskIDs)
        .scrollContentBackground(.hidden)
        .background(TaskListPalette.background)
        .sheet(item: $editorItem, onDismiss: onItemsChanged) { item in
            ScheduleItemEditorView(item: item)
        }
    }

    private func reactivate(_ item: ScheduleItem) {
        withAnimation(.snappy(duration: 0.18)) {
            item.completedAt = nil
        }
        onItemsChanged()
    }

    private func delete(_ item: ScheduleItem) {
        withAnimation(.snappy(duration: 0.18)) {
            modelContext.delete(item)
        }
        onItemsChanged()
    }
}

private struct CompletedFilterTabs: View {
    @Binding var isFilteringByDate: Bool

    var body: some View {
        Picker("Completed Filter", selection: $isFilteringByDate) {
            Text("All").tag(false)
            Text("Date").tag(true)
        }
        .pickerStyle(.segmented)
    }
}

private struct CompletedDateFilterRow: View {
    @Binding var selectedDate: Date

    var body: some View {
        DatePicker("Date", selection: $selectedDate, displayedComponents: [.date])
            .datePickerStyle(.compact)
            .font(.subheadline)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .missionLiquidCard(cornerRadius: 14)
    }
}

private struct CompletedEmptyRow: View {
    var body: some View {
        Text("No completed tasks")
            .font(.callout.weight(.medium))
            .foregroundStyle(TaskListPalette.secondaryText)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TaskListPalette.rowBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(TaskListPalette.glassStroke, lineWidth: 0.5)
            }
    }
}

private struct CompletedTaskRowView: View {
    let item: ScheduleItem
    let onEdit: () -> Void
    let onReactivate: () -> Void

    private var completedDateText: String {
        (item.completedAt ?? item.createdAt).formatted(.dateTime.locale(.enUS).month(.abbreviated).day().year())
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Button {
                onReactivate()
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(MissionTheme.success)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reactivate \(item.title)")

            Button {
                onEdit()
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text(item.title)
                        .font(.body.weight(.regular))
                        .foregroundStyle(TaskListPalette.secondaryText)
                        .strikethrough(true, color: TaskListPalette.tertiaryText.opacity(0.7))
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(completedDateText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(TaskListPalette.secondaryText)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(item.title)")
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TaskListPalette.rowBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(TaskListPalette.glassStroke, lineWidth: 0.5)
        }
        .contentShape(Rectangle())
    }
}
