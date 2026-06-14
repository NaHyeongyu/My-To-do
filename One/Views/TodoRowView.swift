import SwiftData
import SwiftUI

struct TodayTaskRowView: View {
    @Bindable var item: ScheduleItem

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.18)) {
                item.toggleCompleted()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "circle")
                    .font(.body.weight(.medium))
                    .foregroundStyle(TaskListPalette.tertiaryText)
                    .symbolRenderingMode(.hierarchical)

                Text(item.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(TaskListPalette.primaryText)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Complete \(item.title)")
    }
}
