import SwiftData
import Foundation

@Model
final class Usuario {
    var id: UUID
    var nombre: String
    var email: String
    var telefono: String
    var avatarData: Data?

    init(nombre: String, email: String, telefono: String = "") {
        self.id = UUID()
        self.nombre = nombre
        self.email = email
        self.telefono = telefono
    }
}
