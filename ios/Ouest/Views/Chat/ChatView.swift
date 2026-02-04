import SwiftUI

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: ChatViewModel

    init(trip: Trip, repositories: RepositoryProvider? = nil) {
        let repos = repositories ?? RepositoryProvider()
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            tripId: trip.id,
            chatRepository: repos.chatRepository
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: OuestTheme.Spacing.sm) {
                        if viewModel.isLoading {
                            loadingView
                        } else if viewModel.messages.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(viewModel.messages) { message in
                                ChatMessageRow(
                                    message: message,
                                    isCurrentUser: isCurrentUser(message)
                                )
                                .id(message.id)
                            }
                        }
                    }
                    .padding(.horizontal, OuestTheme.Spacing.md)
                    .padding(.vertical, OuestTheme.Spacing.sm)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Input
            chatInputView
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .background(OuestTheme.Colors.background)
        .task {
            await viewModel.loadMessages()
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: OuestTheme.Spacing.sm) {
            ForEach(0..<5, id: \.self) { index in
                HStack {
                    if index % 2 == 0 { Spacer() }
                    RoundedRectangle(cornerRadius: OuestTheme.CornerRadius.medium)
                        .fill(OuestTheme.Colors.inputBackground)
                        .frame(width: 200, height: 60)
                        .shimmer()
                    if index % 2 != 0 { Spacer() }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: OuestTheme.Spacing.md) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(OuestTheme.Colors.textTertiary)

            Text("No messages yet")
                .font(OuestTheme.Fonts.body)
                .foregroundColor(OuestTheme.Colors.textSecondary)

            Text("Start the conversation!")
                .font(OuestTheme.Fonts.caption)
                .foregroundColor(OuestTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OuestTheme.Spacing.xxl)
    }

    private var chatInputView: some View {
        HStack(spacing: OuestTheme.Spacing.sm) {
            TextField("Type a message...", text: $viewModel.newMessageText)
                .font(OuestTheme.Fonts.body)
                .padding(.horizontal, OuestTheme.Spacing.md)
                .padding(.vertical, OuestTheme.Spacing.sm)
                .background(OuestTheme.Colors.inputBackground)
                .cornerRadius(20)

            Button {
                Task {
                    await viewModel.sendMessage()
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(viewModel.newMessageText.isEmpty ? OuestTheme.Colors.textTertiary : OuestTheme.Colors.primary)
            }
            .disabled(viewModel.newMessageText.isEmpty)
        }
        .padding(.horizontal, OuestTheme.Spacing.md)
        .padding(.vertical, OuestTheme.Spacing.sm)
        .background(OuestTheme.Colors.cardBackground)
    }

    // MARK: - Helpers

    private func isCurrentUser(_ message: ChatMessage) -> Bool {
        if appState.isDemoMode {
            return message.userId == "demo-user-1"
        }
        return message.userId == appState.authViewModel.currentUserId
    }
}

// MARK: - Chat Message Row

struct ChatMessageRow: View {
    let message: ChatMessage
    let isCurrentUser: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: OuestTheme.Spacing.xs) {
            if isCurrentUser {
                Spacer(minLength: 60)
            } else {
                OuestAvatar(message.profile, size: .small)
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser {
                    Text(message.profile?.displayNameOrEmail ?? "Unknown")
                        .font(OuestTheme.Fonts.caption)
                        .foregroundColor(OuestTheme.Colors.textSecondary)
                }

                // Message content based on type
                messageContent

                Text(message.timeFormatted)
                    .font(OuestTheme.Fonts.caption2)
                    .foregroundColor(OuestTheme.Colors.textTertiary)
            }

            if !isCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }

    @ViewBuilder
    private var messageContent: some View {
        switch message.messageType {
        case .text:
            textMessageView
        case .expense:
            expenseMessageView
        case .summary:
            summaryMessageView
        }
    }

    private var textMessageView: some View {
        Text(message.content ?? "")
            .font(OuestTheme.Fonts.body)
            .foregroundColor(isCurrentUser ? .white : OuestTheme.Colors.text)
            .padding(.horizontal, OuestTheme.Spacing.sm)
            .padding(.vertical, OuestTheme.Spacing.xs)
            .background(
                isCurrentUser
                    ? AnyView(OuestTheme.Gradients.primary)
                    : AnyView(OuestTheme.Colors.cardBackground)
            )
            .cornerRadius(16)
    }

    private var expenseMessageView: some View {
        HStack(spacing: OuestTheme.Spacing.sm) {
            Image(systemName: "creditcard.fill")
                .foregroundColor(OuestTheme.Colors.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text("New Expense")
                    .font(OuestTheme.Fonts.caption)
                    .foregroundColor(OuestTheme.Colors.textSecondary)

                if let metadata = message.expenseMetadata {
                    Text(metadata.title ?? "Expense")
                        .font(OuestTheme.Fonts.body)
                        .foregroundColor(OuestTheme.Colors.text)

                    if let amount = metadata.amount {
                        Text("$\(String(format: "%.2f", amount))")
                            .font(OuestTheme.Fonts.headline)
                            .foregroundColor(OuestTheme.Colors.primary)
                    }
                }
            }
        }
        .padding(OuestTheme.Spacing.sm)
        .background(OuestTheme.Colors.cardBackground)
        .cornerRadius(OuestTheme.CornerRadius.medium)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var summaryMessageView: some View {
        HStack(spacing: OuestTheme.Spacing.sm) {
            Image(systemName: "doc.text.fill")
                .foregroundColor(OuestTheme.Colors.success)

            Text("Settlement Summary")
                .font(OuestTheme.Fonts.body)
                .foregroundColor(OuestTheme.Colors.text)
        }
        .padding(OuestTheme.Spacing.sm)
        .background(OuestTheme.Colors.success.opacity(0.1))
        .cornerRadius(OuestTheme.CornerRadius.medium)
    }
}

#Preview {
    NavigationStack {
        ChatView(
            trip: DemoModeManager.demoTrips[0],
            repositories: RepositoryProvider(isDemoMode: true)
        )
        .environmentObject(AppState(isDemoMode: true))
    }
}
