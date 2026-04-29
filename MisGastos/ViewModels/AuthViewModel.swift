import Foundation
import Observation
import SwiftData

/// Gestiona el estado del formulario de autenticación y ejecuta login/registro contra SwiftData.
@Observable
final class AuthViewModel {
    var email: String = ""
    var password: String = ""
    var nombre: String = ""
    var isLoading: Bool = false
    var errorMessage: String?

    private let defaults = UserDefaults.standard

    func login(context: ModelContext) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Completá todos los campos"
            return
        }
        isLoading = true
        defer { isLoading = false }
        try? await Task.sleep(for: .seconds(0.6))

        let emailNorm = email.lowercased().trimmingCharacters(in: .whitespaces)
        let descriptor = FetchDescriptor<Usuario>(
            predicate: #Predicate<Usuario> { $0.email == emailNorm }
        )
        let resultados = (try? context.fetch(descriptor)) ?? []

        guard let usuario = resultados.first else {
            errorMessage = "No encontramos una cuenta con ese email"
            return
        }
        guard usuario.password == password else {
            errorMessage = "Contraseña incorrecta"
            return
        }

        defaults.set(usuario.email,  forKey: "usuarioEmail")
        defaults.set(usuario.nombre, forKey: "usuarioNombre")
        defaults.set(true,           forKey: "isLoggedIn")
    }

    func register(context: ModelContext) async {
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
        try? await Task.sleep(for: .seconds(0.6))

        let emailNorm = email.lowercased().trimmingCharacters(in: .whitespaces)
        let descriptor = FetchDescriptor<Usuario>(
            predicate: #Predicate<Usuario> { $0.email == emailNorm }
        )
        let existentes = (try? context.fetch(descriptor)) ?? []
        guard existentes.isEmpty else {
            errorMessage = "Ya existe una cuenta con ese email"
            return
        }

        let usuario = Usuario(nombre: nombre, email: emailNorm, password: password)
        context.insert(usuario)

        defaults.set(emailNorm, forKey: "usuarioEmail")
        defaults.set(nombre,    forKey: "usuarioNombre")
        defaults.set(true,      forKey: "isLoggedIn")
    }
}
