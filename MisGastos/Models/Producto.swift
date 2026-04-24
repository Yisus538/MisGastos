import SwiftData
import Foundation

@Model
final class Producto {
    var id: UUID
    var codigo: String
    var nombre: String
    var descripcion: String
    var precio: Double
    var compra: Compra?

    init(codigo: String, nombre: String, descripcion: String, precio: Double) {
        self.id = UUID()
        self.codigo = codigo
        self.nombre = nombre
        self.descripcion = descripcion
        self.precio = precio
    }
}
