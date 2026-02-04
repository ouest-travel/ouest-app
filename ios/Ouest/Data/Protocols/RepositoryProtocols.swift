import Foundation

// MARK: - Repository Protocols

/// Base protocol for all repositories
protocol Repository {
    associatedtype Model: Identifiable

    func getAll() async throws -> [Model]
    func get(by id: String) async throws -> Model?
    func create(_ model: Model) async throws -> Model
    func update(_ model: Model) async throws -> Model
    func delete(id: String) async throws
}

// MARK: - Trip Repository Protocol

protocol TripRepositoryProtocol {
    func getUserTrips(userId: String) async throws -> [Trip]
    func getPublicTrips() async throws -> [Trip]
    func getTrip(id: String) async throws -> Trip?
    func createTrip(_ request: CreateTripRequest) async throws -> Trip
    func updateTrip(id: String, _ request: UpdateTripRequest) async throws -> Trip
    func deleteTrip(id: String) async throws

    /// Real-time subscription
    func observeTrips(userId: String, onChange: @escaping ([Trip]) -> Void) -> any Cancellable
}

// MARK: - Expense Repository Protocol

protocol ExpenseRepositoryProtocol {
    func getExpenses(tripId: String) async throws -> [Expense]
    func createExpense(_ request: CreateExpenseRequest) async throws -> Expense
    func updateExpense(id: String, _ request: CreateExpenseRequest) async throws -> Expense
    func deleteExpense(id: String) async throws

    /// Real-time subscription
    func observeExpenses(tripId: String, onChange: @escaping ([Expense]) -> Void) -> any Cancellable
}

// MARK: - Profile Repository Protocol

protocol ProfileRepositoryProtocol {
    func getProfile(userId: String) async throws -> Profile?
    func updateProfile(userId: String, displayName: String?, handle: String?, avatarUrl: String?) async throws -> Profile
    func getProfileStats(userId: String) async throws -> ProfileStats
}

// MARK: - Chat Repository Protocol

protocol ChatRepositoryProtocol {
    func getMessages(tripId: String) async throws -> [ChatMessage]
    func sendMessage(_ request: CreateChatMessageRequest) async throws -> ChatMessage

    /// Real-time subscription
    func observeMessages(tripId: String, onNewMessage: @escaping (ChatMessage) -> Void) -> any Cancellable
}

// MARK: - Trip Member Repository Protocol

protocol TripMemberRepositoryProtocol {
    func getMembers(tripId: String) async throws -> [TripMember]
    func addMember(_ request: CreateTripMemberRequest) async throws -> TripMember
    func removeMember(id: String) async throws
    func updateRole(memberId: String, role: MemberRole) async throws -> TripMember
}

// MARK: - Saved Itinerary Repository Protocol

protocol SavedItineraryRepositoryProtocol {
    func getSavedItems(userId: String) async throws -> [SavedItineraryItem]
    func saveItem(_ request: CreateSavedItineraryItemRequest) async throws -> SavedItineraryItem
    func removeItem(id: String) async throws
}

// MARK: - Cancellable Protocol

protocol Cancellable {
    func cancel()
}

// MARK: - Subscription Token

class SubscriptionToken: Cancellable {
    private var onCancel: (() -> Void)?

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        onCancel?()
        onCancel = nil
    }

    deinit {
        cancel()
    }
}
