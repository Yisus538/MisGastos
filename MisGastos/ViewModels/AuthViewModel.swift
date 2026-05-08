// =============================================================================
// AuthViewModel.swift — ViewModel de autenticación (Login y Registro)
// =============================================================================
// Rol en la app:
//   Gestiona el estado de las pantallas de Login y Registro. Delega la
//   autenticación real a SupabaseService y expone propiedades observables
//   que las vistas consumen para actualizar la UI reactivamente.
//
// Equivalente Android:
//   ViewModel + LiveData/StateFlow. En Android se usaría un `AuthViewModel`
//   que extiende `ViewModel`, con `viewModelScope.launch` para corrutinas
//   y `MutableStateFlow`/`MutableLiveData` para los estados observables.
//
// Patrón @Observable (Swift 5.9+):
//   Reemplaza a `ObservableObject` + `@Published`. Con `@Observable`, SwiftUI
//   rastrea automáticamente qué propiedades lee cada vista y solo re-renderiza
//   esa vista cuando esa propiedad específica cambia. Más eficiente que
//   `@Published` que notificaba a todos los observadores ante cualquier cambio.
//
// Regla de imports:
//   Solo `Foundation` + `Observation`. NUNCA importar SwiftUI ni SwiftData
//   en un ViewModel — eso acoplaría la lógica de negocio al framework de UI.
// =============================================================================

import Foundation
import Observation

/// ViewModel que maneja el flujo de autenticación: login y registro de usuarios.
///
/// Usa `@Observable` (equivalente Android: `ViewModel` con `StateFlow`).
/// Las vistas se instancian con `@State private var viewModel = AuthViewModel()`
/// en lugar de `@StateObject`, ya que `@Observable` no requiere `ObservableObject`.
@Observable
final class AuthViewModel {

    // MARK: - Estado observable (equivalente a StateFlow/LiveData en Android)

    /// Email ingresado por el usuario en el formulario.
    var email: String = ""

    /// Contraseña ingresada. Nunca se persiste — solo existe en memoria durante la sesión.
    var password: String = ""

    /// Nombre completo (solo usado en el flujo de registro).
    var nombre: String = ""

    /// Indica si hay una operación de red en progreso.
    /// Las vistas lo usan para mostrar un spinner y deshabilitar el botón.
    var isLoading: Bool = false

    /// Mensaje de error para mostrar al usuario (nil = sin error).
    var errorMessage: String?

    /// Mensaje de éxito, ej: "Revisá tu email para confirmar la cuenta".
    var successMessage: String?

    // MARK: - Dependencias

    /// Singleton de acceso a Supabase — equivalente a un repositorio en Android (Repository pattern).
    private let supabase = SupabaseService.shared

    // MARK: - Acciones

    /// Inicia sesión con email y contraseña via Supabase Auth.
    ///
    /// Flujo:
    /// 1. Valida que los campos no estén vacíos.
    /// 2. Normaliza el email (minúsculas, sin espacios).
    /// 3. Llama `SupabaseService.login()` con async/await.
    /// 4. Si hay éxito, `SessionStore` detecta el evento `.signedIn` de Supabase
    ///    y actualiza `isAuthenticated` → `SplashView` navega a `MainTabView`.
    ///
    /// `async/await` en iOS es equivalente a `coroutines + viewModelScope` en Android.
    /// `defer { isLoading = false }` garantiza que el spinner se oculta siempre,
    /// incluso si se lanza un error (equivalente a `try/finally` en Kotlin).
    func login() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Completá todos los campos"
            return
        }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        // Normalizar email: minúsculas y sin espacios al inicio/final
        let emailNorm = email.lowercased().trimmingCharacters(in: .whitespaces)
        do {
            try await supabase.login(email: emailNorm, password: password)
            // SessionStore.shared observa .signedIn y actualiza isAuthenticated automáticamente.
            // SplashView re-renderiza a MainTabView sin escritura manual en UserDefaults.
        } catch {
            // Mapeo de errores de red/Supabase a mensajes amigables para el usuario
            let msg = error.localizedDescription.lowercased()
            if msg.contains("email not confirmed") || msg.contains("not confirmed") {
                errorMessage = "Confirmá tu email antes de iniciar sesión. Revisá tu bandeja de entrada."
            } else if msg.contains("invalid") || msg.contains("credentials") || msg.contains("wrong") {
                errorMessage = "Email o contraseña incorrectos"
            } else if msg.contains("network") || msg.contains("connection") || msg.contains("offline") || msg.contains("interrupted") || msg.contains("timed out") || msg.contains("could not connect") {
                errorMessage = "Sin conexión al servidor. Verificá tu internet y que el proyecto de Supabase esté activo."
            } else {
                errorMessage = "No se pudo iniciar sesión (\(error.localizedDescription))"
            }
        }
    }

    /// Registra un nuevo usuario en Supabase Auth.
    ///
    /// Flujo:
    /// 1. Valida campos y longitud mínima de contraseña.
    /// 2. Llama `SupabaseService.register()` que hace `signUp` en Supabase.
    /// 3. Si Supabase crea una sesión activa → `SessionStore` navega a main.
    /// 4. Si requiere confirmación de email → muestra mensaje de éxito.
    ///
    /// El nombre del usuario se guarda en `userMetadata` de Supabase Auth
    /// para recuperarlo luego sin consultar una tabla separada.
    func register() async {
        guard !nombre.isEmpty, !email.isEmpty, !password.isEmpty else {
            errorMessage = "Completá todos los campos"
            return
        }
        // Validación de contraseña mínima — Supabase también la valida en el servidor
        guard password.count >= 6 else {
            errorMessage = "La contraseña debe tener al menos 6 caracteres"
            return
        }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        successMessage = nil

        let emailNorm = email.lowercased().trimmingCharacters(in: .whitespaces)
        do {
            try await supabase.register(email: emailNorm, password: password, nombre: nombre)
            // Si Supabase creó sesión activa → SessionStore detecta .signedIn → navega a main
            // Si no hay sesión → confirmación de email requerida → informamos al usuario
            if !supabase.isSessionActive {
                successMessage = "Cuenta creada. Revisá tu email para confirmarla antes de iniciar sesión."
            }
        } catch {
            let msg = error.localizedDescription.lowercased()
            if msg.contains("already registered") || msg.contains("already exists") || msg.contains("user already") {
                errorMessage = "Ya existe una cuenta con ese email"
            } else if msg.contains("password") && msg.contains("weak") {
                errorMessage = "La contraseña es muy débil. Usá al menos 6 caracteres con letras y números."
            } else if msg.contains("network") || msg.contains("connection") || msg.contains("offline") || msg.contains("interrupted") || msg.contains("timed out") || msg.contains("could not connect") {
                errorMessage = "Sin conexión al servidor. Verificá tu internet y que el proyecto de Supabase esté activo."
            } else {
                errorMessage = "No se pudo crear la cuenta (\(error.localizedDescription))"
            }
        }
    }
}
