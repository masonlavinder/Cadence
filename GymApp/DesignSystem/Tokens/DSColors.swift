import SwiftUI

// MARK: - DSColors

enum DSColors {
    // Backgrounds
    static let background = Color(.systemGroupedBackground)
    static let surface = Color(.secondarySystemGroupedBackground)
    static let surfaceElevated = Color(.tertiarySystemGroupedBackground)

    // Brand / Actions
    static let primary = Color.accentColor
    static let secondary = Color(.systemGray)
    static let destructive = Color(.systemRed)
    static let success = Color(.systemGreen)
    static let warning = Color(.systemOrange)

    // Text
    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let textTertiary = Color(.tertiaryLabel)
    static let textDisabled = Color(.quaternaryLabel)
    static let textOnPrimary = Color.white

    // Borders & Dividers
    static let border = Color(.separator)
    static let divider = Color(.separator)

    // Category colors (workout-specific)
    static func categoryColor(_ category: WorkoutCategory) -> Color {
        switch category {
        case .strength: return .blue
        case .hiit: return .red
        case .cardio: return .orange
        case .yoga: return .purple
        case .flexibility: return .green
        case .calisthenics: return .cyan
        case .crossfit: return .pink
        case .custom: return .gray
        }
    }

    // Exercise type colors
    static func exerciseTypeColor(_ type: ExerciseType) -> Color {
        switch type {
        case .strength: return .blue
        case .cardio: return .orange
        case .flexibility, .pose: return .purple
        case .balance: return .green
        case .plyometric: return .red
        case .isometric: return .cyan
        case .interval: return .pink
        case .distance: return .yellow
        case .breathwork: return .mint
        }
    }
}
