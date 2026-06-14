import SwiftUI

struct EmptyStateView: View {
    let title: String
    let systemImage: String?
    var verticalPadding: CGFloat = 26

    init(title: String, systemImage: String? = nil, verticalPadding: CGFloat = 26) {
        self.title = title
        self.systemImage = systemImage
        self.verticalPadding = verticalPadding
    }

    var body: some View {
        VStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(MissionTheme.secondaryText)
            }

            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(MissionTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, verticalPadding)
        .missionCard()
    }
}
