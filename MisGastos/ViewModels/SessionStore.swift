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

    private init() {
        Task {
            for await (event, session) in await SupabaseService.shared.client.auth.authStateChanges {
                switch event {
                case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
                    isAuthenticated = session != nil
                    if let user = session?.user {
                        let email = user.email ?? ""
                        let nombre: String
                        if case .string(let n) = user.userMetadata["nombre"] { nombre = n }
                        else { nombre = email }
                        // Cachea datos de display en UserDefaults (solo lectura por vistas)
                        UserDefaults.standard.set(email,  forKey: "usuarioEmail")
                        UserDefaults.standard.set(nombre, forKey: "usuarioNombre")
                    }
                case .signedOut:
                    isAuthenticated = false
                default:
                    break
                }
            }
        }
    }
}
