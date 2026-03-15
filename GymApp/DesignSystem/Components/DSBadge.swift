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
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        case .neutral: return .gray
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
}
