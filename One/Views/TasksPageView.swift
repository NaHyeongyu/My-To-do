import SwiftData
import SwiftUI

struct TasksPageView: View {
    @Environment(\.modelContext) private var modelContext

    let items: [ScheduleItem]
    let onItemsChanged: () -> Void

    private let horizontalPadding: CGFloat = 16

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
            QuickSingleTaskRow(onItemsChanged: onItemsChanged)
                .listRowInsets(EdgeInsets(top: 6, leading: horizontalPadding, bottom: 6, trailing: horizontalPadding))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            ForEach(openTasks) { item in
                TodayTaskRowView(item: item, onItemsChanged: onItemsChanged)
                    .listRowInsets(EdgeInsets(top: 4, leading: horizontalPadding, bottom: 4, trailing: horizontalPadding))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
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
        .scrollDismissesKeyboard(.interactively)
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
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 6)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
        }
    }

    private func delete(_ item: ScheduleItem) {
        withAnimation(.snappy(duration: 0.18)) {
            modelContext.delete(item)
        }
        onItemsChanged()
    }
}

private struct CompletedPinnedButton: View {
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.body)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(MissionTheme.success)

            Text("Completed")
                .font(.body.weight(.medium))
                .foregroundStyle(TaskListPalette.primaryText)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text("\(count)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(MissionTheme.selectedText)
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(MissionTheme.accent, in: Capsule())

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
                .stroke(TaskListPalette.glassStroke, lineWidth: 0.5)
        }
    }
}
