import SwiftUI

// MARK: - DSSectionHeader

struct DSSectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var onAction: (() -> Void)? = nil

    @Environment(\.dsTheme) private var theme

    var body: some View {
        HStack {
            Text(title)
                .font(DSFont.captionBold.font)
                .foregroundStyle(theme.textSecondary)
                .textCase(.uppercase)

            Spacer()

            if let actionTitle, let onAction {
                Button(action: onAction) {
                    Text(actionTitle)
                        .font(DSFont.captionBold.font)
                        .foregroundStyle(theme.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, DSSpacing.xs)
    }
}

#Preview {
    VStack(spacing: DSSpacing.lg) {
        DSSectionHeader(title: "Exercises")
        DSSectionHeader(title: "Recent", actionTitle: "See All") {}
    }
    .padding()
}
