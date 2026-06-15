import SwiftUI

struct EditorPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .missionCard()
    }
}

struct EditorSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(MissionTheme.secondaryText)

            EditorPanel {
                content
            }
        }
    }
}

struct RoutineLabelBadge: View {
    let label: RoutineLabel
    var isSelected = false
    var fillsWidth = true
    var fixedWidth: CGFloat?
    var font: Font = .subheadline.weight(.semibold)
    var iconSize: CGFloat = 14
    var height: CGFloat = 40
    var horizontalPadding: CGFloat = 12
    var selectedForeground: Color = MissionTheme.selectedText
    var normalForeground: Color = MissionTheme.graphite
    var selectedBackground: Color = MissionTheme.selection
    var normalBackground: Color = MissionTheme.controlFill

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: label.symbolName)
                .font(.system(size: iconSize, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .frame(width: 20, height: 20, alignment: .center)

            Text(label.title)
                .font(font)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .allowsTightening(true)
                .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: .leading)
        }
        .padding(.horizontal, horizontalPadding)
        .frame(width: fixedWidth)
        .frame(
            maxWidth: fillsWidth && fixedWidth == nil ? .infinity : nil,
            minHeight: height,
            alignment: .leading
        )
        .foregroundStyle(isSelected ? selectedForeground : normalForeground)
        .background(isSelected ? selectedBackground : normalBackground, in: Capsule(style: .continuous))
    }
}
