import SwiftData
import Foundation

@Model
final class Compra {
    var id: UUID
    var fecha: Date
    var supermercado: String
    var total: Double
    var metodoPago: String = "Efectivo"
    var imagenTicket: Data?
    @Relationship(deleteRule: .cascade) var productos: [Producto]

    init(fecha: Date, supermercado: String, total: Double, metodoPago: String = "Efectivo") {
        self.id = UUID()
        self.fecha = fecha
        self.supermercado = supermercado
        self.total = total
        self.metodoPago = metodoPago
        self.productos = []
    }
}
