import SwiftUI

// MARK: - DSCard

struct DSCard<Content: View>: View {
    var padding: CGFloat = DSSpacing.lg
    @ViewBuilder let content: () -> Content

    @Environment(\.dsTheme) private var theme

    var body: some View {
        content()
            .padding(padding)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.md)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
    }
}

// MARK: - DSGlassCard

struct DSGlassCard<Content: View>: View {
    var padding: CGFloat = DSSpacing.lg
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.md)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
    }
}

// MARK: - Card ViewModifier

struct DSCardModifier: ViewModifier {
    var padding: CGFloat = DSSpacing.lg

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.md)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
    }
}

// MARK: - Glass Card ViewModifier

struct DSGlassCardModifier: ViewModifier {
    var padding: CGFloat = DSSpacing.lg

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.md)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
    }
}

extension View {
    func dsCard(padding: CGFloat = DSSpacing.lg) -> some View {
        self.modifier(DSCardModifier(padding: padding))
    }

    func dsGlassCard(padding: CGFloat = DSSpacing.lg) -> some View {
        self.modifier(DSGlassCardModifier(padding: padding))
    }
}

#Preview {
    VStack(spacing: DSSpacing.lg) {
        DSCard {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Text("Card Title").font(DSFont.headline.font)
                Text("Some content goes here").font(DSFont.body.font)
            }
        }

        DSGlassCard {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Text("Glass Card").font(DSFont.headline.font)
                Text("Translucent background").font(DSFont.body.font)
            }
        }

        Text("Using .dsCard() modifier")
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsCard()

        Text("Using .dsGlassCard() modifier")
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsGlassCard()
    }
    .padding()
    .background(DSColors.background)
}
