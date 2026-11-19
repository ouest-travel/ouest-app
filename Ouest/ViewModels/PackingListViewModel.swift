import Foundation
import Observation

/// One shared packing list per trip. Every member can add, tick and claim
/// items; the view model keeps the list optimistic so a tap feels instant
/// and rolls back with a toast if the write fails.
@MainActor @Observable
final class PackingListViewModel {

    // MARK: - List State

    var items: [PackingItem] = []
    var members: [TripMember] = []
    var isLoading = false

    var failure: OuestError?
    var failureDetail: String?
    var toast: OuestToast?

    // MARK: - Form State

    var newTitle = ""
    var newCategory: PackingCategory = .essentials
    var newAssignee: UUID?
    var isSaving = false

    // MARK: - Internal

    let trip: Trip
    private(set) var currentUserId: UUID?

    init(trip: Trip) {
        self.trip = trip
    }

    // MARK: - Computed

    var isFormValid: Bool {
        !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var packedCount: Int { items.filter(\.isPacked).count }
    var totalCount: Int { items.count }
    var progress: Double { totalCount == 0 ? 0 : Double(packedCount) / Double(totalCount) }
    var isEverythingPacked: Bool { totalCount > 0 && packedCount == totalCount }

    /// Items grouped in the fixed category order, empty categories dropped.
    /// Packed items sink to the bottom of their group so what's left to do
    /// stays at the top.
    var sections: [(category: PackingCategory, items: [PackingItem])] {
        PackingCategory.allCases.compactMap { category in
            let group = items.filter { $0.category == category }
            guard !group.isEmpty else { return nil }
            let sorted = group.sorted { lhs, rhs in
                if lhs.isPacked != rhs.isPacked { return !lhs.isPacked }
                return (lhs.createdAt ?? .distantPast) < (rhs.createdAt ?? .distantPast)
            }
            return (category, sorted)
        }
    }

    func member(for userId: UUID?) -> TripMember? {
        guard let userId else { return nil }
        return members.first { $0.userId == userId }
    }

    // MARK: - Load

    func load() async {
        isLoading = items.isEmpty
        failure = nil
        failureDetail = nil
        do {
            currentUserId = try await SupabaseManager.client.auth.session.user.id
            async let itemsTask = PackingService.fetchItems(tripId: trip.id)
            async let membersTask = TripService.fetchMembers(tripId: trip.id)
            items = try await itemsTask
            members = try await membersTask
        } catch {
            failure = OuestError(error)
            failureDetail = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Add

    func addItem() async -> Bool {
        guard let userId = currentUserId, isFormValid else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            let payload = CreatePackingItemPayload(
                tripId: trip.id,
                title: newTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                category: newCategory,
                assignedTo: newAssignee,
                createdBy: userId
            )
            let item = try await PackingService.createItem(payload)
            items.append(item)
            resetForm(keepingCategory: true)
            return true
        } catch {
            toast = .failure("Couldn't add that item")
            failureDetail = error.localizedDescription
            return false
        }
    }

    /// Seeds the destination-agnostic starter list so an empty trip has
    /// something to tick off. Only offered while the list is empty.
    func addStarterItems() async {
        guard let userId = currentUserId, items.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let payloads = PackingItem.starterItems.map {
                CreatePackingItemPayload(
                    tripId: trip.id, title: $0.title, category: $0.category,
                    assignedTo: nil, createdBy: userId
                )
            }
            items = try await PackingService.createItems(payloads)
        } catch {
            toast = .failure("Couldn't add the starter list")
            failureDetail = error.localizedDescription
        }
    }

    // MARK: - Toggle (optimistic)

    func togglePacked(_ item: PackingItem) async {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let previous = items[index]
        items[index].isPacked.toggle()
        do {
            let updated = try await PackingService.updateItem(
                id: item.id, UpdatePackingItemPayload(isPacked: items[index].isPacked)
            )
            if let i = items.firstIndex(where: { $0.id == item.id }) { items[i] = updated }
        } catch {
            if let i = items.firstIndex(where: { $0.id == item.id }) { items[i] = previous }
            toast = .failure("Couldn't update \(item.title)")
            failureDetail = error.localizedDescription
        }
    }

    // MARK: - Assign (optimistic)

    func assign(_ item: PackingItem, to userId: UUID?) async {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let previous = items[index]
        items[index].assignedTo = userId
        items[index].assignee = member(for: userId)?.profile
        do {
            var payload = UpdatePackingItemPayload()
            if let userId { payload.assignedTo = userId } else { payload.clearAssignee = true }
            let updated = try await PackingService.updateItem(id: item.id, payload)
            if let i = items.firstIndex(where: { $0.id == item.id }) { items[i] = updated }
        } catch {
            if let i = items.firstIndex(where: { $0.id == item.id }) { items[i] = previous }
            toast = .failure("Couldn't change who's bringing \(item.title)")
            failureDetail = error.localizedDescription
        }
    }

    // MARK: - Delete

    func delete(_ item: PackingItem) async {
        let previous = items
        items.removeAll { $0.id == item.id }
        do {
            try await PackingService.deleteItem(id: item.id)
        } catch {
            items = previous
            toast = .failure("Couldn't remove \(item.title)")
            failureDetail = error.localizedDescription
        }
    }

    /// Mirrors the RLS delete policy: the item's creator or the trip owner.
    func canDelete(_ item: PackingItem) -> Bool {
        guard let userId = currentUserId else { return false }
        return item.createdBy == userId || trip.createdBy == userId
    }

    // MARK: - Form

    func resetForm(keepingCategory: Bool = false) {
        newTitle = ""
        if !keepingCategory { newCategory = .essentials }
        newAssignee = nil
        isSaving = false
    }
}
