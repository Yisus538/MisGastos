// =============================================================================
// Compra.swift — Modelo de datos principal de la app Súper Ahorro
// =============================================================================
// Rol en la app:
//   Representa una compra realizada en un supermercado. Cada `Compra` contiene
//   una lista de `Producto` y puede tener una foto del ticket adjunta.
//
// Equivalente Android:
//   @Entity de Room/SQLite — se persiste automáticamente en la base de datos
//   local del dispositivo, con relaciones uno-a-muchos manejadas por Room.
//
// Patrón arquitectónico:
//   SwiftData (@Model) actúa como capa de persistencia local offline-first.
//   Los datos se sincronizan con Supabase (PostgreSQL) en background mediante
//   el campo `isSynced`. Si no hay conexión, la compra queda guardada en disco
//   y `SyncService` la sincroniza cuando vuelve la conectividad.
// =============================================================================

import SwiftData
import Foundation

/// Representa una compra realizada en un supermercado.
///
/// `@Model` es el equivalente iOS de `@Entity` en Android Room: marca la clase
/// para que SwiftData la persista automáticamente en SQLite local.
/// La anotación genera automáticamente la tabla, índices e historial de migraciones.
@Model
final class Compra {

    // MARK: - Propiedades persistidas

    /// Identificador único universal — equivale a una PRIMARY KEY UUID en Room.
    var id: UUID

    /// UID del usuario propietario de esta compra (UUID de Supabase Auth).
    /// Se usa para filtrar compras por usuario en queries locales (@Query)
    /// y para cumplir con las políticas RLS de Supabase.
    var userId: String          // ← NUEVO: filtra compras por usuario

    /// Fecha de la compra. Permite agrupar por mes en estadísticas y historial.
    var fecha: Date

    /// Nombre del supermercado donde se realizó la compra.
    var supermercado: String

    /// Total de la compra en pesos argentinos (ARS).
    /// Se calcula automáticamente sumando los precios de los productos.
    var total: Double

    /// Método de pago utilizado (Efectivo, Débito, Crédito, etc.).
    var metodoPago: String = "Efectivo"

    /// Imagen del ticket en formato JPEG, guardada como Data binaria.
    /// Solo se usa como fallback cuando `ticketURL` no está disponible
    /// (URL firmada vencida o sin conexión al momento de la compra).
    var imagenTicket: Data?

    /// URL firmada de Supabase Storage donde se almacena la foto del ticket.
    /// La URL tiene 1 hora de validez; si vence, se muestra `imagenTicket` local.
    var ticketURL: String? = nil

    /// Indica si esta compra ya fue sincronizada con Supabase.
    /// `false` = pendiente de sync (sin conexión al crear); `true` = ya en la nube.
    /// `SyncService` monitorea este campo al arrancar la app.
    var isSynced: Bool = false

    /// Relación uno-a-muchos con `Producto`.
    /// `deleteRule: .cascade` garantiza que al eliminar una Compra se eliminan
    /// automáticamente todos sus Productos — equivalente a `CASCADE DELETE` en SQL
    /// o `@Relation(onDelete = CASCADE)` en Room.
    @Relationship(deleteRule: .cascade) var productos: [Producto]

    // MARK: - Inicializador

    /// Crea una nueva compra asignando automáticamente un UUID y el userId del
    /// usuario activo en `SupabaseService`.
    ///
    /// - Parameters:
    ///   - fecha: Fecha de la compra.
    ///   - supermercado: Nombre del supermercado.
    ///   - total: Total a pagar (se recalcula al agregar productos).
    ///   - metodoPago: Medio de pago utilizado.
    init(fecha: Date, supermercado: String, total: Double, metodoPago: String = "Efectivo") {
        self.id = UUID()
        // Obtiene el userId del singleton de Supabase para asociar la compra al usuario.
        // Si la sesión aún no cargó en memoria, el llamador en NuevaCompraView
        // sobreescribe este valor con SessionStore.shared.currentUserID.
        self.userId = SupabaseService.shared.currentUserID?.uuidString ?? "unknown"
        self.fecha = fecha
        self.supermercado = supermercado
        self.total = total
        self.metodoPago = metodoPago
        self.productos = []
    }
}
