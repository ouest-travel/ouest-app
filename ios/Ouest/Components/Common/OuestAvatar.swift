import SwiftUI

enum AvatarSize {
    case small      // 32pt
    case medium     // 40pt
    case large      // 56pt
    case xlarge     // 80pt

    var dimension: CGFloat {
        switch self {
        case .small: return 32
        case .medium: return 40
        case .large: return 56
        case .xlarge: return 80
        }
    }

    var font: Font {
        switch self {
        case .small: return .system(size: 12, weight: .semibold)
        case .medium: return .system(size: 14, weight: .semibold)
        case .large: return .system(size: 20, weight: .semibold)
        case .xlarge: return .system(size: 28, weight: .semibold)
        }
    }
}

struct OuestAvatar: View {
    let profile: Profile?
    let size: AvatarSize

    init(_ profile: Profile?, size: AvatarSize = .medium) {
        self.profile = profile
        self.size = size
    }

    var body: some View {
        Group {
            if let avatarUrl = profile?.avatarUrl,
               let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholderView
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholderView
                    @unknown default:
                        placeholderView
                    }
                }
            } else {
                placeholderView
            }
        }
        .frame(width: size.dimension, height: size.dimension)
        .clipShape(Circle())
    }

    private var placeholderView: some View {
        ZStack {
            OuestTheme.Gradients.primary
            Text(profile?.initials ?? "?")
                .font(size.font)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Avatar Group (for trip members)

struct OuestAvatarGroup: View {
    let profiles: [Profile]
    let maxDisplay: Int
    let size: AvatarSize

    init(_ profiles: [Profile], maxDisplay: Int = 3, size: AvatarSize = .small) {
        self.profiles = profiles
        self.maxDisplay = maxDisplay
        self.size = size
    }

    var body: some View {
        HStack(spacing: -8) {
            ForEach(Array(profiles.prefix(maxDisplay).enumerated()), id: \.element.id) { index, profile in
                OuestAvatar(profile, size: size)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .zIndex(Double(maxDisplay - index))
            }

            if profiles.count > maxDisplay {
                ZStack {
                    Circle()
                        .fill(OuestTheme.Colors.inputBackground)
                    Text("+\(profiles.count - maxDisplay)")
                        .font(size.font)
                        .foregroundColor(OuestTheme.Colors.textSecondary)
                }
                .frame(width: size.dimension, height: size.dimension)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            OuestAvatar(nil, size: .small)
            OuestAvatar(nil, size: .medium)
            OuestAvatar(nil, size: .large)
            OuestAvatar(nil, size: .xlarge)
        }

        OuestAvatar(
            Profile(
                id: "1",
                email: "test@test.com",
                displayName: "John Doe",
                handle: "johnd",
                avatarUrl: nil,
                createdAt: Date()
            ),
            size: .large
        )

        OuestAvatarGroup(DemoModeManager.demoMembers, maxDisplay: 3)
    }
    .padding()
}
