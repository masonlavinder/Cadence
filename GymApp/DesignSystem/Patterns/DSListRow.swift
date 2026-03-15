import SwiftUI

// MARK: - DSListRow

struct DSListRow<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var leadingIcon: String? = nil
    var leadingColor: Color = DSColors.primary
    @ViewBuilder var trailing: () -> Trailing

    @Environment(\.dsTheme) private var theme

    var body: some View {
        HStack(spacing: DSSpacing.md) {
            if let leadingIcon {
                Image(systemName: leadingIcon)
                    .font(.title3)
                    .foregroundStyle(leadingColor)
                    .frame(width: 36)
            }

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(title)
                    .font(DSFont.body.font)
                    .foregroundStyle(theme.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(DSFont.caption.font)
                        .foregroundStyle(theme.textSecondary)
                }
            }

            Spacer()

            trailing()
        }
        .padding(.vertical, DSSpacing.sm)
    }
}

extension DSListRow where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, leadingIcon: String? = nil, leadingColor: Color = DSColors.primary) {
        self.title = title
        self.subtitle = subtitle
        self.leadingIcon = leadingIcon
        self.leadingColor = leadingColor
        self.trailing = { EmptyView() }
    }
}

#Preview {
    VStack(spacing: 0) {
        DSListRow(title: "Push-ups", subtitle: "Chest, Triceps", leadingIcon: "figure.strengthtraining.traditional")
        DSDivider(leadingInset: 52)
        DSListRow(title: "Squats", subtitle: "Quads, Glutes", leadingIcon: "figure.strengthtraining.traditional") {
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
    .padding()
}
