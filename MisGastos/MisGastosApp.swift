// =============================================================================
// MisGastosApp.swift — Entry point de la aplicación iOS "Súper Ahorro"
// =============================================================================
// Rol en la app:
//   Archivo de entrada de la aplicación. Define el `@main` struct que conforme
//   al protocolo `App` de SwiftUI, configura el `modelContainer` de SwiftData
//   y presenta la View raíz (`AppLockWrapper`).
//
// Equivalente Android:
//   Equivale a `Application.kt` (donde se inicializaría Room, Hilt, etc.) +
//   `MainActivity.kt` (que llama `setContent { AppNavHost() }`).
//   El `@main` equivale al atributo `android:name` en `AndroidManifest.xml` para
//   la clase Application, combinado con el `Intent-filter` de `MAIN` + `LAUNCHER`.
//
// `modelContainer(for:)`:
//   Configura SwiftData para persistir las entidades `Compra`, `Producto` y `Usuario`
//   en SQLite local. Equivalente Android: `Room.databaseBuilder()` en `Application.kt`,
//   o la anotación `@Database` en la clase Room Database.
//   Todos los `@Model` deben estar declarados aquí para que SwiftData los incluya
//   en el esquema de la base de datos.
//
// `AppLockWrapper` — Capa de bloqueo biométrico:
//   View contenedora que agrega una capa de seguridad sobre `SplashView`.
//   Cuando la app pasa a background (`scenePhase == .background`) con una sesión
//   activa y biometría disponible, muestra `AppLockView` (pantalla de desbloqueo).
//   Equivalente Android: `Activity.onPause()` con `BiometricPrompt.authenticate()`,
//   o el uso de `AppLockManager` con `FLAG_SECURE`.
//
// `AppLockView` — Pantalla de desbloqueo biométrico:
//   View que se superpone con transición de opacidad cuando la app está bloqueada.
//   Se desbloquea via `BiometricService.shared.authenticate()` (Face ID / Touch ID).
//   El bloqueo se activa al ir a background y se desactiva al autenticarse
//   o al cerrar sesión (si no hay sesión, no tiene sentido bloquear).
//
// `@Environment(\.scenePhase)`:
//   Permite observar los cambios de estado del ciclo de vida de la app:
//   `.active` (foreground), `.inactive` (transitioning), `.background`.
//   Equivalente Android: `ProcessLifecycleOwner` + `LifecycleObserver` con
//   `onStop()` y `onStart()`, o `AppLifecycleObserver` de Jetpack.
// =============================================================================

import SwiftUI
import SwiftData

// MARK: - Entry point

/// Punto de entrada de la app Súper Ahorro.
///
/// La anotación `@main` indica al sistema operativo que este struct es el entry point.
/// Equivalente Android: `<application android:name=".MyApp">` en `AndroidManifest.xml`.
@main
struct MisGastosApp: App {

    var body: some Scene {
        WindowGroup {
            // `AppLockWrapper` envuelve `SplashView` y agrega la capa de bloqueo biométrico
            AppLockWrapper()
        }
        // Configurar SwiftData con las tres entidades `@Model` de la app.
        // SwiftData crea automáticamente la base de datos SQLite si no existe
        // y aplica migraciones cuando el esquema cambia.
        // Equivalente Android: `Room.databaseBuilder(context, AppDatabase::class.java, "super_ahorro.db").build()`
        .modelContainer(for: [Compra.self, Producto.self, Usuario.self])
    }
}

// MARK: - AppLockWrapper — Capa de bloqueo biométrico

/// View contenedora que detecta cambios de ciclo de vida y bloquea la app al ir a background.
///
/// Estrategia:
/// - `@Environment(\.scenePhase)` observa el estado de la escena (active/inactive/background).
/// - Cuando pasa a background con sesión activa + biometría disponible → `isLocked = true`.
/// - `AppLockView` se superpone con animación de opacidad (`.zIndex(1)` para estar sobre todo).
/// - Al cerrar sesión, `isLocked = false` automáticamente (no tiene sentido el lock sin sesión).
///
/// Equivalente Android: `Activity.onPause()` / `onStop()` con `BiometricPrompt`,
/// o `SecureActivity` que verifica autenticación al entrar en `onResume()`.
struct AppLockWrapper: View {

    // MARK: - Ciclo de vida

    /// Estado de la escena (active / inactive / background).
    /// Equivalente Android: `ProcessLifecycleOwner.get().lifecycle.addObserver(...)`.
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Estado

    /// `true` cuando la app está bloqueada y debe mostrar `AppLockView`.
    @State private var isLocked = false

    /// Singleton de sesión — para saber si hay usuario autenticado antes de bloquear.
    @State private var session  = SessionStore.shared

    var body: some View {
        ZStack {
            // Vista principal de la app — siempre presente debajo del lock
            SplashView()
                .task {
                    // Inicializar `SessionStore` para que suscriba a `authStateChanges`
                    // de Supabase ANTES de que `SplashView` decida el routing.
                    // Los 2.2s de animación del splash dan margen para que llegue el
                    // primer evento de autenticación del SDK.
                    _ = SessionStore.shared
                }

            // Capa de bloqueo biométrico — solo visible cuando `isLocked == true`
            if isLocked {
                AppLockView { withAnimation(.easeOut(duration: 0.25)) { isLocked = false } }
                    .transition(.opacity)  // Aparece/desaparece con fade
                    .zIndex(1)             // Asegura que está sobre `SplashView`
            }
        }
        .animation(.easeOut(duration: 0.25), value: isLocked)
        .onChange(of: scenePhase) { _, phase in
            // Bloquear al pasar a background, solo si:
            // 1. El usuario está autenticado (hay sesión activa)
            // 2. El dispositivo soporta biometría (Face ID o Touch ID disponible)
            if phase == .background && session.isAuthenticated && BiometricService.shared.isAvailable {
                isLocked = true
            }
        }
        .onChange(of: session.isAuthenticated) { _, authenticated in
            // Al cerrar sesión: quitar el lock automáticamente.
            // No tiene sentido mantener la pantalla de bloqueo si ya no hay sesión.
            if !authenticated { isLocked = false }
        }
    }
}

// MARK: - AppLockView — Pantalla de desbloqueo

/// Pantalla de bloqueo que requiere autenticación biométrica (Face ID / Touch ID)
/// para desbloquear la app cuando vuelve del background.
///
/// Equivalente Android:
///   `BiometricPrompt.authenticate(...)` dentro de `onResume()` de la Activity,
///   con un `PromptInfo` que incluye el título "Autenticá para continuar".
///   En Android se puede usar `BiometricPrompt` + `CryptObject` para mayor seguridad
///   (vincular la biometría con una clave en el Keystore), pero en este TP se usa
///   la versión simple sin crypto.
struct AppLockView: View {

    // MARK: - Callback

    /// Se llama cuando la autenticación biométrica es exitosa.
    let onUnlock: () -> Void

    // MARK: - Estado

    /// `true` mientras se espera la respuesta del sistema biométrico.
    @State private var isAuthenticating = false

    /// `true` si el último intento de autenticación falló.
    @State private var failed = false

    // MARK: - Vista principal

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo de la app
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

                // Botón biométrico y mensaje de error
                VStack(spacing: 14) {
                    // Mensaje de error — visible solo si el último intento falló
                    if failed {
                        Text("No se pudo autenticar. Intentá de nuevo.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.saDanger)
                            .multilineTextAlignment(.center)
                    }

                    // Botón de desbloqueo biométrico
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
                        .opacity(isAuthenticating ? 0.7 : 1)  // Feedback visual de estado loading
                    }
                    .disabled(isAuthenticating)
                    .padding(.horizontal, 28)
                }
                .padding(.bottom, 52)
            }
        }
        .onAppear {
            // Disparar Face ID automáticamente al aparecer la pantalla de lock.
            // Evita que el usuario tenga que tocar el botón manualmente la primera vez.
            authenticate()
        }
    }

    // MARK: - Helpers

    /// Nombre del SF Symbol correspondiente al tipo de biometría disponible.
    ///
    /// `BiometricService.shared.biometricType` detecta si el dispositivo usa Face ID o Touch ID
    /// via `LAContext().biometryType`. Equivalente Android: `BiometricManager.canAuthenticate()`.
    private var biometricIcon: String {
        BiometricService.shared.biometricType == .faceID ? "faceid" : "touchid"
    }

    /// Etiqueta del botón que cambia según el tipo de biometría y si hubo un intento fallido.
    private var biometricLabel: String {
        let name = BiometricService.shared.biometricType == .faceID ? "Face ID" : "Touch ID"
        return failed ? "Reintentar con \(name)" : "Continuar con \(name)"
    }

    // MARK: - Autenticación

    /// Llama a `BiometricService` para autenticar con Face ID o Touch ID.
    ///
    /// `BiometricService.shared.authenticate()` usa `LAContext.evaluatePolicy()`
    /// internamente. El resultado llega en el `Task` en el main thread.
    ///
    /// Si la autenticación es exitosa, llama `onUnlock()` que anima la desaparición
    /// de esta view. Si falla (usuario cancela, no reconoce la cara/huella, etc.),
    /// muestra el mensaje de error y permite reintentar.
    ///
    /// Equivalente Android: `biometricPrompt.authenticate(promptInfo, cryptoObject)`
    /// con callbacks `onAuthenticationSucceeded` y `onAuthenticationError`.
    private func authenticate() {
        guard !isAuthenticating else { return }  // Evitar llamadas concurrentes
        isAuthenticating = true
        failed = false
        Task {
            let ok = await BiometricService.shared.authenticate(
                reason: "Autenticá para acceder a Súper Ahorro"
            )
            isAuthenticating = false
            if ok {
                onUnlock()  // Llama al closure que quita el lock con animación
            } else {
                withAnimation { failed = true }  // Mostrar mensaje de error animado
            }
        }
    }
}
