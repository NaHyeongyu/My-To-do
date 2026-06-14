import SwiftData
import SwiftUI

struct TasksPageView: View {
    @Environment(\.modelContext) private var modelContext

    let items: [ScheduleItem]

    private var openTaskIDs: [UUID] {
        openTasks.map(\.id)
    }

    private var completedTaskIDs: [UUID] {
        completedTasks.map(\.id)
    }

    private var openTasks: [ScheduleItem] {
        items.openTasks()
    }

    private var completedTasks: [ScheduleItem] {
        items.completedTasks()
    }

    var body: some View {
        List {
            QuickSingleTaskRow()
                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            ForEach(openTasks) { item in
                TodayTaskRowView(item: item)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 12))
                    .listRowBackground(TaskListPalette.rowBackground)
                    .listRowSeparatorTint(TaskListPalette.separator.opacity(0.55))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            delete(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 42)
        .animation(.snappy(duration: 0.18), value: openTaskIDs)
        .animation(.snappy(duration: 0.18), value: completedTaskIDs)
        .scrollContentBackground(.hidden)
        .background(TaskListPalette.background)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            NavigationLink {
                CompletedTasksPageView()
            } label: {
                CompletedPinnedButton(count: completedTasks.count)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .background(TaskListPalette.background.ignoresSafeArea(edges: .bottom))
        }
    }

    private func delete(_ item: ScheduleItem) {
        withAnimation(.snappy(duration: 0.18)) {
            modelContext.delete(item)
        }
    }
}

private struct CompletedPinnedButton: View {
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.body)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(TaskListPalette.secondaryText)

            Text("Completed")
                .font(.body.weight(.medium))
                .foregroundStyle(TaskListPalette.primaryText)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text("\(count)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(TaskListPalette.secondaryText)
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(TaskListPalette.fill, in: Capsule())

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(TaskListPalette.tertiaryText)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(TaskListPalette.rowBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(TaskListPalette.separator.opacity(0.28), lineWidth: 0.5)
        }
    }
}
