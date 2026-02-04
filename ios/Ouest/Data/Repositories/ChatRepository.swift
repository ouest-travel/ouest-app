import Foundation
import Supabase

// MARK: - Chat Repository Implementation

final class ChatRepository: ChatRepositoryProtocol {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    func getMessages(tripId: String) async throws -> [ChatMessage] {
        let messages: [ChatMessage] = try await client
            .from(Tables.chatMessages)
            .select("*, profile:profiles!user_id(id, email, display_name, handle, avatar_url, created_at)")
            .eq("trip_id", value: tripId)
            .order("created_at", ascending: true)
            .execute()
            .value

        return messages
    }

    func sendMessage(_ request: CreateChatMessageRequest) async throws -> ChatMessage {
        let message: ChatMessage = try await client
            .from(Tables.chatMessages)
            .insert(request)
            .select("*, profile:profiles!user_id(id, email, display_name, handle, avatar_url, created_at)")
            .single()
            .execute()
            .value

        return message
    }

    func observeMessages(tripId: String, onNewMessage: @escaping (ChatMessage) -> Void) -> any Cancellable {
        let channel = client.realtimeV2.channel("chat_\(tripId)")

        Task {
            await channel.onPostgresChange(
                InsertAction.self,
                schema: "public",
                table: Tables.chatMessages,
                filter: "trip_id=eq.\(tripId)"
            ) { [weak self] insert in
                guard self != nil else { return }
                // Fetch the full message with profile
                Task {
                    do {
                        let message: ChatMessage = try await self!.client
                            .from(Tables.chatMessages)
                            .select("*, profile:profiles!user_id(id, email, display_name, handle, avatar_url, created_at)")
                            .eq("id", value: insert.record["id"] as? String ?? "")
                            .single()
                            .execute()
                            .value

                        await MainActor.run {
                            onNewMessage(message)
                        }
                    } catch {
                        print("Error fetching new message: \(error)")
                    }
                }
            }

            await channel.subscribe()
        }

        return SubscriptionToken {
            Task {
                await channel.unsubscribe()
            }
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
        // Return a mock message
        return ChatMessage(
            id: UUID().uuidString,
            tripId: request.tripId,
            userId: request.userId,
            content: request.content,
            messageType: request.messageType,
            metadata: request.metadata,
            createdAt: Date()
        )
    }

    func observeMessages(tripId: String, onNewMessage: @escaping (ChatMessage) -> Void) -> any Cancellable {
        return SubscriptionToken { }
    }
}
