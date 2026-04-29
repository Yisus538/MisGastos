import SwiftData
import Foundation

@Model
final class Usuario {
    var id: UUID
    var nombre: String
    var email: String
    var password: String
    var telefono: String
    var avatarData: Data?

    init(nombre: String, email: String, password: String = "", telefono: String = "") {
        self.id = UUID()
        self.nombre = nombre
        self.email = email
        self.password = password
        self.telefono = telefono
    }
}
