import SwiftUI

/// Manages demo mode state and provides demo data
class DemoModeManager: ObservableObject {
    @AppStorage("isDemoMode") var isDemoMode: Bool = false

    func toggleDemoMode() {
        isDemoMode.toggle()
    }

    func setDemoMode(_ enabled: Bool) {
        isDemoMode = enabled
    }
}

// MARK: - Demo Data

extension DemoModeManager {

    // Demo user profile
    static let demoProfile = Profile(
        id: "demo-user-id",
        email: "demo@ouest.app",
        displayName: "Trey",
        handle: "trey",
        avatarUrl: nil,
        createdAt: Date()
    )

    // Demo trip members
    static let demoMembers: [Profile] = [
        Profile(id: "demo-user-1", email: "trey@ouest.app", displayName: "Trey", handle: "trey", avatarUrl: nil, createdAt: Date()),
        Profile(id: "demo-user-2", email: "jason@ouest.app", displayName: "Jason", handle: "jason", avatarUrl: nil, createdAt: Date()),
        Profile(id: "demo-user-3", email: "sandra@ouest.app", displayName: "Sandra", handle: "sandra", avatarUrl: nil, createdAt: Date()),
        Profile(id: "demo-user-4", email: "timmy@ouest.app", displayName: "Timmy", handle: "timmy", avatarUrl: nil, createdAt: Date())
    ]

    // Demo trips
    static let demoTrips: [Trip] = [
        Trip(
            id: "demo-trip-1",
            name: "Tokyo Adventure",
            destination: "Tokyo, Japan",
            startDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
            endDate: Calendar.current.date(byAdding: .day, value: 37, to: Date()),
            budget: 2400,
            currency: "CAD",
            createdBy: "demo-user-1",
            isPublic: true,
            votingEnabled: true,
            coverImage: nil,
            description: "Exploring the best of Tokyo - food, culture, and nightlife!",
            status: .upcoming,
            createdAt: Date()
        ),
        Trip(
            id: "demo-trip-2",
            name: "Paris Getaway",
            destination: "Paris, France",
            startDate: Calendar.current.date(byAdding: .month, value: 2, to: Date()),
            endDate: Calendar.current.date(byAdding: .month, value: 2, to: Calendar.current.date(byAdding: .day, value: 7, to: Date())!),
            budget: 3200,
            currency: "CAD",
            createdBy: "demo-user-1",
            isPublic: false,
            votingEnabled: true,
            coverImage: nil,
            description: "Romantic week in the City of Light",
            status: .planning,
            createdAt: Date()
        ),
        Trip(
            id: "demo-trip-3",
            name: "Barcelona Summer",
            destination: "Barcelona, Spain",
            startDate: Calendar.current.date(byAdding: .month, value: -4, to: Date()),
            endDate: Calendar.current.date(byAdding: .month, value: -4, to: Calendar.current.date(byAdding: .day, value: 7, to: Date())!),
            budget: 1800,
            currency: "CAD",
            createdBy: "demo-user-1",
            isPublic: true,
            votingEnabled: false,
            coverImage: nil,
            description: "Beach, tapas, and Gaudi architecture",
            status: .completed,
            createdAt: Calendar.current.date(byAdding: .month, value: -5, to: Date())!
        )
    ]

    // Demo expenses for Tokyo trip
    static let demoExpenses: [Expense] = [
        Expense(
            id: "demo-expense-1",
            tripId: "demo-trip-1",
            title: "Ramen at Ichiran",
            amount: 45.00,
            currency: "CAD",
            category: .food,
            paidBy: "demo-user-1",
            splitAmong: ["demo-user-1", "demo-user-2"],
            date: Date(),
            hasChat: false,
            createdAt: Date()
        ),
        Expense(
            id: "demo-expense-2",
            tripId: "demo-trip-1",
            title: "Shinkansen to Kyoto",
            amount: 280.00,
            currency: "CAD",
            category: .transport,
            paidBy: "demo-user-2",
            splitAmong: ["demo-user-1", "demo-user-2"],
            date: Date(),
            hasChat: false,
            createdAt: Date()
        ),
        Expense(
            id: "demo-expense-3",
            tripId: "demo-trip-1",
            title: "Shibuya Hotel",
            amount: 450.00,
            currency: "CAD",
            category: .stay,
            paidBy: "demo-user-1",
            splitAmong: ["demo-user-1", "demo-user-2"],
            date: Date(),
            hasChat: true,
            createdAt: Date()
        ),
        Expense(
            id: "demo-expense-4",
            tripId: "demo-trip-1",
            title: "TeamLab Borderless",
            amount: 64.00,
            currency: "CAD",
            category: .activities,
            paidBy: "demo-user-2",
            splitAmong: ["demo-user-1", "demo-user-2"],
            date: Date(),
            hasChat: false,
            createdAt: Date()
        )
    ]

    // Demo chat messages
    static let demoChatMessages: [ChatMessage] = [
        ChatMessage(
            id: "demo-msg-1",
            tripId: "demo-trip-1",
            userId: "demo-user-1",
            content: "Just booked the hotel! Check out the view from the room 🏨",
            messageType: .text,
            metadata: nil,
            createdAt: Calendar.current.date(byAdding: .hour, value: -2, to: Date())!
        ),
        ChatMessage(
            id: "demo-msg-2",
            tripId: "demo-trip-1",
            userId: "demo-user-2",
            content: "Nice! Can't wait for this trip",
            messageType: .text,
            metadata: nil,
            createdAt: Calendar.current.date(byAdding: .hour, value: -1, to: Date())!
        ),
        ChatMessage(
            id: "demo-msg-3",
            tripId: "demo-trip-1",
            userId: "demo-user-1",
            content: nil,
            messageType: .expense,
            metadata: ["expenseId": "demo-expense-3", "title": "Shibuya Hotel", "amount": 450.00],
            createdAt: Calendar.current.date(byAdding: .minute, value: -30, to: Date())!
        )
    ]

    // Demo saved itinerary items
    static let demoSavedItems: [SavedItineraryItem] = [
        SavedItineraryItem(
            id: "demo-saved-1",
            userId: "demo-user-1",
            activityName: "Senso-ji Temple",
            activityLocation: "Asakusa, Tokyo",
            activityTime: "9:00 AM",
            activityCost: "Free",
            activityDescription: "Tokyo's oldest temple with beautiful architecture",
            activityCategory: .activity,
            sourceTripLocation: "Tokyo, Japan",
            sourceTripUser: "demo-user-2",
            day: 1,
            createdAt: Date()
        ),
        SavedItineraryItem(
            id: "demo-saved-2",
            userId: "demo-user-1",
            activityName: "Tsukiji Outer Market",
            activityLocation: "Tsukiji, Tokyo",
            activityTime: "7:00 AM",
            activityCost: "~$30",
            activityDescription: "Fresh sushi and street food breakfast",
            activityCategory: .food,
            sourceTripLocation: "Tokyo, Japan",
            sourceTripUser: "demo-user-3",
            day: 2,
            createdAt: Date()
        )
    ]
}
