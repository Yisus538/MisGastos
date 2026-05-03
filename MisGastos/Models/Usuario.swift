import SwiftData
import Foundation

// Modelo deprecado — auth se delega a Supabase. Se mantiene en el container solo
// para compatibilidad con el schema existente. No crear nuevas instancias.
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
