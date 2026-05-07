import Foundation
import SwiftData

@MainActor
final class SyncService {
    static let shared = SyncService()
    private init() {}

    // Descarga desde Supabase las compras (y sus productos) que no existen
    // en SwiftData local. Cubre fresh install, nuevo dispositivo y sesión
    // iniciada en otro lugar. Seguro llamar en cada arranque; no duplica datos.
    func pullDesdeSupabase(context: ModelContext) async {
        guard SupabaseService.shared.isSessionActive else { return }

        do {
            let remotas = try await SupabaseService.shared.fetchCompras()
            guard !remotas.isEmpty else { return }

            let locales = (try? context.fetch(FetchDescriptor<Compra>())) ?? []
            let idsLocales = Set(locales.map { $0.id })
            let faltantes = remotas.filter { !idsLocales.contains($0.id) }
            guard !faltantes.isEmpty else { return }

            let productosDTOs = try await SupabaseService.shared.fetchProductos(
                compraIDs: faltantes.map { $0.id }
            )
            let productosPorCompra = Dictionary(grouping: productosDTOs, by: { $0.compraId })

            let currentUID = SessionStore.shared.currentUserID
            for dto in faltantes {
                let compra = Compra(
                    fecha: dto.fecha,
                    supermercado: dto.supermercado,
                    total: dto.total,
                    metodoPago: dto.metodoPago
                )
                compra.id = dto.id
                if !currentUID.isEmpty { compra.userId = currentUID }
                compra.ticketURL = dto.ticketURL
                compra.isSynced = true
                context.insert(compra)

                for prod in productosPorCompra[dto.id] ?? [] {
                    let producto = Producto(
                        codigo: prod.codigo,
                        nombre: prod.nombre,
                        descripcion: prod.descripcion,
                        precio: prod.precio
                    )
                    producto.id = prod.id
                    producto.compra = compra
                    producto.isSynced = true
                    context.insert(producto)
                }
            }

            try? context.save()
        } catch {}
    }

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
            // Upsert para manejar el caso en que la compra ya llegó a Supabase
            // pero isSynced quedó false en disco (crash, fallo de producto, etc.).
            // Un INSERT duplicado fallaba con constraint error y dejaba la compra
            // bloqueada en isSynced=false para siempre.
            do {
                try await SupabaseService.shared.upsertCompra(
                    id: compra.id,
                    fecha: compra.fecha,
                    supermercado: compra.supermercado,
                    total: compra.total,
                    metodoPago: compra.metodoPago,
                    ticketURL: compra.ticketURL
                )
                compra.isSynced = true
                try? context.save()  // Guardar isSynced=true antes de continuar con productos
            } catch {
                continue  // Sin sesión o error de red real: intentar en el próximo arranque
            }

            // Sync de productos de forma independiente
            for producto in compra.productos where !producto.isSynced {
                do {
                    try await SupabaseService.shared.upsertProducto(
                        id: producto.id,
                        compraID: compra.id,
                        nombre: producto.nombre,
                        descripcion: producto.descripcion,
                        codigo: producto.codigo,
                        precio: producto.precio
                    )
                    producto.isSynced = true
                } catch {
                    // Producto pendiente: se reintentará en el próximo arranque
                }
            }
        }

        try? context.save()
    }
}
