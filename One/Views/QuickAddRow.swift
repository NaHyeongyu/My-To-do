import SwiftData
import SwiftUI

struct QuickSingleTaskRow: View {
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.callout.weight(.semibold))
                .foregroundStyle(isFocused ? TaskListPalette.primaryText : TaskListPalette.tertiaryText)
                .frame(width: 18)

            TextField("Add a task", text: $title)
                .focused($isFocused)
                .font(.body)
                .submitLabel(.done)
                .textInputAutocapitalization(.sentences)
                .onSubmit(addTask)

            Button(action: addTask) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(trimmedTitle.isEmpty ? TaskListPalette.tertiaryText : TaskListPalette.primaryText)
                    .frame(width: 26, height: 26)
            }
            .disabled(trimmedTitle.isEmpty)
            .buttonStyle(.plain)
            .accessibilityLabel("Add")
        }
        .padding(.vertical, 9)
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .background(TaskListPalette.rowBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke((isFocused ? TaskListPalette.primaryText : TaskListPalette.separator).opacity(isFocused ? 0.24 : 0.28), lineWidth: 0.5)
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addTask() {
        guard !trimmedTitle.isEmpty else { return }

        let item = ScheduleItem(kind: .task, title: trimmedTitle)
        modelContext.insert(item)
        title = ""
        isFocused = true
    }
}

#Preview {
    QuickSingleTaskRow()
        .padding()
        .modelContainer(for: [ScheduleItem.self], inMemory: true)
}
