import SwiftUI

// MARK: - DSButton

struct DSButton: View {
    enum Variant {
        case primary, secondary, destructive, ghost
    }

    enum Size {
        case sm, md, lg
    }

    let title: String
    var icon: String? = nil
    var variant: Variant = .primary
    var size: Size = .md
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var expand: Bool = true
    let action: () -> Void

    @Environment(\.dsTheme) private var theme

    var body: some View {
        Button {
            if !isLoading && !isDisabled {
                action()
            }
        } label: {
            HStack(spacing: DSSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(foregroundColor)
                } else if let icon {
                    Image(systemName: icon)
                        .font(iconFont)
                }
                Text(title)
                    .font(textFont)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: expand ? .infinity : nil)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                if variant == .ghost || variant == .secondary {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(borderColor, lineWidth: variant == .secondary ? 1 : 0)
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(isDisabled ? 0.5 : 1.0)
        .allowsHitTesting(!isDisabled && !isLoading)
    }

    // MARK: - Styling

    private var backgroundColor: Color {
        switch variant {
        case .primary: return theme.primary
        case .secondary: return Color.clear
        case .destructive: return theme.destructive
        case .ghost: return Color.clear
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary: return theme.textOnPrimary
        case .secondary: return theme.primary
        case .destructive: return theme.textOnPrimary
        case .ghost: return theme.primary
        }
    }

    private var borderColor: Color {
        switch variant {
        case .secondary: return theme.primary.opacity(0.3)
        default: return Color.clear
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .sm: return DSSpacing.sm
        case .md: return DSSpacing.md
        case .lg: return DSSpacing.lg
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .sm: return DSSpacing.md
        case .md: return DSSpacing.lg
        case .lg: return DSSpacing.xl
        }
    }

    private var cornerRadius: CGFloat {
        switch size {
        case .sm: return DSRadius.sm
        case .md: return DSRadius.md
        case .lg: return DSRadius.md
        }
    }

    private var textFont: Font {
        switch size {
        case .sm: return DSFont.caption.font
        case .md: return DSFont.subheadline.font
        case .lg: return DSFont.headline.font
        }
    }

    private var iconFont: Font {
        switch size {
        case .sm: return .caption
        case .md: return .subheadline
        case .lg: return .headline
        }
    }
}

#Preview("All Variants") {
    VStack(spacing: DSSpacing.lg) {
        DSButton(title: "Primary", variant: .primary) {}
        DSButton(title: "Secondary", variant: .secondary) {}
        DSButton(title: "Destructive", icon: "trash", variant: .destructive) {}
        DSButton(title: "Ghost", variant: .ghost) {}
        DSButton(title: "Loading", isLoading: true) {}
        DSButton(title: "Disabled", isDisabled: true) {}

        HStack(spacing: DSSpacing.sm) {
            DSButton(title: "Small", size: .sm, expand: false) {}
            DSButton(title: "Medium", size: .md, expand: false) {}
            DSButton(title: "Large", size: .lg, expand: false) {}
        }
    }
    .padding()
}
