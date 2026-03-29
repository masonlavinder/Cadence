import SwiftUI

// MARK: - DSTextField

struct DSTextField: View {
    let label: String
    var placeholder: String = ""
    @Binding var text: String
    var error: String? = nil
    var leadingIcon: String? = nil
    var isDisabled: Bool = false
    var axis: Axis = .horizontal

    @Environment(\.dsTheme) private var theme
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            // Label
            if !label.isEmpty {
                Text(label)
                    .font(DSFont.captionBold.font)
                    .foregroundStyle(error != nil ? theme.destructive : theme.textSecondary)
            }

            // Field
            HStack(spacing: DSSpacing.sm) {
                if let leadingIcon {
                    Image(systemName: leadingIcon)
                        .foregroundStyle(theme.textTertiary)
                        .font(.subheadline)
                }

                TextField(placeholder, text: $text, axis: axis)
                    .focused($isFocused)
                    .disabled(isDisabled)

                if !text.isEmpty && isFocused {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.textTertiary)
                    }
                    .buttonStyle(.tactile)
                }
            }
            .padding(DSSpacing.md)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
            .overlay {
                RoundedRectangle(cornerRadius: DSRadius.sm)
                    .stroke(borderColor, lineWidth: 1)
            }

            // Error
            if let error {
                Text(error)
                    .font(DSFont.caption.font)
                    .foregroundStyle(theme.destructive)
            }
        }
        .opacity(isDisabled ? 0.5 : 1.0)
    }

    private var borderColor: Color {
        if error != nil { return theme.destructive }
        if isFocused { return theme.primary }
        return theme.border.opacity(0.5)
    }
}

#Preview("States") {
    VStack(spacing: DSSpacing.lg) {
        DSTextField(label: "Name", placeholder: "Enter name", text: .constant(""))
        DSTextField(label: "Search", placeholder: "Search...", text: .constant("Hello"), leadingIcon: "magnifyingglass")
        DSTextField(label: "Email", placeholder: "you@example.com", text: .constant("bad"), error: "Invalid email")
        DSTextField(label: "Disabled", placeholder: "Can't edit", text: .constant(""), isDisabled: true)
    }
    .padding()
}
