// =============================================================================
// SessionStore.swift — Fuente de verdad del estado de autenticación
// =============================================================================
// Rol en la app:
//   Singleton que suscribe al stream de eventos de autenticación de Supabase
//   (`authStateChanges`) y expone `isAuthenticated` a las vistas. Es la única
//   fuente de verdad del estado de sesión — las vistas NO deben leer
//   `@AppStorage("isLoggedIn")` para rutear.
//
// Equivalente Android:
//   En Android con Firebase Auth se usaría `FirebaseAuth.getInstance()
//   .addAuthStateListener { ... }` o un `Flow` de un repositorio de auth
//   observado en el ViewModel con `viewModelScope.launch { ... }`.
//   Con Supabase en Android, sería `supabase.auth.sessionStatus.collect { }`.
//
// Por qué @MainActor:
//   Todas las actualizaciones de estado que afectan la UI deben ejecutarse
//   en el hilo principal. `@MainActor` garantiza esto automáticamente, sin
//   necesidad de `DispatchQueue.main.async { }`.
//   Equivalente Android: `withContext(Dispatchers.Main) { }`.
//
// Por qué singleton:
//   Un único observador del stream de auth evita duplicar suscripciones.
//   Se inicializa en `MisGastosApp.task {}` antes de que `SplashView` decida
//   el routing, garantizando que el estado sea correcto.
// =============================================================================

import Foundation
import Observation
import Supabase

// Única fuente de verdad del estado de autenticación.
// Suscribe a authStateChanges del SDK de Supabase: cualquier evento
// (signIn, signOut, tokenRefreshed) actualiza isAuthenticated automáticamente.
// Las vistas observan esta clase en lugar de leer @AppStorage("isLoggedIn").

/// Singleton `@Observable` que mantiene el estado de autenticación de Supabase.
///
/// Equivalente Android: clase `AuthRepository` que expone un `StateFlow<AuthState>`
/// suscrito a los listeners de Firebase Auth o Supabase Auth.
///
/// `@MainActor` garantiza que todas las actualizaciones de propiedades ocurran
/// en el hilo principal (equivalente a `withContext(Dispatchers.Main)` en Kotlin).
@Observable
@MainActor
final class SessionStore {

    // MARK: - Singleton

    /// Instancia compartida — se crea una sola vez al arrancar la app.
    static let shared = SessionStore()

    // MARK: - Estado observable

    /// `true` si hay una sesión activa de Supabase. Las vistas lo usan para
    /// decidir si mostrar `MainTabView` o `LoginView`.
    private(set) var isAuthenticated: Bool = false

    /// UID del usuario activo; vacío si no hay sesión.
    /// Se usa para filtrar compras por usuario en queries SwiftData.
    private(set) var currentUserID: String = ""

    // MARK: - Inicialización

    /// Inicializador privado para forzar el uso del singleton `shared`.
    /// Lanza una `Task` que escucha el stream de eventos de auth de Supabase.
    /// El `for await` es un `async stream` — equivalente a `collect {}` de Kotlin Flow.
    private init() {
        Task {
            // `authStateChanges` es un AsyncStream que emite eventos cada vez que
            // cambia el estado de autenticación (login, logout, refresh de token).
            for await (event, session) in await SupabaseService.shared.client.auth.authStateChanges {
                switch event {
                case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
                    // Sesión activa: actualizar estado y cachear datos del usuario
                    isAuthenticated = session != nil
                    if let user = session?.user {
                        currentUserID = user.id.uuidString
                        let email = user.email ?? ""
                        let nombre: String
                        // Extraer el nombre del metadata guardado en el registro
                        if case .string(let n) = user.userMetadata["nombre"] { nombre = n }
                        else { nombre = email }
                        // Clave sin scope: usada por LoginView para detectar si hay usuario previo
                        // y ofrecer/disparar Face ID / Touch ID automáticamente.
                        UserDefaults.standard.set(email, forKey: "usuarioEmail")
                        // Cachea datos de display con scope de usuario (aislamiento multi-cuenta)
                        UserDefaults.standard.set(email,  forKey: "usuarioEmail_\(user.id.uuidString)")
                        UserDefaults.standard.set(nombre, forKey: "usuarioNombre_\(user.id.uuidString)")
                        // Notificar a UserScopedStorage para refrescar propiedades observables
                        UserScopedStorage.shared.reload()
                    }

                case .signedOut:
                    // Logout: limpiar TODAS las claves de sesión del usuario que cerró
                    let uid = currentUserID
                    UserDefaults.standard.removeObject(forKey: "usuarioEmail_\(uid)")
                    UserDefaults.standard.removeObject(forKey: "usuarioNombre_\(uid)")
                    UserDefaults.standard.removeObject(forKey: "avatarData_\(uid)")
                    UserDefaults.standard.removeObject(forKey: "aparienciaMode_\(uid)")
                    UserDefaults.standard.removeObject(forKey: "presupuestoActivo_\(uid)")
                    UserDefaults.standard.removeObject(forKey: "presupuestoMensual_\(uid)")
                    UserDefaults.standard.removeObject(forKey: "presupuestoAlertaMes_\(uid)")
                    currentUserID = ""
                    isAuthenticated = false
                    // ── CORRECCIÓN: limpiar estado observable del store ──
                    UserScopedStorage.shared.reload()

                default:
                    break
                }
            }
        }
    }
}
