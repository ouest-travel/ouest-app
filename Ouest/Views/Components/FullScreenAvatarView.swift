import SwiftUI

/// Full-screen avatar viewer with zoom and dismiss gesture.
struct FullScreenAvatarView: View {
    let url: String?
    let name: String?

    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black
                .ignoresSafeArea()
                .opacity(appeared ? 1 : 0)

            VStack(spacing: 0) {
                // Top bar with close button
                HStack {
                    Spacer()
                    Button {
                        withAnimation(OuestTheme.Anim.quick) {
                            appeared = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding()
                    .accessibilityLabel("Close")
                }

                Spacer()

                // Large avatar image
                avatarImage
                    .scaleEffect(scale)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                scale = lastScale * value.magnification
                            }
                            .onEnded { _ in
                                withAnimation(OuestTheme.Anim.bouncy) {
                                    scale = max(1.0, min(scale, 4.0))
                                    lastScale = scale
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(OuestTheme.Anim.bouncy) {
                            if scale > 1.0 {
                                scale = 1.0
                                lastScale = 1.0
                            } else {
                                scale = 2.5
                                lastScale = 2.5
                            }
                        }
                    }

                Spacer()

                // Name label
                if let name, !name.isEmpty {
                    Text(name)
                        .font(OuestTheme.Typography.cardTitle)
                        .foregroundStyle(.white)
                        .padding(.bottom, OuestTheme.Spacing.xxxl)
                        .opacity(appeared ? 1 : 0)
                }
            }
        }
        .onAppear {
            withAnimation(OuestTheme.Anim.smooth) {
                appeared = true
            }
        }
    }

    @ViewBuilder
    private var avatarImage: some View {
        if let url, let imageURL = URL(string: url) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .clipShape(Circle())
                        .shadow(color: .white.opacity(0.1), radius: 20)
                        .frame(maxWidth: 300, maxHeight: 300)
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.8)
                case .failure:
                    placeholderView
                case .empty:
                    ProgressView()
                        .tint(.white)
                @unknown default:
                    placeholderView
                }
            }
        } else {
            placeholderView
        }
    }

    private var placeholderView: some View {
        Circle()
            .fill(Color(.systemGray4))
            .frame(width: 200, height: 200)
            .overlay {
                Image(systemName: "person.fill")
                    .foregroundStyle(Color(.systemGray))
                    .font(.system(size: OuestTheme.Icon.hero))
            }
    }
}

#Preview {
    FullScreenAvatarView(url: nil, name: "Preview User")
}

#Preview("Dark") {
    FullScreenAvatarView(url: nil, name: "Preview User")
        .preferredColorScheme(.dark)
}
