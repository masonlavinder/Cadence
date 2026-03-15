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

    var body: some View {
        VStack(spacing: 12) {
            // Title + New button
            HStack {
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()

                if let secondaryLabel = secondaryButtonLabel,
                   let secondaryIcon = secondaryButtonIcon,
                   let secondaryAction = onSecondaryButtonTap {
                    Button {
                        secondaryAction()
                    } label: {
                        Image(systemName: secondaryIcon)
                            .font(.title3)
                            .foregroundStyle(.accentColor)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    onButtonTap()
                } label: {
                    Image(systemName: buttonIcon)
                        .font(.title2)
                        .foregroundStyle(.accentColor)
                }
                .buttonStyle(.plain)
            }

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(searchPrompt, text: $searchText)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
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
