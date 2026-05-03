import SwiftData
import Foundation

@Model
final class Compra {
    var id: UUID
    var userId: String          // ← NUEVO: filtra compras por usuario
    var fecha: Date
    var supermercado: String
    var total: Double
    var metodoPago: String = "Efectivo"
    var imagenTicket: Data?
    var ticketURL: String? = nil
    var isSynced: Bool = false
    @Relationship(deleteRule: .cascade) var productos: [Producto]

    init(fecha: Date, supermercado: String, total: Double, metodoPago: String = "Efectivo") {
        self.id = UUID()
        self.userId = SupabaseService.shared.currentUserID?.uuidString ?? "unknown"
        self.fecha = fecha
        self.supermercado = supermercado
        self.total = total
        self.metodoPago = metodoPago
        self.productos = []
    }
}
