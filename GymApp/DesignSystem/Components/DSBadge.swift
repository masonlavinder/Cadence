import SwiftUI

// MARK: - DSBadge

struct DSBadge: View {
    enum Variant {
        case info, success, warning, error, neutral
    }

    let text: String
    var variant: Variant = .neutral
    var icon: String? = nil

    var body: some View {
        HStack(spacing: DSSpacing.xs) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(text)
                .font(DSFont.captionBold.font)
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
        .background(backgroundColor.opacity(0.15))
        .foregroundStyle(backgroundColor)
        .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch variant {
        case .info: return DSColors.primary
        case .success: return DSColors.success
        case .warning: return DSColors.warning
        case .error: return DSColors.destructive
        case .neutral: return DSColors.secondary
        }
    }
}

#Preview {
    HStack(spacing: DSSpacing.sm) {
        DSBadge(text: "Info", variant: .info)
        DSBadge(text: "Success", variant: .success, icon: "checkmark")
        DSBadge(text: "Warning", variant: .warning)
        DSBadge(text: "Error", variant: .error)
        DSBadge(text: "Neutral", variant: .neutral)
    }
    .padding()
    .background(DSColors.background)
}
