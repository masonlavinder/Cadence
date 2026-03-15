import SwiftUI

// MARK: - Screen Padding

extension View {
    func dsScreenPadding() -> some View {
        self.padding(.horizontal, DSSpacing.lg)
    }
}

// MARK: - Conditional Modifier

extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
