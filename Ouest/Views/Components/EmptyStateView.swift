import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                OuestButton(title: actionTitle, action: action)
                    .frame(width: 200)
            }
        }
        .padding(32)
    }
}

#Preview {
    EmptyStateView(
        icon: "airplane",
        title: "No Trips Yet",
        message: "Create your first trip to get started",
        actionTitle: "Create Trip",
        action: {}
    )
}
