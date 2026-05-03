import Foundation
import Observation
import Supabase

// Única fuente de verdad del estado de autenticación.
// Suscribe a authStateChanges del SDK de Supabase: cualquier evento
// (signIn, signOut, tokenRefreshed) actualiza isAuthenticated automáticamente.
// Las vistas observan esta clase en lugar de leer @AppStorage("isLoggedIn").
@Observable
@MainActor
final class SessionStore {
    static let shared = SessionStore()

    private(set) var isAuthenticated: Bool = false
    /// UID del usuario activo; vacío si no hay sesión.
    private(set) var currentUserID: String = ""

    private init() {
        Task {
            for await (event, session) in await SupabaseService.shared.client.auth.authStateChanges {
                switch event {
                case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
                    isAuthenticated = session != nil
                    if let user = session?.user {
                        currentUserID = user.id.uuidString
                        let email = user.email ?? ""
                        let nombre: String
                        if case .string(let n) = user.userMetadata["nombre"] { nombre = n }
                        else { nombre = email }
                        // Cachea datos de display con scope de usuario
                        UserDefaults.standard.set(email,  forKey: "usuarioEmail_\(user.id.uuidString)")
                        UserDefaults.standard.set(nombre, forKey: "usuarioNombre_\(user.id.uuidString)")
                        // ── CORRECCIÓN: notificar a todos los observers del store ──
                        UserScopedStorage.shared.reload()
                    }

                case .signedOut:
                    // Limpiar TODAS las claves de sesión al cerrar
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
