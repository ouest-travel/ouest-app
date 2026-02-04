export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export interface Database {
  public: {
    Tables: {
      profiles: {
        Row: {
          id: string
          email: string
          display_name: string | null
          handle: string | null
          avatar_url: string | null
          created_at: string
        }
        Insert: {
          id: string
          email: string
          display_name?: string | null
          handle?: string | null
          avatar_url?: string | null
          created_at?: string
        }
        Update: {
          id?: string
          email?: string
          display_name?: string | null
          handle?: string | null
          avatar_url?: string | null
          created_at?: string
        }
      }
      trips: {
        Row: {
          id: string
          name: string
          destination: string
          start_date: string | null
          end_date: string | null
          budget: number | null
          currency: string
          created_by: string
          is_public: boolean
          voting_enabled: boolean
          cover_image: string | null
          description: string | null
          status: 'planning' | 'upcoming' | 'active' | 'completed'
          created_at: string
        }
        Insert: {
          id?: string
          name: string
          destination: string
          start_date?: string | null
          end_date?: string | null
          budget?: number | null
          currency?: string
          created_by: string
          is_public?: boolean
          voting_enabled?: boolean
          cover_image?: string | null
          description?: string | null
          status?: 'planning' | 'upcoming' | 'active' | 'completed'
          created_at?: string
        }
        Update: {
          id?: string
          name?: string
          destination?: string
          start_date?: string | null
          end_date?: string | null
          budget?: number | null
          currency?: string
          created_by?: string
          is_public?: boolean
          voting_enabled?: boolean
          cover_image?: string | null
          description?: string | null
          status?: 'planning' | 'upcoming' | 'active' | 'completed'
          created_at?: string
        }
      }
      trip_members: {
        Row: {
          id: string
          trip_id: string
          user_id: string
          role: 'owner' | 'member'
          joined_at: string
        }
        Insert: {
          id?: string
          trip_id: string
          user_id: string
          role?: 'owner' | 'member'
          joined_at?: string
        }
        Update: {
          id?: string
          trip_id?: string
          user_id?: string
          role?: 'owner' | 'member'
          joined_at?: string
        }
      }
      expenses: {
        Row: {
          id: string
          trip_id: string
          title: string
          amount: number
          currency: string
          category: 'food' | 'transport' | 'stay' | 'activities' | 'other'
          paid_by: string
          split_among: string[]
          date: string
          has_chat: boolean
          created_at: string
        }
        Insert: {
          id?: string
          trip_id: string
          title: string
          amount: number
          currency?: string
          category?: 'food' | 'transport' | 'stay' | 'activities' | 'other'
          paid_by: string
          split_among: string[]
          date?: string
          has_chat?: boolean
          created_at?: string
        }
        Update: {
          id?: string
          trip_id?: string
          title?: string
          amount?: number
          currency?: string
          category?: 'food' | 'transport' | 'stay' | 'activities' | 'other'
          paid_by?: string
          split_among?: string[]
          date?: string
          has_chat?: boolean
          created_at?: string
        }
      }
      chat_messages: {
        Row: {
          id: string
          trip_id: string
          user_id: string
          content: string | null
          message_type: 'text' | 'expense' | 'summary'
          metadata: Json | null
          created_at: string
        }
        Insert: {
          id?: string
          trip_id: string
          user_id: string
          content?: string | null
          message_type?: 'text' | 'expense' | 'summary'
          metadata?: Json | null
          created_at?: string
        }
        Update: {
          id?: string
          trip_id?: string
          user_id?: string
          content?: string | null
          message_type?: 'text' | 'expense' | 'summary'
          metadata?: Json | null
          created_at?: string
        }
      }
      countries_visited: {
        Row: {
          id: string
          user_id: string
          country_code: string
          country_name: string
          visited_at: string
          notes: string | null
          created_at: string
        }
        Insert: {
          id?: string
          user_id: string
          country_code: string
          country_name: string
          visited_at?: string
          notes?: string | null
          created_at?: string
        }
        Update: {
          id?: string
          user_id?: string
          country_code?: string
          country_name?: string
          visited_at?: string
          notes?: string | null
          created_at?: string
        }
      }
      wishlist: {
        Row: {
          id: string
          user_id: string
          destination: string
          country_code: string | null
          country_name: string | null
          notes: string | null
          priority: 'low' | 'medium' | 'high'
          created_at: string
        }
        Insert: {
          id?: string
          user_id: string
          destination: string
          country_code?: string | null
          country_name?: string | null
          notes?: string | null
          priority?: 'low' | 'medium' | 'high'
          created_at?: string
        }
        Update: {
          id?: string
          user_id?: string
          destination?: string
          country_code?: string | null
          country_name?: string | null
          notes?: string | null
          priority?: 'low' | 'medium' | 'high'
          created_at?: string
        }
      }
      saved_itinerary_items: {
        Row: {
          id: string
          user_id: string
          activity_name: string
          activity_location: string
          activity_time: string | null
          activity_cost: string | null
          activity_description: string | null
          activity_category: 'food' | 'activity' | 'transport' | 'accommodation'
          source_trip_location: string | null
          source_trip_user: string | null
          day: number | null
          created_at: string
        }
        Insert: {
          id?: string
          user_id: string
          activity_name: string
          activity_location: string
          activity_time?: string | null
          activity_cost?: string | null
          activity_description?: string | null
          activity_category?: 'food' | 'activity' | 'transport' | 'accommodation'
          source_trip_location?: string | null
          source_trip_user?: string | null
          day?: number | null
          created_at?: string
        }
        Update: {
          id?: string
          user_id?: string
          activity_name?: string
          activity_location?: string
          activity_time?: string | null
          activity_cost?: string | null
          activity_description?: string | null
          activity_category?: 'food' | 'activity' | 'transport' | 'accommodation'
          source_trip_location?: string | null
          source_trip_user?: string | null
          day?: number | null
          created_at?: string
        }
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      [_ in never]: never
    }
  }
}

