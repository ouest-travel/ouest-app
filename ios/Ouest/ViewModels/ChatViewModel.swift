import Foundation
import SwiftUI

// MARK: - Chat ViewModel

@MainActor
final class ChatViewModel: ObservableObject {
    // MARK: - Published State

    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSending = false
    @Published private(set) var error: String?
    @Published var messageText = ""

    // MARK: - Dependencies

    private let chatRepository: any ChatRepositoryProtocol
    private let tripId: String
    private let currentUserId: String
    private var subscription: (any Cancellable)?

    // MARK: - Computed Properties

    var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var groupedMessages: [(date: String, messages: [ChatMessage])] {
        let grouped = Dictionary(grouping: messages) { message -> String in
            message.dateFormatted
        }

        return grouped.map { (date: $0.key, messages: $0.value) }
            .sorted { $0.messages.first?.createdAt ?? Date() < $1.messages.first?.createdAt ?? Date() }
    }

    // MARK: - Initialization

    init(
        chatRepository: any ChatRepositoryProtocol,
        tripId: String,
        currentUserId: String
    ) {
        self.chatRepository = chatRepository
        self.tripId = tripId
        self.currentUserId = currentUserId
    }

    // MARK: - Data Loading

    func loadMessages() async {
        isLoading = true
        error = nil

        do {
            messages = try await chatRepository.getMessages(tripId: tripId)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func refresh() async {
        await loadMessages()
    }

    // MARK: - Real-time Updates

    func startObserving() {
        subscription = chatRepository.observeMessages(tripId: tripId) { [weak self] newMessage in
            Task { @MainActor in
                guard let self = self else { return }
                // Avoid duplicates
                if !self.messages.contains(where: { $0.id == newMessage.id }) {
                    self.messages.append(newMessage)
                }
            }
        }
    }

    func stopObserving() {
        subscription?.cancel()
        subscription = nil
    }

    // MARK: - Send Message

    func sendMessage() async {
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        isSending = true
        let textToSend = content
        messageText = "" // Clear immediately for better UX

        let request = CreateChatMessageRequest(
            tripId: tripId,
            userId: currentUserId,
            content: textToSend,
            messageType: .text,
            metadata: nil
        )

        do {
            let message = try await chatRepository.sendMessage(request)
            // Add to local list (may already be added via subscription)
            if !messages.contains(where: { $0.id == message.id }) {
                messages.append(message)
            }
        } catch {
            self.error = error.localizedDescription
            messageText = textToSend // Restore text on failure
        }

        isSending = false
    }

    func sendExpenseMessage(expense: Expense) async {
        isSending = true

        let metadata: [String: AnyCodable] = [
            "expenseId": AnyCodable(expense.id),
            "title": AnyCodable(expense.title),
            "amount": AnyCodable(Double(truncating: expense.amount as NSDecimalNumber))
        ]

        let request = CreateChatMessageRequest(
            tripId: tripId,
            userId: currentUserId,
            content: nil,
            messageType: .expense,
            metadata: metadata
        )

        do {
            let message = try await chatRepository.sendMessage(request)
            if !messages.contains(where: { $0.id == message.id }) {
                messages.append(message)
            }
        } catch {
            self.error = error.localizedDescription
        }

        isSending = false
    }

    // MARK: - Helpers

    func isCurrentUser(_ message: ChatMessage) -> Bool {
        message.userId == currentUserId
    }

    // MARK: - Error Handling

    func clearError() {
        error = nil
    }
}
