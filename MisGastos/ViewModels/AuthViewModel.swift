import Foundation
import Observation

@Observable
final class AuthViewModel {
    var email: String = ""
    var password: String = ""
    var nombre: String = ""
    var isLoading: Bool = false
    var errorMessage: String?

    private let defaults = UserDefaults.standard
    private let supabase = SupabaseService.shared

    func login() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Completá todos los campos"
            return
        }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        let emailNorm = email.lowercased().trimmingCharacters(in: .whitespaces)
        do {
            try await supabase.login(email: emailNorm, password: password)
            defaults.set(emailNorm, forKey: "usuarioEmail")
            defaults.set(true, forKey: "isLoggedIn")
            let nombreGuardado = supabase.nombreFromMetadata() ?? emailNorm
            defaults.set(nombreGuardado, forKey: "usuarioNombre")
        } catch {
            let msg = error.localizedDescription.lowercased()
            if msg.contains("email not confirmed") || msg.contains("not confirmed") {
                errorMessage = "Confirmá tu email antes de iniciar sesión. Revisá tu bandeja de entrada."
            } else if msg.contains("invalid") || msg.contains("credentials") || msg.contains("wrong") {
                errorMessage = "Email o contraseña incorrectos"
            } else if msg.contains("network") || msg.contains("connection") || msg.contains("offline") {
                errorMessage = "Sin conexión a internet. Verificá tu red."
            } else {
                errorMessage = "No se pudo iniciar sesión. Intentá de nuevo."
            }
        }
    }

    func register() async {
        guard !nombre.isEmpty, !email.isEmpty, !password.isEmpty else {
            errorMessage = "Completá todos los campos"
            return
        }
        guard password.count >= 6 else {
            errorMessage = "La contraseña debe tener al menos 6 caracteres"
            return
        }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        let emailNorm = email.lowercased().trimmingCharacters(in: .whitespaces)
        do {
            try await supabase.register(email: emailNorm, password: password, nombre: nombre)
            defaults.set(emailNorm, forKey: "usuarioEmail")
            defaults.set(nombre, forKey: "usuarioNombre")

            // Si Supabase creó sesión activa → confirmación de email desactivada → acceso directo
            // Si no hay sesión → confirmación requerida → el usuario debe confirmar su email
            if supabase.isSessionActive {
                defaults.set(true, forKey: "isLoggedIn")
            } else {
                errorMessage = "Cuenta creada. Revisá tu email para confirmarla antes de iniciar sesión."
            }
        } catch {
            let msg = error.localizedDescription.lowercased()
            if msg.contains("already registered") || msg.contains("already exists") || msg.contains("user already") {
                errorMessage = "Ya existe una cuenta con ese email"
            } else if msg.contains("password") && msg.contains("weak") {
                errorMessage = "La contraseña es muy débil. Usá al menos 6 caracteres con letras y números."
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
}
