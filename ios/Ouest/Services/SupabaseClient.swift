import Foundation

// MARK: - App Configuration

enum Config {
    // App Bundle ID
    static let bundleId = "com.ouest.app"

    // Cloudinary config for image uploads (optional - for avatar uploads)
    static let cloudinaryCloudName = "your-cloud-name"
    static let cloudinaryUploadPreset = "ouest-avatars"

    // Future: Add Supabase credentials here when ready to enable cloud sync
    // static let supabaseURL = "https://your-project.supabase.co"
    // static let supabaseAnonKey = "your-anon-key"
}

// MARK: - Database Tables (for future cloud sync)

enum Tables {
    static let profiles = "profiles"
    static let trips = "trips"
    static let tripMembers = "trip_members"
    static let expenses = "expenses"
    static let chatMessages = "chat_messages"
    static let savedItineraryItems = "saved_itinerary_items"
    static let countriesVisited = "countries_visited"
    static let wishlist = "wishlist"
}
