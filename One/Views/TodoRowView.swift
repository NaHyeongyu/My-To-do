import SwiftData
import SwiftUI

struct TodayTaskRowView: View {
    @Bindable var item: ScheduleItem
    let onEdit: (ScheduleItem) -> Void
    let onItemsChanged: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.snappy(duration: 0.18)) {
                    item.toggleCompleted()
                }
                onItemsChanged()
            } label: {
                Image(systemName: "circle")
                    .font(.body.weight(.medium))
                    .foregroundStyle(MissionTheme.accent)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Complete \(item.title)")

            Button {
                onEdit(item)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(TaskListPalette.primaryText)
                        .lineLimit(1)

                    if let dateText {
                        Text(dateText)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(TaskListPalette.secondaryText)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(item.title)")
        }
        .padding(.vertical, dateText == nil ? 11 : 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TaskListPalette.rowBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(TaskListPalette.glassStroke, lineWidth: 0.5)
        }
        .contentShape(Rectangle())
    }

    private var dateText: String? {
        guard let taskDate = item.taskDate else {
            return nil
        }

        if calendar.isDateInToday(taskDate) {
            return "Today"
        }

        if calendar.isDateInTomorrow(taskDate) {
            return "Tomorrow"
        }

        return taskDate.formatted(.dateTime.locale(.enUS).month(.abbreviated).day())
    }
}
