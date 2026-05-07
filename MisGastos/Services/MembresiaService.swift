import Foundation
import Supabase

// MARK: - DTOs

struct MembresiaDTO: Codable {
    let plan: String
    let billingCycle: String
    let precio: Double
    let fechaInicio: Date?
    let fechaRenovacion: Date?
    let activa: Bool

    enum CodingKeys: String, CodingKey {
        case plan
        case billingCycle    = "billing_cycle"
        case precio
        case fechaInicio     = "fecha_inicio"
        case fechaRenovacion = "fecha_renovacion"
        case activa
    }
}

private struct MembresiaUpsert: Encodable {
    let userId: UUID
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

@MainActor
final class MembresiaService {
    static let shared = MembresiaService()
    private init() {}

    private var client: SupabaseClient { SupabaseService.shared.client }

    // MARK: Fetch
    func fetchMembresia() async throws -> MembresiaDTO? {
        do {
            let dto: MembresiaDTO = try await client
                .from("membresias")
                .select()
                .single()
                .execute()
                .value
            return dto
        } catch {
            // Sin registro aún (usuario nuevo)
            return nil
        }
    }

    // Carga y sincroniza con UserScopedStorage
    func sincronizar() async {
        guard let dto = try? await fetchMembresia() else { return }
        UserScopedStorage.shared.actualizarPlan(
            plan: dto.plan,
            billingCycle: dto.billingCycle,
            precio: dto.precio,
            fechaRenovacion: dto.fechaRenovacion
        )
    }

    // MARK: Suscribir Pro
    func suscribirPro(billingCycle: String) async throws {
        guard let userID = SupabaseService.shared.currentUserID else { throw SAError.noSession }
        let precio: Double = billingCycle == "mensual" ? 2990 : 2990 * 12 * 0.8
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
        try await client
            .from("membresias")
            .upsert(body, onConflict: "user_id")
            .execute()

        UserScopedStorage.shared.actualizarPlan(
            plan: "pro",
            billingCycle: billingCycle,
            precio: precio,
            fechaRenovacion: fechaRenovacion
        )
    }

    // MARK: Cancelar / bajar a Gratis
    func cancelarPlan() async throws {
        guard let userID = SupabaseService.shared.currentUserID else { throw SAError.noSession }
        let body = MembresiaUpsert(
            userId: userID,
            plan: "gratis",
            billingCycle: "mensual",
            precio: 0,
            fechaRenovacion: nil,
            activa: true
        )
        try await client
            .from("membresias")
            .upsert(body, onConflict: "user_id")
            .execute()

        UserScopedStorage.shared.actualizarPlan(
            plan: "gratis",
            billingCycle: "mensual",
            precio: 0,
            fechaRenovacion: nil
        )
    }
}
