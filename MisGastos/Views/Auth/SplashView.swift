import SwiftUI

struct SplashView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @State private var showMain = false
    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 8
    @State private var dotAnimating = false

    var body: some View {
        if showMain {
            if isLoggedIn { MainTabView() } else { LoginView() }
        } else {
            ZStack {
                LinearGradient.saGreen.ignoresSafeArea()

                VStack(spacing: 24) {
                    SABrandMark(size: 112)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)

                    VStack(spacing: 6) {
                        Text("Súper Ahorro")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.white)
                            .tracking(-1.4)
                        Text("Tus gastos del súper, bajo control")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .opacity(textOpacity)
                    .offset(y: textOffset)
                }

                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(Color.white)
                                .frame(width: 7, height: 7)
                                .opacity(dotAnimating ? 1.0 : 0.3)
                                .animation(
                                    .easeInOut(duration: 0.5)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(i) * 0.16),
                                    value: dotAnimating
                                )
                        }
                    }
                    .padding(.bottom, 64)
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    logoScale = 1.0
                    logoOpacity = 1.0
                }
                withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                    textOpacity = 1.0
                    textOffset = 0
                }
                dotAnimating = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                    withAnimation(.easeInOut(duration: 0.3)) { showMain = true }
                }
            }
        }
    }
}
