// =============================================================================
// LoginView.swift — Pantalla de inicio de sesión con Face ID / Touch ID
// =============================================================================
// Rol en la app:
//   Formulario de inicio de sesión con email y contraseña que delega la
//   autenticación a `AuthViewModel` → `SupabaseService`. Incluye:
//   - Login con email + contraseña via Supabase Auth (JWT).
//   - Login biométrico automático (Face ID / Touch ID) si el usuario ya
//     había iniciado sesión anteriormente.
//   - Botones decorativos de Sign in with Apple y Google (no funcionales en TP).
//   - Link a recuperar contraseña y link a registrarse.
//
// Equivalente Android:
//   `LoginActivity` / `LoginFragment` con:
//   - `TextInputLayout` para email y contraseña.
//   - `BiometricPrompt` para la autenticación biométrica.
//   - `FirebaseAuth.signInWithEmailAndPassword()` para el login con contraseña.
//   - O en Compose: un `@Composable fun LoginScreen(viewModel: AuthViewModel)`.
//
// Patrón @Observable en SwiftUI:
//   `@State private var viewModel = AuthViewModel()` instancia el ViewModel
//   directamente en la View. `@Observable` (Swift 5.9) hace que SwiftUI detecte
//   automáticamente qué propiedades del ViewModel usa la vista y se re-renderice
//   solo cuando esas propiedades cambian.
//   Equivalente Android: `@HiltViewModel` + `by viewModels()` en Fragment/Activity,
//   o `viewModel<AuthViewModel>()` en Compose.
//
// Biometría con sesión de Supabase:
//   Face ID / Touch ID autentica al usuario en el dispositivo (Secure Enclave).
//   Si la autenticación biométrica es exitosa, se intenta restaurar la sesión
//   JWT desde el Keychain. Si el JWT expiró, se pide contraseña.
//   Equivalente Android: `BiometricPrompt` + `CryptoObject` para desencriptar el
//   token guardado en `EncryptedSharedPreferences`.
// =============================================================================

import SwiftUI

/// Pantalla de inicio de sesión de Súper Ahorro.
///
/// Flujo de autenticación:
/// 1. Usuario ingresa email + contraseña → `SAButton` → `viewModel.login()`.
/// 2. `AuthViewModel.login()` llama a `SupabaseService.shared.login(email:password:)`.
/// 3. Supabase devuelve un JWT que el SDK guarda en el Keychain automáticamente.
/// 4. `SessionStore` detecta el cambio de auth via `authStateChanges` y navega a `MainTabView`.
///
/// Equivalente Android: `LoginActivity` con `FirebaseAuth` o un `LoginScreen` en Compose.
struct LoginView: View {

    // MARK: - ViewModel

    /// ViewModel de autenticación — instanciado directamente con @State.
    ///
    /// `@State` en SwiftUI es el reemplazo de `@StateObject` para clases `@Observable`.
    /// No usar `@StateObject` con clases que conforman `@Observable` (no `ObservableObject`).
    @State private var viewModel = AuthViewModel()

    // MARK: - Estado de presentación de sheets

    /// Controla si se presenta la pantalla de registro.
    @State private var showRegister = false

    /// Controla si se presenta la pantalla de recuperar contraseña.
    @State private var showForgot = false

    // MARK: - Biometría

    /// Previene que el diálogo biométrico se muestre más de una vez al cargar la vista.
    @State private var didTryBiometric = false

    /// Email del último usuario que inició sesión — persiste en UserDefaults.
    ///
    /// Si `usuarioEmail` no está vacío, hay un usuario previo y se puede ofrecer
    /// el inicio de sesión biométrico como atajo.
    @AppStorage("usuarioEmail") private var usuarioEmail: String = ""

    /// Referencia al servicio biométrico para verificar disponibilidad y tipo.
    private let biometric = BiometricService.shared

    // MARK: - Propiedades computadas

    /// `true` si el dispositivo tiene biometría disponible y hay un usuario previo.
    ///
    /// Ambas condiciones deben cumplirse: tener Face ID/Touch ID no es suficiente
    /// si el usuario nunca inició sesión (no hay sesión guardada en el Keychain).
    private var showBiometric: Bool {
        biometric.isAvailable && !usuarioEmail.isEmpty
    }

    /// SF Symbol correspondiente al tipo de biometría disponible.
    private var biometricIcon: String {
        biometric.biometricType == .faceID ? "faceid" : "touchid"
    }

    /// Texto del botón biométrico según el hardware disponible.
    private var biometricLabel: String {
        biometric.biometricType == .faceID ? "Continuar con Face ID" : "Continuar con Touch ID"
    }

    // MARK: - Vista principal

    var body: some View {
        NavigationStack {
            ZStack {
                Color.saBg.ignoresSafeArea()  // Fondo adaptativo claro/oscuro

                VStack(spacing: 0) {
                    // Contenido scrollable para adaptarse a pantallas pequeñas o con teclado
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {

                            // Logo de la app
                            SABrandMark(size: 64)
                                .padding(.top, 60)
                                .padding(.bottom, 24)

                            // Título y subtítulo de bienvenida
                            Text("Bienvenido")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(Color.saLabel)
                                .tracking(-1)
                            Text("Iniciá sesión para seguir ahorrando")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.saLabel3)
                                .padding(.top, 8)
                                .padding(.bottom, 32)

                            // Campos de formulario
                            VStack(spacing: 12) {
                                // Campo de email con tipo de teclado y autocompletar del sistema
                                SAField(placeholder: "Correo electrónico", text: $viewModel.email, icon: "envelope")
                                    .textContentType(.emailAddress)    // iOS autocompletar desde Keychain
                                    .keyboardType(.emailAddress)       // Teclado con @ y . visibles
                                    .textInputAutocapitalization(.never)  // No capitalizar email
                                // Campo de contraseña oculta con toggle de visibilidad
                                SAField(placeholder: "Contraseña", text: $viewModel.password, icon: "lock", isSecure: true)
                            }

                            // Link de recuperar contraseña
                            HStack {
                                Spacer()
                                Button("¿Olvidaste tu contraseña?") { showForgot = true }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.saGreen)
                            }
                            .padding(.top, 14)
                            .padding(.bottom, 28)

                            // Mensaje de error (visible solo si hay error en el ViewModel)
                            if let error = viewModel.errorMessage {
                                Text(error).font(.caption).foregroundStyle(Color.saDanger)
                                    .padding(.bottom, 8)
                            }

                            // Botón principal de login — deshabilita durante la carga
                            SAButton(title: "Iniciar sesión", isLoading: viewModel.isLoading) {
                                Task { await viewModel.login() }
                            }

                            // Divisor "o continuá con"
                            HStack(spacing: 12) {
                                Rectangle().fill(Color.saSep).frame(height: 0.5)
                                Text("o continuá con")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.saLabel3)
                                Rectangle().fill(Color.saSep).frame(height: 0.5)
                            }
                            .padding(.vertical, 26)

                            // Botones sociales (decorativos — OAuth no implementado en TP)
                            // Equivalente Android: FirebaseUI Auth o Identity Platform de Google
                            HStack(spacing: 12) {
                                socialBtn(icon: "apple.logo", label: "Apple")
                                socialBtn(icon: "globe", label: "Google")
                            }

                            // Botón de biometría — solo visible si hay sesión previa y biometría disponible
                            if showBiometric {
                                Button {
                                    Task {
                                        // 1. Solicitar autenticación biométrica al Secure Enclave
                                        let ok = await biometric.authenticate(reason: "Accedé a Súper Ahorro")
                                        if ok {
                                            // 2. Si Face ID aprueba, intentar restaurar sesión JWT del Keychain
                                            // Equivalente Android: desencriptar token de EncryptedSharedPreferences
                                            await SupabaseService.shared.restaurarSesion()
                                            if !SupabaseService.shared.isSessionActive {
                                                // El JWT expiró — no hay forma de renovarlo sin contraseña
                                                viewModel.errorMessage = "Tu sesión expiró. Iniciá sesión con tu contraseña."
                                            }
                                            // Si isSessionActive == true, SessionStore detectará el cambio
                                            // de authStateChanges y navegará automáticamente a MainTabView
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: biometricIcon)
                                            .font(.system(size: 20))
                                        Text(biometricLabel)
                                            .font(.system(size: 15, weight: .semibold))
                                    }
                                    .foregroundStyle(Color.saGreen)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.saGreenBg)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 12)
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    // Link de registro — anclado en la parte inferior de la pantalla
                    HStack(spacing: 4) {
                        Text("¿No tenés cuenta?")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.saLabel3)
                        Button("Registrate") { showRegister = true }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.saGreen)
                    }
                    .padding(.vertical, 24)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            // Intento automático de biometría al aparecer la pantalla (primera vez)
            .task {
                // Solo intentar si hay biometría disponible y no se intentó antes
                guard showBiometric, !didTryBiometric else { return }
                didTryBiometric = true
                // Delay para que la animación de transición termine antes del diálogo del sistema
                // Sin este delay, el diálogo puede aparecer antes de que la vista sea visible
                try? await Task.sleep(for: .milliseconds(600))
                let ok = await biometric.authenticate(reason: "Accedé a Súper Ahorro")
                if ok {
                    await SupabaseService.shared.restaurarSesion()
                    if !SupabaseService.shared.isSessionActive {
                        viewModel.errorMessage = "Tu sesión expiró. Iniciá sesión con tu contraseña."
                    }
                }
            }
            .sheet(isPresented: $showRegister) { RegisterView() }
            .sheet(isPresented: $showForgot) { ForgotPasswordView() }
        }
    }

    // MARK: - Botón de red social

    /// Construye un botón de login social (Apple, Google) con estilo consistente.
    ///
    /// Estos botones son decorativos en el TP — OAuth requiere configuración adicional
    /// en Supabase (URL scheme, redirect URL) y en Xcode (Associated Domains).
    ///
    /// `@ViewBuilder` permite que esta función retorne vistas SwiftUI condicionales.
    @ViewBuilder
    private func socialBtn(icon: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(Color.saLabel)
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.saLabel)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(Color.saCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.saSep, lineWidth: 0.5)
        )
    }
}
