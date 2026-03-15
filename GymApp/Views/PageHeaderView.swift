import SwiftUI

// MARK: - PageHeaderView

struct PageHeaderView<Filters: View>: View {
    let title: String
    let buttonLabel: String
    let buttonIcon: String
    let onButtonTap: () -> Void
    @Binding var searchText: String
    let searchPrompt: String
    @ViewBuilder let filters: () -> Filters

    /// Secondary button (optional, e.g. "Generate with AI")
    var secondaryButtonLabel: String? = nil
    var secondaryButtonIcon: String? = nil
    var onSecondaryButtonTap: (() -> Void)? = nil

    @Environment(\.dsTheme) private var theme

    var body: some View {
        VStack(spacing: 12) {
            // Title + New button
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("cadence")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .tracking(4)
                        .textCase(.uppercase)
                        .foregroundStyle(theme.primary)
                    Text(title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(theme.textPrimary)
                }

                Spacer()

                HStack(spacing: 16) {
                    if let secondaryIcon = secondaryButtonIcon,
                       let secondaryAction = onSecondaryButtonTap {
                        Button {
                            secondaryAction()
                        } label: {
                            Image(systemName: secondaryIcon)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .foregroundStyle(theme.primary)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        onButtonTap()
                    } label: {
                        Image(systemName: buttonIcon)
                            .font(.title)
                            .frame(width: 44, height: 44)
                            .foregroundStyle(theme.primary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.textSecondary)
                TextField(searchPrompt, text: $searchText)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filters()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}
