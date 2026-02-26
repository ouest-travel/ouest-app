import SwiftUI

struct OuestCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(OuestTheme.Spacing.lg)
            .background(OuestTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.lg))
            .shadow(OuestTheme.Shadow.md)
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
