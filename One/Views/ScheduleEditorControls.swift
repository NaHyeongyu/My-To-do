import SwiftUI

struct FiveMinuteTimePickerRow: View {
    let title: String
    @Binding var selection: Date

    var body: some View {
        HStack {
            Text(title)

            Spacer(minLength: 16)

            FiveMinuteTimePicker(selection: $selection)
                .frame(minWidth: 92, minHeight: 34, alignment: .trailing)
                .fixedSize()
        }
        .accessibilityElement(children: .combine)
    }
}

struct WeekdaySelectionRow: View {
    @Binding var mask: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(RepeatWeekday.allCases) { weekday in
                WeekdaySelectionButton(
                    weekday: weekday,
                    isSelected: RepeatWeekdayMask.contains(weekday, in: mask)
                ) {
                    mask = RepeatWeekdayMask.toggled(weekday, in: mask)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

private struct WeekdaySelectionButton: View {
    let weekday: RepeatWeekday
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(weekday.compactTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? MissionTheme.selectedText : MissionTheme.graphite)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? MissionTheme.selection : MissionTheme.controlFill)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(weekday.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct FiveMinuteTimePicker: UIViewRepresentable {
    @Binding var selection: Date

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.minuteInterval = 5
        picker.preferredDatePickerStyle = .compact
        picker.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        picker.minuteInterval = 5

        let snappedSelection = Calendar.current.dateBySnappingToFiveMinute(selection)
        guard abs(picker.date.timeIntervalSince(snappedSelection)) > 0.5 else {
            return
        }

        picker.date = snappedSelection
    }

    final class Coordinator: NSObject {
        private var selection: Binding<Date>

        init(selection: Binding<Date>) {
            self.selection = selection
        }

        @MainActor @objc func valueChanged(_ picker: UIDatePicker) {
            selection.wrappedValue = Calendar.current.dateBySnappingToFiveMinute(picker.date)
        }
    }
}
