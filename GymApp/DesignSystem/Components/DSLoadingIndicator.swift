import SwiftUI

// MARK: - DSLoadingIndicator

struct DSLoadingIndicator: View {
    var label: String? = nil
    var size: ControlSize = .regular

    @Environment(\.dsTheme) private var theme

    var body: some View {
        VStack(spacing: DSSpacing.sm) {
            ProgressView()
                .controlSize(size)
                .tint(theme.primary)

            if let label {
                Text(label)
                    .font(DSFont.caption.font)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }
}

// MARK: - DSSkeleton

struct DSSkeleton: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16

    @State private var shimmer = false

    var body: some View {
        RoundedRectangle(cornerRadius: DSRadius.sm)
            .fill(DSColors.surfaceElevated)
            .frame(width: width, height: height)
            .overlay {
                RoundedRectangle(cornerRadius: DSRadius.sm)
                    .fill(
                        LinearGradient(
                            colors: [.clear, DSColors.textTertiary.opacity(0.2), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: shimmer ? 200 : -200)
            }
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    shimmer = true
                }
            }
    }
}

#Preview {
    VStack(spacing: DSSpacing.xl) {
        DSLoadingIndicator(label: "Loading workouts...")

        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            DSSkeleton(width: 200, height: 20)
            DSSkeleton(height: 14)
            DSSkeleton(width: 150, height: 14)
        }
        .padding()
    }
    .background(DSColors.background)
}
