//
//  ChatView.swift
//  Cadence
//

import SwiftUI

struct ChatView: View {
    @Environment(\.dsTheme) private var theme
    @State private var chatService = ChatService()
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if case .unavailable(let reason) = chatService.state {
                Spacer()
                DSEmptyState(
                    icon: "brain.head.profile.slash",
                    title: "AI Coach Unavailable",
                    message: reason
                )
                Spacer()
            } else if chatService.messages.isEmpty {
                Spacer()
                DSEmptyState(
                    icon: "bubble.left.and.text.bubble.right",
                    title: "Ask Your Coach",
                    message: "Ask me anything about workouts, form, programming, or nutrition."
                )
                Spacer()
            } else {
                messageList
            }

            if case .unavailable = chatService.state {
                // Hide input bar when unavailable
            } else {
                inputBar
            }
        }
        .background(theme.background)
        .navigationTitle("Coach")
        .toolbar {
            if !chatService.messages.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset") {
                        chatService.resetConversation()
                    }
                    .disabled(chatService.state == .responding)
                }
            }
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DSSpacing.sm) {
                    ForEach(chatService.messages) { message in
                        ChatBubble(message: message, isResponding: chatService.state == .responding)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.vertical, DSSpacing.sm)
            }
            .onChange(of: chatService.messages.count) {
                if let last = chatService.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: chatService.messages.last?.content) {
                if let last = chatService.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: DSSpacing.sm) {
            TextField("Message your coach...", text: $inputText, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .padding(.horizontal, DSSpacing.md)
                .padding(.vertical, DSSpacing.sm)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: DSRadius.lg)
                        .stroke(theme.border.opacity(0.5), lineWidth: 1)
                )
                .focused($isInputFocused)

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canSend ? theme.primary : theme.textDisabled)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.vertical, DSSpacing.sm)
        .background(theme.background)
    }

    // MARK: - Helpers

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && chatService.state != .responding
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        Task { await chatService.send(text) }
    }
}

// MARK: - Chat Bubble

private struct ChatBubble: View {
    let message: ChatMessage
    let isResponding: Bool
    @Environment(\.dsTheme) private var theme

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: DSSpacing.xxxl) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: DSSpacing.xs) {
                if message.content.isEmpty && isResponding {
                    ProgressView()
                        .controlSize(.small)
                        .padding(DSSpacing.md)
                } else {
                    Text(message.content)
                        .dsFont(.body)
                        .foregroundStyle(message.role == .user ? theme.textOnPrimary : theme.textPrimary)
                        .padding(.horizontal, DSSpacing.md)
                        .padding(.vertical, DSSpacing.sm)
                }
            }
            .background(message.role == .user ? theme.primary : theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg))

            if message.role == .assistant { Spacer(minLength: DSSpacing.xxxl) }
        }
    }
}

#Preview {
    NavigationStack {
        ChatView()
            .dsTheme(.default)
    }
}
