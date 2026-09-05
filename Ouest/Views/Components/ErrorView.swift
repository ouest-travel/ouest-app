import SwiftUI

struct ErrorView: View {
    let message: String
    var retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: OuestTheme.Icon.hero))
                .foregroundStyle(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let retryAction {
                OuestButton(title: "Try Again", style: .secondary, action: retryAction)
                    .frame(width: 160)
            }
        }
        .padding(32)
    }
}

#Preview {
    ErrorView(message: "Something went wrong", retryAction: {})
}

#Preview("Dark") {
    ErrorView(message: "Something went wrong", retryAction: {})
        .preferredColorScheme(.dark)
}
