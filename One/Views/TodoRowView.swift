import SwiftData
import SwiftUI

struct TodayTaskRowView: View {
    @Bindable var item: ScheduleItem
    let onItemsChanged: () -> Void

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.18)) {
                item.toggleCompleted()
            }
            onItemsChanged()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "circle")
                    .font(.body.weight(.medium))
                    .foregroundStyle(MissionTheme.accent)
                    .symbolRenderingMode(.hierarchical)

                Text(item.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(TaskListPalette.primaryText)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TaskListPalette.rowBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(TaskListPalette.glassStroke, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Complete \(item.title)")
    }
}
