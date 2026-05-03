import Foundation
import SwiftData

@MainActor
final class SyncService {
    static let shared = SyncService()
    private init() {}

    // Reintenta sincronizar con Supabase todas las compras (y sus productos)
    // que quedaron pendientes por falta de conexión. Seguro llamar en cada
    // arranque de la app; no hace nada si no hay sesión activa.
    func sincronizarPendientes(context: ModelContext) async {
        guard SupabaseService.shared.isSessionActive else { return }

        let descriptor = FetchDescriptor<Compra>(
            predicate: #Predicate { $0.isSynced == false }
        )
        guard let pendientes = try? context.fetch(descriptor), !pendientes.isEmpty else { return }

        for compra in pendientes {
            do {
                try await SupabaseService.shared.crearCompra(
                    id: compra.id,
                    fecha: compra.fecha,
                    supermercado: compra.supermercado,
                    total: compra.total,
                    metodoPago: compra.metodoPago,
                    ticketURL: compra.ticketURL
                )
                compra.isSynced = true

                for producto in compra.productos where !producto.isSynced {
                    try await SupabaseService.shared.crearProducto(
                        id: producto.id,
                        compraID: compra.id,
                        nombre: producto.nombre,
                        descripcion: producto.descripcion,
                        codigo: producto.codigo,
                        precio: producto.precio
                    )
                    producto.isSynced = true
                }
            } catch {
                // Deja isSynced = false; se reintentará en el próximo arranque
            }
        }

        try? context.save()
    }
}
