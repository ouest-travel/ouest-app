import SwiftUI

struct OuestButton: View {
    let title: String
    var style: ButtonStyle = .primary
    var isLoading: Bool = false
    let action: () -> Void

    enum ButtonStyle {
        case primary
        case secondary
        case destructive
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isLoading)
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: .primary
        case .secondary: Color(.systemGray5)
        case .destructive: .red
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: Color(.systemBackground)
        case .secondary: .primary
        case .destructive: .white
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        OuestButton(title: "Primary", action: {})
        OuestButton(title: "Secondary", style: .secondary, action: {})
        OuestButton(title: "Loading", isLoading: true, action: {})
        OuestButton(title: "Delete", style: .destructive, action: {})
    }
    .padding()
}
