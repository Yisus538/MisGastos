import SwiftUI
import SwiftData

struct SplashView: View {
    @AppStorage("aparienciaMode") private var aparienciaRaw: String = "sistema"
    @Environment(\.modelContext)  private var modelContext
    @State private var showMain = false

    private let session = SessionStore.shared

    private var preferredScheme: ColorScheme? {
        (AparienciaMode(rawValue: aparienciaRaw) ?? .sistema).colorScheme
    }
    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 8
    @State private var dotAnimating = false

    var body: some View {
        if showMain {
            Group {
                // SessionStore es la única fuente de verdad: deriva de Supabase authStateChanges
                if session.isAuthenticated { MainTabView() } else { LoginView() }
            }
            .preferredColorScheme(preferredScheme)
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
            .preferredColorScheme(.dark)
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
                Task {
                    UserScopedStorage.shared.refreshExchangeRates()
                    // Restaurar sesión desde Keychain antes de cualquier operación.
                    await SupabaseService.shared.restaurarSesion()
                    if let remote = try? await SupabaseService.shared.fetchApariencia(),
                       AparienciaMode(rawValue: remote) != nil {
                        aparienciaRaw = remote
                    }
                    // Sincronizar membresía y datos de compras
                    await MembresiaService.shared.sincronizar()
                    await SyncService.shared.sincronizarPendientes(context: modelContext)
                    await SyncService.shared.pullDesdeSupabase(context: modelContext)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                    withAnimation(.easeInOut(duration: 0.3)) { showMain = true }
                }
            }
        }
    }
}
