# Ouest - Architecture Guide

## Overview

Ouest is a native iOS travel app built with SwiftUI (iOS 17+) and Supabase. The app follows MVVM architecture with a clear separation between Views, ViewModels, Services, and Models.

## Tech Stack

- **UI**: SwiftUI (iOS 17+)
- **Language**: Swift 6
- **Architecture**: MVVM with @Observable
- **Backend**: Supabase (PostgreSQL, Auth, Realtime, Storage, Edge Functions)
- **Networking**: supabase-swift SDK
- **Package Manager**: Swift Package Manager

## Project Structure

```
Ouest/
├── Models/          — Codable structs matching Supabase tables
├── ViewModels/      — @Observable classes with business logic
├── Views/           — SwiftUI views organized by feature
├── Services/        — Supabase API call layer
├── Utilities/       — Constants, extensions, validators
├── Configuration/   — xcconfig files for Supabase keys
└── Resources/       — Assets, Info.plist
```

## Data Flow

```
Supabase DB → Service (async func) → ViewModel (@Observable) → View (SwiftUI)
```

1. **Service** functions make async calls to Supabase and return typed data
2. **ViewModels** call services, manage state, and handle errors
3. **Views** observe ViewModels via `@Observable` and render UI

## Architecture Decisions

### MVVM with @Observable (iOS 17+)
ViewModels use the `@Observable` macro instead of `ObservableObject`/`@Published`. This provides automatic observation without explicit property wrappers.

### @MainActor ViewModels
All ViewModels are `@MainActor` to ensure UI state mutations happen on the main thread. This is simpler than manually dispatching and works well with SwiftUI.

### Service Layer
Services are stateless — they're collections of async functions that call Supabase. ViewModels own the state. This makes services easy to test and reuse.

### Environment-based Dependency Injection
ViewModels are passed through SwiftUI's `.environment()` modifier, making them available to the entire view hierarchy without manual prop drilling.

## Authentication

1. App launches → `ContentView` calls `authViewModel.restoreSession()`
2. If session exists → show `MainTabView`
3. If no session → show `LoginView`
4. Supabase handles JWT token storage in Keychain automatically

## Security

- Supabase keys stored in `.xcconfig` files (gitignored)
- Keys injected into Info.plist at build time via `$(SUPABASE_URL)` substitution
- Only the `anon` key is used in the client — never `service_role`
- All Supabase tables have Row Level Security (RLS) enabled
- Input validation before all Supabase operations

## Navigation

- `ContentView` — root, handles auth routing
- `MainTabView` — 5 tabs: Home, Explore, Create, Activity, Profile
- `NavigationStack` per tab for push navigation
- Sheets for modals (create, edit, settings)

## Feature Phases

| Phase | Feature | Status |
|-------|---------|--------|
| 0 | Project Scaffolding | Complete |
| 1 | Authentication | Pending |
| 2 | Trip Management | Pending |
| 3 | Itinerary Builder | Pending |
| 4 | Expenses & Splitting | Pending |
| 5 | Social / Community | Pending |
| 6 | Entry Requirements | Pending |
| 7 | Profile & Settings | Pending |
| 8 | Travel Journal | Pending |
| 9 | Collaborative Voting | Pending |
| 10 | QR Code & Link Sharing | Pending |
| 11 | Trip Chat | Pending |
| 12 | Notifications & Polish | Pending |
| 13 | App Store Prep | Pending |
