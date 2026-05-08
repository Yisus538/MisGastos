// =============================================================================
// SyncService.swift — Servicio de sincronización offline-first con Supabase
// =============================================================================
// Rol en la app:
//   Implementa la estrategia offline-first: los datos se guardan primero en
//   SwiftData local (disponibles inmediatamente) y luego se sincronizan con
//   Supabase en background. Este servicio maneja dos casos:
//   1. `sincronizarPendientes`: sube compras con `isSynced=false` a Supabase.
//   2. `pullDesdeSupabase`: descarga compras de la nube que no están en local
//      (nuevo dispositivo, reinstalación de la app).
//
// Equivalente Android:
//   `WorkManager` con `SyncWorker` en Android es el patrón estándar para
//   sincronización en background. Aquí se usa `Task` de Swift Concurrency ya
//   que la sync ocurre al arrancar la app (foreground). Para background real,
//   iOS usa `BGTaskScheduler` + `BGProcessingTask`.
//
// Patrón offline-first:
//   Datos locales (SwiftData/SQLite) son la fuente de verdad para la UI.
//   La nube (Supabase/PostgreSQL) es el respaldo persistente y punto de
//   sincronización entre dispositivos. Este patrón garantiza que la app
//   funcione sin conexión (modo avión) y sincronice cuando vuelve la red.
//
// Por qué upsert en lugar de insert:
//   Un INSERT fallaba con error de clave duplicada cuando la compra ya llegó
//   a Supabase en un intento anterior pero `isSynced` quedó en `false` por
//   un crash o error al marcarla como synced. El UPSERT (INSERT OR UPDATE)
//   resuelve esto de forma idempotente: si ya existe, actualiza; si no, inserta.
// =============================================================================

import Foundation
import SwiftData

/// Servicio singleton que gestiona la sincronización bidireccional entre
/// SwiftData (local) y Supabase (nube).
///
/// `@MainActor` es necesario porque interactúa con `ModelContext` de SwiftData,
/// que debe usarse en el hilo principal en iOS 17+.
@MainActor
final class SyncService {

    // MARK: - Singleton

    static let shared = SyncService()
    private init() {}

    // MARK: - Pull (nube → local)

    /// Descarga desde Supabase las compras que no existen en SwiftData local.
    ///
    /// Cubre los siguientes escenarios:
    /// - Fresh install: el usuario instaló la app en un dispositivo nuevo.
    /// - Nueva sesión: el usuario inició sesión desde otro dispositivo.
    /// - Restauración de backup: reinstalación desde iCloud/App Store.
    ///
    /// Es idempotente: si los datos ya están en local, no los duplica
    /// (filtra por IDs que no están en `idsLocales`).
    ///
    /// Migración de userId:
    ///   Compras creadas antes de que existiera el campo `userId` quedan con ""
    ///   tras la auto-migration de SwiftData. Se asigna el UID actual para que
    ///   `HomeView` pueda filtrarlas correctamente.
    ///
    /// - Parameter context: ModelContext de SwiftData para insertar compras locales.
    func pullDesdeSupabase(context: ModelContext) async {
        guard SupabaseService.shared.isSessionActive,
              let currentUUID = SupabaseService.shared.currentUserID else { return }
        let uidStr = currentUUID.uuidString

        do {
            // Fetch local antes de la red para poder comparar IDs y migrar userId vacíos
            let locales = (try? context.fetch(FetchDescriptor<Compra>())) ?? []

            // Migración: compras creadas antes de que existiera el campo userId
            // quedan con "" tras la auto-migration de SwiftData. Se asigna el UID actual.
            let sinUserId = locales.filter { $0.userId.isEmpty || $0.userId == "unknown" }
            if !sinUserId.isEmpty {
                sinUserId.forEach { $0.userId = uidStr }
                try? context.save()
            }

            // Obtener compras de la nube y comparar con las locales
            let remotas = try await SupabaseService.shared.fetchCompras()
            guard !remotas.isEmpty else { return }

            // Filtrar solo las compras remotas que NO están en local (evita duplicados)
            let idsLocales = Set(locales.map { $0.id })
            let faltantes = remotas.filter { !idsLocales.contains($0.id) }
            guard !faltantes.isEmpty else { return }

            // Obtener todos los productos de las compras faltantes en una sola query
            // (más eficiente que hacer una query por compra)
            let productosDTOs = try await SupabaseService.shared.fetchProductos(
                compraIDs: faltantes.map { $0.id }
            )
            // Agrupar productos por compraId para acceso O(1) en el loop siguiente
            let productosPorCompra = Dictionary(grouping: productosDTOs, by: { $0.compraId })

            // Insertar cada compra faltante con sus productos en SwiftData local
            for dto in faltantes {
                let compra = Compra(
                    fecha: dto.fecha,
                    supermercado: dto.supermercado,
                    total: dto.total,
                    metodoPago: dto.metodoPago
                )
                compra.id = dto.id       // Preservar el UUID original de Supabase
                compra.userId = uidStr
                compra.ticketURL = dto.ticketURL
                compra.isSynced = true   // Ya está en la nube, no necesita sync
                context.insert(compra)

                // Insertar los productos asociados a esta compra
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

    // MARK: - Push (local → nube)

    /// Reintenta sincronizar con Supabase todas las compras y productos pendientes.
    ///
    /// Busca en SwiftData las compras con `isSynced == false` (creadas sin
    /// conexión) y las sube a Supabase usando `upsert` para idempotencia.
    ///
    /// Estrategia de sync por compra:
    /// 1. Hacer upsert de la compra en Supabase.
    /// 2. Si tiene éxito → marcar `isSynced = true` y guardar en disco.
    /// 3. Si falla → continuar con la siguiente compra (se reintentará).
    /// 4. Hacer upsert de cada producto de la compra (independientemente).
    ///
    /// La sync de productos es independiente de la de compras: un fallo en
    /// un producto no bloquea el proceso para las demás compras.
    ///
    /// Es seguro llamar en cada arranque: si no hay sesión o no hay pendientes,
    /// retorna de inmediato sin hacer operaciones de red.
    ///
    /// - Parameter context: ModelContext de SwiftData para leer y actualizar compras.
    func sincronizarPendientes(context: ModelContext) async {
        guard SupabaseService.shared.isSessionActive else { return }

        // Query de compras pendientes usando #Predicate (equivalente Android: WHERE isSynced = 0)
        let descriptor = FetchDescriptor<Compra>(
            predicate: #Predicate { $0.isSynced == false }
        )
        guard let pendientes = try? context.fetch(descriptor), !pendientes.isEmpty else { return }

        for compra in pendientes {
            // Upsert en lugar de INSERT para manejar el caso en que la compra ya llegó
            // a Supabase pero isSynced quedó false en disco (crash, fallo de producto, etc.).
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
                // Guardar isSynced=true antes de continuar con productos,
                // para no re-intentar la compra si hay error en los productos
                try? context.save()
            } catch {
                // Sin sesión o error de red real: intentar en el próximo arranque
                continue
            }

            // Sync de productos de forma independiente (un fallo no afecta otras compras)
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
                    // Producto pendiente: se reintentará en el próximo arranque de la app
                }
            }
        }

        try? context.save()
    }
}
