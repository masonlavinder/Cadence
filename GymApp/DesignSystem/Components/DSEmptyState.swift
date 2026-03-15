import SwiftUI

// MARK: - DSEmptyState

struct DSEmptyState: View {
    let icon: String
    let title: String
    var message: String = ""
    var buttonTitle: String? = nil
    var buttonIcon: String? = nil
    var onAction: (() -> Void)? = nil

    @Environment(\.dsTheme) private var theme

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(theme.textTertiary)

            VStack(spacing: DSSpacing.xs) {
                Text(title)
                    .font(DSFont.headline.font)
                    .foregroundStyle(theme.textPrimary)

                if !message.isEmpty {
                    Text(message)
                        .font(DSFont.subheadline.font)
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            if let buttonTitle, let onAction {
                DSButton(
                    title: buttonTitle,
                    icon: buttonIcon,
                    variant: .primary,
                    size: .md,
                    expand: false,
                    action: onAction
                )
            }
        }
        .padding(DSSpacing.xxl)
    }
}

#Preview {
    VStack(spacing: DSSpacing.xxl) {
        DSEmptyState(
            icon: "dumbbell",
            title: "No Workouts",
            message: "Create a workout or generate one with AI",
            buttonTitle: "Create Workout",
            buttonIcon: "plus",
            onAction: {}
        )

        DSEmptyState(
            icon: "magnifyingglass",
            title: "No Results",
            message: "Try a different search"
        )
    }
}
