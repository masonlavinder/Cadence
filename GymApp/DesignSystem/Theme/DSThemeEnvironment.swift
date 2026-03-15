import SwiftUI

// MARK: - DSTheme Environment Key

private struct DSThemeKey: EnvironmentKey {
    static let defaultValue = DSTheme.default
}

extension EnvironmentValues {
    var dsTheme: DSTheme {
        get { self[DSThemeKey.self] }
        set { self[DSThemeKey.self] = newValue }
    }
}

extension View {
    func dsTheme(_ theme: DSTheme) -> some View {
        self.environment(\.dsTheme, theme)
    }
}
