import Foundation
import Supabase

/// Supabase client singleton for database operations
class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        // TODO: Replace with your actual Supabase credentials
        // These should ideally come from environment/config
        let supabaseURL = URL(string: Config.supabaseURL)!
        let supabaseKey = Config.supabaseAnonKey

        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
    }

    // MARK: - Auth

    var auth: AuthClient {
        client.auth
    }

    // MARK: - Database

    func from(_ table: String) -> PostgrestQueryBuilder {
        client.from(table)
    }

    // MARK: - Realtime

    var realtime: RealtimeClientV2 {
        client.realtimeV2
    }

    func channel(_ name: String) -> RealtimeChannelV2 {
        client.realtimeV2.channel(name)
    }
}

// MARK: - Configuration

enum Config {
    // TODO: Replace these with your actual Supabase credentials
    // For production, use environment variables or a secure config

    static let supabaseURL = "https://your-project.supabase.co"
    static let supabaseAnonKey = "your-anon-key"

    // Cloudinary config for image uploads
    static let cloudinaryCloudName = "your-cloud-name"
    static let cloudinaryUploadPreset = "ouest-avatars"
}

// MARK: - Database Tables

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
