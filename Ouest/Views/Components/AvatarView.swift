import SwiftUI

struct AvatarView: View {
    let url: String?
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let url, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    placeholderView
                }
            } else {
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var placeholderView: some View {
        Circle()
            .fill(Color(.systemGray4))
            .overlay {
                Image(systemName: "person.fill")
                    .foregroundStyle(Color(.systemGray))
                    .font(.system(size: size * 0.4))
            }
    }
}

#Preview {
    HStack {
        AvatarView(url: nil, size: 32)
        AvatarView(url: nil, size: 48)
        AvatarView(url: nil, size: 64)
    }
}
