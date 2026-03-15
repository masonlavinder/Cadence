import SwiftUI

// MARK: - DSFont

enum DSFont {
    case largeTitle
    case title
    case title2
    case title3
    case headline
    case subheadline
    case body
    case bodyBold
    case caption
    case captionBold
    case caption2

    var font: Font {
        switch self {
        case .largeTitle: return .largeTitle.weight(.bold)
        case .title: return .title.weight(.bold)
        case .title2: return .title2.weight(.bold)
        case .title3: return .title3.weight(.semibold)
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .bodyBold: return .body.weight(.semibold)
        case .caption: return .caption
        case .captionBold: return .caption.weight(.semibold)
        case .caption2: return .caption2
        }
    }
}

// MARK: - Text Extension

extension Text {
    func dsFont(_ style: DSFont) -> Text {
        self.font(style.font)
    }
}

// MARK: - View Extension

extension View {
    func dsFont(_ style: DSFont) -> some View {
        self.font(style.font)
    }
}
