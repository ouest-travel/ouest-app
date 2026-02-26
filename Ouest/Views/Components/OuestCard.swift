import SwiftUI

struct OuestCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    OuestCard {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trip to Tokyo")
                .font(.headline)
            Text("March 15 - March 25")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    .padding()
}
