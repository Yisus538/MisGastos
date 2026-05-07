import SwiftUI
import SwiftData

@main
struct MisGastosApp: App {
    var body: some Scene {
        WindowGroup {
            AppLockWrapper()
        }
        .modelContainer(for: [Compra.self, Producto.self, Usuario.self])
    }
}

// MARK: - AppLockWrapper

struct AppLockWrapper: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isLocked = false
    @State private var session  = SessionStore.shared

    var body: some View {
        ZStack {
            SplashView()
                .task {
                    // Inicializa SessionStore para que suscriba a authStateChanges de Supabase
                    // antes de que SplashView decida el routing (2.2s de animación de margen).
                    _ = SessionStore.shared
                }

            if isLocked {
                AppLockView { withAnimation(.easeOut(duration: 0.25)) { isLocked = false } }
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeOut(duration: 0.25), value: isLocked)
        .onChange(of: scenePhase) { _, phase in
            // Bloquear al ir a background, solo si hay sesión activa y biometría disponible
            if phase == .background && session.isAuthenticated && BiometricService.shared.isAvailable {
                isLocked = true
            }
        }
        .onChange(of: session.isAuthenticated) { _, authenticated in
            // Al cerrar sesión, quitar el lock si estaba puesto
            if !authenticated { isLocked = false }
        }
    }
}

// MARK: - AppLockView

struct AppLockView: View {
    let onUnlock: () -> Void

    @State private var isAuthenticating = false
    @State private var failed = false

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                SABrandMark(size: 88)
                    .padding(.bottom, 28)

                Text("Súper Ahorro")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.saLabel)
                    .tracking(-1.2)
                    .padding(.bottom, 8)

                Text("Autenticá para continuar")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.saLabel3)

                Spacer()

                // Botón biométrico
                VStack(spacing: 14) {
                    if failed {
                        Text("No se pudo autenticar. Intentá de nuevo.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.saDanger)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: authenticate) {
                        HStack(spacing: 10) {
                            Image(systemName: biometricIcon)
                                .font(.system(size: 22, weight: .medium))
                            Text(biometricLabel)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(LinearGradient.saGreen, in: RoundedRectangle(cornerRadius: 16))
                        .opacity(isAuthenticating ? 0.7 : 1)
                    }
                    .disabled(isAuthenticating)
                    .padding(.horizontal, 28)
                }
                .padding(.bottom, 52)
            }
        }
        .onAppear {
            // Disparar Face ID automáticamente al aparecer el lock
            authenticate()
        }
    }

    private var biometricIcon: String {
        BiometricService.shared.biometricType == .faceID ? "faceid" : "touchid"
    }

    private var biometricLabel: String {
        let name = BiometricService.shared.biometricType == .faceID ? "Face ID" : "Touch ID"
        return failed ? "Reintentar con \(name)" : "Continuar con \(name)"
    }

    private func authenticate() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        failed = false
        Task {
            let ok = await BiometricService.shared.authenticate(
                reason: "Autenticá para acceder a Súper Ahorro"
            )
            isAuthenticating = false
            if ok {
                onUnlock()
            } else {
                withAnimation { failed = true }
            }
        }
    }
}
