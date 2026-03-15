import SwiftUI

// MARK: - Color Hex Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }
}

// MARK: - DSColors

enum DSColors {
    // Backgrounds (greyscale)
    static let background = Color(hex: "0F0F0F")
    static let surface = Color(hex: "1A1A1A")
    static let surfaceElevated = Color(hex: "252525")

    // Brand / Actions
    static let primary = Color(hex: "F4A27A")           // Warm peach
    static let primaryLight = Color(hex: "FCEADE")       // Light peach
    static let secondary = Color(hex: "6B6B6B")
    static let destructive = Color(hex: "FF6B6B")
    static let success = Color(hex: "7ECFA0")
    static let warning = Color(hex: "FFB86C")

    // Text (greyscale)
    static let textPrimary = Color(hex: "F0F0F0")
    static let textSecondary = Color(hex: "9E9E9E")
    static let textTertiary = Color(hex: "6B6B6B")
    static let textDisabled = Color(hex: "4A4A4A")
    static let textOnPrimary = Color(hex: "1A1A1A")     // Dark text on peach

    // Borders & Dividers
    static let border = Color(hex: "2E2E2E")
    static let divider = Color(hex: "2E2E2E")

    // Category colors — muted variants
    static func categoryColor(_ category: WorkoutCategory) -> Color {
        switch category {
        case .strength: return Color(hex: "7A9BB5")      // Steel blue
        case .hiit: return Color(hex: "C4787A")          // Rose
        case .cardio: return Color(hex: "D4A96A")        // Amber
        case .yoga: return Color(hex: "A78BBF")          // Lavender
        case .flexibility: return Color(hex: "82B596")   // Sage
        case .calisthenics: return Color(hex: "6DABA0")  // Teal
        case .crossfit: return Color(hex: "B58B9E")      // Mauve
        case .custom: return Color(hex: "8A8A8A")        // Grey
        }
    }

    // Exercise type colors — muted variants
    static func exerciseTypeColor(_ type: ExerciseType) -> Color {
        switch type {
        case .strength: return Color(hex: "7A9BB5")      // Steel blue
        case .cardio: return Color(hex: "D4A96A")        // Amber
        case .flexibility, .pose: return Color(hex: "A78BBF") // Lavender
        case .balance: return Color(hex: "82B596")       // Sage
        case .plyometric: return Color(hex: "C4787A")    // Rose
        case .isometric: return Color(hex: "6DABA0")     // Teal
        case .interval: return Color(hex: "B58B9E")      // Mauve
        case .distance: return Color(hex: "D4A96A")      // Amber
        case .breathwork: return Color(hex: "82B596")    // Sage
        }
    }
}
