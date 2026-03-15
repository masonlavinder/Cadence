import SwiftUI

// MARK: - DSTheme

struct DSTheme {
    let background: Color
    let surface: Color
    let surfaceElevated: Color
    let primary: Color
    let secondary: Color
    let destructive: Color
    let success: Color
    let warning: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let textDisabled: Color
    let textOnPrimary: Color
    let border: Color
    let divider: Color

    static let `default` = DSTheme(
        background: DSColors.background,
        surface: DSColors.surface,
        surfaceElevated: DSColors.surfaceElevated,
        primary: DSColors.primary,
        secondary: DSColors.secondary,
        destructive: DSColors.destructive,
        success: DSColors.success,
        warning: DSColors.warning,
        textPrimary: DSColors.textPrimary,
        textSecondary: DSColors.textSecondary,
        textTertiary: DSColors.textTertiary,
        textDisabled: DSColors.textDisabled,
        textOnPrimary: DSColors.textOnPrimary,
        border: DSColors.border,
        divider: DSColors.divider
    )
}
