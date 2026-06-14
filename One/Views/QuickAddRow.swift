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
                .textFieldStyle(.plain)
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

        let parsedTask = QuickTaskInputParser.parse(trimmedTitle)
        let item = ScheduleItem(
            kind: .task,
            title: parsedTask.title,
            taskDate: parsedTask.date
        )
        modelContext.insert(item)
        title = ""
        isFocused = true
    }
}

private struct QuickTaskInput {
    let title: String
    let date: Date?
}

private enum QuickTaskInputParser {
    static func parse(
        _ rawValue: String,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> QuickTaskInput {
        let rawTitle = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedTitle = rawTitle.lowercased()
        let today = calendar.startOfDay(for: now)
        let time = extractedTime(from: lowercasedTitle)
        let day = extractedDay(from: lowercasedTitle, today: today, calendar: calendar)
        let parsedDate = combinedDate(day: day, time: time, now: now, calendar: calendar)
        let cleanedTitle = cleaned(rawTitle)

        return QuickTaskInput(title: cleanedTitle.isEmpty ? rawTitle : cleanedTitle, date: parsedDate)
    }

    private static func extractedDay(from text: String, today: Date, calendar: Calendar) -> Date? {
        if text.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: today)
        }

        if text.contains("today") {
            return today
        }

        for weekday in RepeatWeekday.allCases {
            let weekdayTitle = weekday.title.lowercased()
            let weekdayShortTitle = weekday.shortTitle.lowercased()

            if containsWord(weekdayTitle, in: text) || containsWord(weekdayShortTitle, in: text) {
                return nextDate(matching: weekday, from: today, calendar: calendar)
            }
        }

        return nil
    }

    private static func extractedTime(from text: String) -> DateComponents? {
        let patterns = [
            #"\b([0-1]?\d|2[0-3]):([0-5]\d)\b"#,
            #"\b(1[0-2]|0?\d)(?::([0-5]\d))?\s*(am|pm)\b"#
        ]

        for pattern in patterns {
            guard
                let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
            else {
                continue
            }

            let hourRange = Range(match.range(at: 1), in: text)
            let minuteRange = match.numberOfRanges > 2 ? Range(match.range(at: 2), in: text) : nil
            let meridiemRange = match.numberOfRanges > 3 ? Range(match.range(at: 3), in: text) : nil

            guard var hour = hourRange.flatMap({ Int(text[$0]) }) else {
                continue
            }

            let minute = minuteRange.flatMap { Int(text[$0]) } ?? 0
            if let meridiemRange {
                let meridiem = String(text[meridiemRange])
                if meridiem == "pm", hour < 12 {
                    hour += 12
                } else if meridiem == "am", hour == 12 {
                    hour = 0
                }
            }

            return DateComponents(hour: hour, minute: minute)
        }

        return nil
    }

    private static func combinedDate(
        day: Date?,
        time: DateComponents?,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        guard day != nil || time != nil else {
            return nil
        }

        let baseDay = day ?? calendar.startOfDay(for: now)
        var components = calendar.dateComponents([.year, .month, .day], from: baseDay)
        components.hour = time?.hour ?? 9
        components.minute = time?.minute ?? 0

        guard let date = calendar.date(from: components) else {
            return day
        }

        if day == nil, date < now {
            return calendar.date(byAdding: .day, value: 1, to: date)
        }

        return date
    }

    private static func nextDate(matching weekday: RepeatWeekday, from today: Date, calendar: Calendar) -> Date? {
        let currentWeekday = calendar.component(.weekday, from: today)
        let daysUntilWeekday = (weekday.rawValue - currentWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: daysUntilWeekday, to: today)
    }

    private static func containsWord(_ word: String, in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: #"\b\#(word)\b"#, options: [.caseInsensitive]) else {
            return false
        }

        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    private static func cleaned(_ text: String) -> String {
        let patterns = [
            #"\b(today|tomorrow)\b"#,
            #"\b(sunday|monday|tuesday|wednesday|thursday|friday|saturday)\b"#,
            #"\b(sun|mon|tue|wed|thu|fri|sat)\b"#,
            #"\b([0-1]?\d|2[0-3]):([0-5]\d)\b"#,
            #"\b(1[0-2]|0?\d)(?::([0-5]\d))?\s*(am|pm)\b"#
        ]

        let cleanedText = patterns.reduce(text) { partialResult, pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                return partialResult
            }

            return regex.stringByReplacingMatches(
                in: partialResult,
                range: NSRange(partialResult.startIndex..., in: partialResult),
                withTemplate: ""
            )
        }

        return cleanedText
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    QuickSingleTaskRow()
        .padding()
        .modelContainer(for: [ScheduleItem.self], inMemory: true)
}
