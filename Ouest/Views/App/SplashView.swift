import SwiftUI

struct SplashView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 64))
                .foregroundStyle(.primary)

            Text("Ouest")
                .font(.largeTitle)
                .fontWeight(.bold)

            ProgressView()
                .padding(.top, 8)
        }
    }
}

#Preview {
    SplashView()
}
