// =============================================================================
// MembresiaService.swift — Servicio de gestión de membresía Gratis/Pro
// =============================================================================
// Rol en la app:
//   Gestiona el plan de membresía del usuario (Gratis o Pro) sincronizado con
//   la tabla `membresias` de Supabase. Usa `upsert` (INSERT OR UPDATE) para
//   evitar errores de clave duplicada en la tabla con `UNIQUE(user_id)`.
//
// Equivalente Android:
//   Repositorio que llama a una API REST (Retrofit) o a Firestore para gestionar
//   el estado de suscripción. El upsert equivale a `setMerge()` en Firestore
//   o a una petición PUT a un endpoint de backend.
//
// DTOs (Data Transfer Objects):
//   `MembresiaDTO` y `MembresiaUpsert` son structs Codable que mapean
//   automáticamente entre los campos Swift (camelCase) y las columnas PostgreSQL
//   (snake_case) mediante `CodingKeys`. Equivalente Android: data class con
//   `@SerializedName` de Gson o `@Json` de Moshi.
//
// Por qué @MainActor:
//   Las operaciones actualizan `UserScopedStorage.shared` que es `@MainActor`.
//   Marcar el servicio con `@MainActor` evita tener que hacer `await MainActor.run {}`
//   en cada método.
// =============================================================================

import Foundation
import Supabase

// MARK: - DTOs

/// DTO de lectura para la tabla `membresias` de Supabase.
/// `Codable` permite serialización/deserialización JSON automática.
/// Los `CodingKeys` mapean snake_case (PostgreSQL) a camelCase (Swift).
/// Equivalente Android: data class con `@Json` de Moshi o `@SerializedName` de Gson.
struct MembresiaDTO: Codable {
    let plan: String            // "gratis" | "pro"
    let billingCycle: String    // "mensual" | "anual"
    let precio: Double          // en ARS
    let fechaInicio: Date?      // fecha de inicio del plan Pro
    let fechaRenovacion: Date?  // próxima renovación (nil si plan Gratis)
    let activa: Bool            // si el plan está vigente

    /// Mapeo explícito entre los nombres de propiedades Swift y las columnas PostgreSQL.
    enum CodingKeys: String, CodingKey {
        case plan
        case billingCycle    = "billing_cycle"
        case precio
        case fechaInicio     = "fecha_inicio"
        case fechaRenovacion = "fecha_renovacion"
        case activa
    }
}

/// DTO de escritura para hacer upsert en la tabla `membresias`.
/// Es privado porque solo `MembresiaService` lo usa internamente.
/// No expone `fechaInicio` — la calcula la base de datos con `DEFAULT NOW()`.
private struct MembresiaUpsert: Encodable {
    let userId: UUID        // clave primaria de la tabla (RLS la usa para filtrar)
    let plan: String
    let billingCycle: String
    let precio: Double
    let fechaRenovacion: Date?
    let activa: Bool

    enum CodingKeys: String, CodingKey {
        case userId          = "user_id"
        case plan
        case billingCycle    = "billing_cycle"
        case precio
        case fechaRenovacion = "fecha_renovacion"
        case activa
    }
}

// MARK: - Service

/// Servicio singleton que gestiona los planes de membresía contra Supabase.
///
/// Flujo típico:
/// 1. `MembresiaView.onAppear` llama `sincronizar()` para refrescar estado.
/// 2. `suscribirPro()` hace upsert a Supabase y actualiza `UserScopedStorage`.
/// 3. `cancelarPlan()` hace upsert con plan "gratis" y limpia el storage.
@MainActor
final class MembresiaService {

    // MARK: - Singleton

    static let shared = MembresiaService()
    private init() {}

    // MARK: - Acceso al cliente Supabase

    /// Referencia al cliente Supabase compartido, que gestiona la sesión JWT.
    private var client: SupabaseClient { SupabaseService.shared.client }

    // MARK: - Fetch

    /// Obtiene el estado de membresía del usuario activo desde Supabase.
    ///
    /// `.single()` espera exactamente 1 fila — si no existe, lanza error y
    /// se captura para retornar `nil` (usuario nuevo sin registro de membresía).
    ///
    /// - Returns: `MembresiaDTO` con el estado del plan, o `nil` si es usuario nuevo.
    func fetchMembresia() async throws -> MembresiaDTO? {
        do {
            let dto: MembresiaDTO = try await client
                .from("membresias")
                .select()
                .single()   // Equivalente a LIMIT 1 + error si no hay resultado
                .execute()
                .value
            return dto
        } catch {
            // Sin registro aún (usuario nuevo) — retornar nil en lugar de propagar el error
            return nil
        }
    }

    /// Descarga el plan activo desde Supabase y sincroniza `UserScopedStorage`.
    ///
    /// Llamado en `SplashView.onAppear` y en `MembresiaView.onAppear`
    /// para mantener el estado local consistente con la fuente de verdad remota.
    func sincronizar() async {
        guard let dto = try? await fetchMembresia() else { return }
        UserScopedStorage.shared.actualizarPlan(
            plan: dto.plan,
            billingCycle: dto.billingCycle,
            precio: dto.precio,
            fechaRenovacion: dto.fechaRenovacion
        )
    }

    // MARK: - Suscribir Pro

    /// Activa el plan Pro para el usuario activo.
    ///
    /// Calcula el precio y la fecha de renovación según el ciclo elegido:
    /// - Mensual: $2990 ARS, próximo mes.
    /// - Anual: $28.704 ARS (20% descuento), próximo año.
    ///
    /// Usa `upsert` con `onConflict: "user_id"` para actualizar si ya existe
    /// un registro, o insertar uno nuevo si no lo hay.
    /// Equivalente SQL: `INSERT ... ON CONFLICT (user_id) DO UPDATE SET ...`
    ///
    /// - Parameter billingCycle: `"mensual"` o `"anual"`.
    func suscribirPro(billingCycle: String) async throws {
        guard let userID = SupabaseService.shared.currentUserID else { throw SAError.noSession }

        // Calcular precio: anual tiene 20% de descuento sobre 12 meses
        let precio: Double = billingCycle == "mensual" ? 2990 : 2990 * 12 * 0.8

        // Calcular fecha de próxima renovación usando Calendar para manejar edge cases
        // (ej: 31 de enero + 1 mes = 28 de febrero, no se rompe)
        let cal = Calendar.current
        let fechaRenovacion: Date = billingCycle == "mensual"
            ? (cal.date(byAdding: .month, value: 1, to: .now) ?? .now)
            : (cal.date(byAdding: .year,  value: 1, to: .now) ?? .now)

        let body = MembresiaUpsert(
            userId: userID,
            plan: "pro",
            billingCycle: billingCycle,
            precio: precio,
            fechaRenovacion: fechaRenovacion,
            activa: true
        )

        // Upsert: inserta si no existe, actualiza si ya hay un registro para este user_id
        try await client
            .from("membresias")
            .upsert(body, onConflict: "user_id")
            .execute()

        // Actualizar estado local para que la UI refleje el cambio de inmediato
        UserScopedStorage.shared.actualizarPlan(
            plan: "pro",
            billingCycle: billingCycle,
            precio: precio,
            fechaRenovacion: fechaRenovacion
        )
    }

    // MARK: - Cancelar / bajar a Gratis

    /// Baja el plan del usuario a Gratis, eliminando la fecha de renovación.
    ///
    /// Hace upsert con plan "gratis" y precio 0 — no elimina el registro de la
    /// tabla `membresias` para mantener el historial de suscripciones.
    func cancelarPlan() async throws {
        guard let userID = SupabaseService.shared.currentUserID else { throw SAError.noSession }
        let body = MembresiaUpsert(
            userId: userID,
            plan: "gratis",
            billingCycle: "mensual",
            precio: 0,
            fechaRenovacion: nil,   // Sin fecha de renovación en plan Gratis
            activa: true
        )
        try await client
            .from("membresias")
            .upsert(body, onConflict: "user_id")
            .execute()

        // Actualizar estado local de forma inmediata
        UserScopedStorage.shared.actualizarPlan(
            plan: "gratis",
            billingCycle: "mensual",
            precio: 0,
            fechaRenovacion: nil
        )
    }
}
