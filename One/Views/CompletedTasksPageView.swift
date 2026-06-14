import SwiftData
import SwiftUI

struct CompletedTasksPageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScheduleItem.createdAt, order: .reverse) private var items: [ScheduleItem]

    @State private var isFilteringByDate = false
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)

    private let calendar = Calendar.current

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
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if isFilteringByDate {
                DatePicker("Date", selection: $selectedDate, displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .font(.subheadline)
                    .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(TaskListPalette.rowBackground)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if visibleCompletedTasks.isEmpty {
                Text("No completed tasks")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(TaskListPalette.secondaryText)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 12))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(visibleCompletedTasks) { item in
                    CompletedTaskRowView(item: item)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 12))
                        .listRowBackground(TaskListPalette.rowBackground)
                        .listRowSeparatorTint(TaskListPalette.separator.opacity(0.55))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                delete(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
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
    }

    private func delete(_ item: ScheduleItem) {
        withAnimation(.snappy(duration: 0.18)) {
            modelContext.delete(item)
        }
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

private struct CompletedTaskRowView: View {
    let item: ScheduleItem

    private var completedDateText: String {
        (item.completedAt ?? item.createdAt).formatted(.dateTime.locale(.enUS).month(.abbreviated).day().year())
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(TaskListPalette.tertiaryText)

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
        .padding(.vertical, 8)
    }
}
