import Foundation

// MARK: - Chat Repository Implementation (Local Storage)

final class ChatRepository: ChatRepositoryProtocol {
    private let userDefaultsKey = "ouest_chat_messages"

    init() {}

    func getMessages(tripId: String) async throws -> [ChatMessage] {
        let messages = loadMessages()
        return messages.filter { $0.tripId == tripId }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func sendMessage(_ request: CreateChatMessageRequest) async throws -> ChatMessage {
        var messages = loadMessages()

        let message = ChatMessage(
            id: UUID().uuidString,
            tripId: request.tripId,
            userId: request.userId,
            content: request.content,
            messageType: request.messageType,
            metadata: request.metadata,
            createdAt: Date(),
            profile: nil
        )

        messages.append(message)
        saveMessages(messages)

        return message
    }

    func observeMessages(tripId: String, onNewMessage: @escaping (ChatMessage) -> Void) -> any Cancellable {
        // Local storage doesn't support real-time updates
        return SubscriptionToken { }
    }

    // MARK: - Private Storage Methods

    private func loadMessages() -> [ChatMessage] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode([ChatMessage].self, from: data)
        } catch {
            print("Failed to decode messages: \(error)")
            return []
        }
    }

    private func saveMessages(_ messages: [ChatMessage]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(messages)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Failed to save messages: \(error)")
        }
    }
}

// MARK: - Mock Chat Repository

final class MockChatRepository: ChatRepositoryProtocol {
    func getMessages(tripId: String) async throws -> [ChatMessage] {
        return DemoModeManager.demoChatMessages.filter { $0.tripId == tripId }
    }

    func sendMessage(_ request: CreateChatMessageRequest) async throws -> ChatMessage {
        try await Task.sleep(nanoseconds: 300_000_000)
        return ChatMessage(
            id: UUID().uuidString,
            tripId: request.tripId,
            userId: request.userId,
            content: request.content,
            messageType: request.messageType,
            metadata: request.metadata,
            createdAt: Date(),
            profile: nil
        )
    }

    func observeMessages(tripId: String, onNewMessage: @escaping (ChatMessage) -> Void) -> any Cancellable {
        return SubscriptionToken { }
    }
}
