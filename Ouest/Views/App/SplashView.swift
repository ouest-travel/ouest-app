import SwiftUI

struct SplashView: View {
    @State private var iconScale: CGFloat = 0.6
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var progressOpacity: Double = 0

    var body: some View {
        VStack(spacing: OuestTheme.Spacing.lg) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 64))
                .foregroundStyle(OuestTheme.Colors.brandGradient)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

            Text("Ouest")
                .font(OuestTheme.Typography.heroTitle)
                .opacity(textOpacity)

            ProgressView()
                .tint(OuestTheme.Colors.brand)
                .scaleEffect(1.1)
                .opacity(progressOpacity)
                .padding(.top, OuestTheme.Spacing.sm)
        }
        .onAppear {
            withAnimation(OuestTheme.Anim.bouncy) {
                iconScale = 1.0
                iconOpacity = 1
            }
            withAnimation(OuestTheme.Anim.smooth.delay(0.25)) {
                textOpacity = 1
            }
            withAnimation(OuestTheme.Anim.smooth.delay(0.5)) {
                progressOpacity = 1
            }
        }
    }
}

#Preview {
    SplashView()
}
