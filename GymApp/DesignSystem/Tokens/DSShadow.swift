import SwiftUI

// MARK: - DSShadow

extension View {
    func dsShadowSm() -> some View {
        self.shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
    }

    func dsShadowMd() -> some View {
        self.shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)
    }

    func dsShadowLg() -> some View {
        self.shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
    }
}
