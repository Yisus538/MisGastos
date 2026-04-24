import SwiftUI

@Observable
final class AuthViewModel {
    var email: String = ""
    var password: String = ""
    var nombre: String = ""
    var isLoading: Bool = false
    var errorMessage: String?

    @ObservationIgnored @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @ObservationIgnored @AppStorage("usuarioEmail") private var usuarioEmail: String = ""
    @ObservationIgnored @AppStorage("usuarioNombre") private var usuarioNombre: String = ""

    func login() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = String(localized: "error.campos_vacios")
            return
        }
        isLoading = true
        defer { isLoading = false }
        try? await Task.sleep(for: .seconds(0.8))
        usuarioEmail = email
        usuarioNombre = email.components(separatedBy: "@").first ?? "Usuario"
        isLoggedIn = true
    }

    func register() async {
        guard !nombre.isEmpty, !email.isEmpty, !password.isEmpty else {
            errorMessage = String(localized: "error.campos_vacios")
            return
        }
        isLoading = true
        defer { isLoading = false }
        try? await Task.sleep(for: .seconds(0.8))
        usuarioEmail = email
        usuarioNombre = nombre
        isLoggedIn = true
    }
}
