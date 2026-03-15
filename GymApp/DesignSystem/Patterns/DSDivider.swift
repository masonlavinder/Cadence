import SwiftUI

// MARK: - DSDivider

struct DSDivider: View {
    var leadingInset: CGFloat = 0

    @Environment(\.dsTheme) private var theme

    var body: some View {
        Rectangle()
            .fill(theme.divider)
            .frame(height: 1 / UIScreen.main.scale)
            .padding(.leading, leadingInset)
    }
}
