// =====================================================
// SETUP REQUERIDO (hacer antes de compilar):
// 1. Xcode → File → Add Package Dependencies
//    URL: https://github.com/supabase/supabase-swift
//    Versión: Up to Next Major desde 2.0.0
// 2. Crear proyecto en supabase.com (plan gratuito)
// 3. Ejecutar Resources/supabase_schema.sql en el SQL Editor
// 4. Storage → New bucket: "tickets-usuarios" (privado)
// 5. Reemplazar SUPABASE_URL y SUPABASE_ANON_KEY abajo
// =====================================================

import Foundation
import Supabase

// MARK: - Codable DTOs (snake_case ↔ PostgreSQL)

private struct CompraRemota: Codable {
    let id: UUID
    let userId: UUID
    let fecha: Date
    let supermercado: String
    let total: Double
    let metodoPago: String
    let ticketUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, fecha, supermercado, total
        case userId     = "user_id"
        case metodoPago = "metodo_pago"
        case ticketUrl  = "ticket_url"
    }
}

private struct ProductoRemoto: Codable {
    let id: UUID
    let compraId: UUID
    let nombre: String
    let descripcion: String
    let codigo: String
    let precio: Double

    enum CodingKeys: String, CodingKey {
        case id, nombre, descripcion, codigo, precio
        case compraId = "compra_id"
    }
}

private struct SupermercadoRemoto: Codable {
    let nombre: String
}

// MARK: - SupabaseService

final class SupabaseService {
    static let shared = SupabaseService()

    // ⚠️ Reemplazá estos valores con los de tu proyecto en supabase.com
    // Project Settings → API → Project URL y anon key
    private static let supabaseURL = URL(string: "https://umbxwxsikjvqkybraipi.supabase.co")!
    private static let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVtYnh3eHNpa2p2cWt5YnJhaXBpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3NTI3MDcsImV4cCI6MjA5MzMyODcwN30.IXUZhe39Pu_QrpBXlr5neDEV0UduyaoQ0ZU0TCXMNmk"

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: Self.supabaseURL,
            supabaseKey: Self.supabaseKey
        )
    }

    var currentUserID: UUID? { client.auth.currentUser?.id }

    var isSessionActive: Bool { client.auth.currentSession != nil }

    // Carga/restaura la sesión desde Keychain. Llamar al iniciar la app
    // para garantizar que currentUserID no sea nil antes de operaciones DB.
    func restaurarSesion() async {
        _ = try? await client.auth.session
    }

    // MARK: - Auth

    func login(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    func register(email: String, password: String, nombre: String) async throws {
        try await client.auth.signUp(
            email: email,
            password: password,
            data: ["nombre": .string(nombre)]
        )
    }

    func logout() async throws {
        try await client.auth.signOut()
    }

    func resetPassword(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
    }

    func nombreFromMetadata() -> String? {
        guard let user = client.auth.currentUser,
              case .string(let n) = user.userMetadata["nombre"] else { return nil }
        return n
    }

    // MARK: - Compras

    func fetchCompras() async throws -> [CompraDTO] {
        let remotas: [CompraRemota] = try await client
            .from("compras")
            .select()
            .order("fecha", ascending: false)
            .execute()
            .value

        return remotas.map {
            CompraDTO(
                id: $0.id,
                fecha: $0.fecha,
                supermercado: $0.supermercado,
                total: $0.total,
                metodoPago: $0.metodoPago,
                ticketURL: $0.ticketUrl
            )
        }
    }

    func crearCompra(id: UUID, fecha: Date, supermercado: String, total: Double, metodoPago: String, ticketURL: String?) async throws {
        guard let userID = currentUserID else { throw SAError.noSession }

        let remota = CompraRemota(
            id: id,
            userId: userID,
            fecha: fecha,
            supermercado: supermercado,
            total: total,
            metodoPago: metodoPago,
            ticketUrl: ticketURL
        )
        try await client.from("compras").insert(remota).execute()
    }

    func actualizarCompra(id: UUID, supermercado: String, fecha: Date, total: Double, metodoPago: String, ticketURL: String?) async throws {
        guard let userID = currentUserID else { throw SAError.noSession }

        let remota = CompraRemota(
            id: id,
            userId: userID,
            fecha: fecha,
            supermercado: supermercado,
            total: total,
            metodoPago: metodoPago,
            ticketUrl: ticketURL
        )
        try await client
            .from("compras")
            .update(remota)
            .eq("id", value: id.uuidString)
            .execute()
    }

    func borrarCompra(id: UUID) async throws {
        try await client
            .from("compras")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Productos

    func crearProducto(id: UUID, compraID: UUID, nombre: String, descripcion: String, codigo: String, precio: Double) async throws {
        let remoto = ProductoRemoto(
            id: id,
            compraId: compraID,
            nombre: nombre,
            descripcion: descripcion,
            codigo: codigo,
            precio: precio
        )
        try await client.from("productos").insert(remoto).execute()
    }

    func actualizarProducto(id: UUID, compraID: UUID, nombre: String, descripcion: String, codigo: String, precio: Double) async throws {
        let remoto = ProductoRemoto(
            id: id,
            compraId: compraID,
            nombre: nombre,
            descripcion: descripcion,
            codigo: codigo,
            precio: precio
        )
        try await client
            .from("productos")
            .update(remoto)
            .eq("id", value: id.uuidString)
            .execute()
    }

    func borrarProducto(id: UUID) async throws {
        try await client
            .from("productos")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Storage de tickets

    func subirTicket(_ data: Data, compraID: UUID) async throws -> String {
        guard let userID = currentUserID else { throw SAError.noSession }

        let path = "\(userID.uuidString)/\(compraID.uuidString).jpg"

        try await client.storage
            .from("tickets-usuarios")
            .upload(
                path: path,
                file: data,
                options: FileOptions(contentType: "image/jpeg")
            )

        let signedURL = try await client.storage
            .from("tickets-usuarios")
            .createSignedURL(path: path, expiresIn: 3600)

        return signedURL.absoluteString
    }

    // MARK: - Preferencias de perfil

    func guardarApariencia(_ mode: String) async throws {
        guard let userID = currentUserID else { throw SAError.noSession }
        try await client
            .from("perfiles")
            .update(["apariencia": mode])
            .eq("id", value: userID.uuidString)
            .execute()
    }

    func fetchApariencia() async throws -> String? {
        guard let userID = currentUserID else { return nil }
        struct Row: Decodable { let apariencia: String? }
        let rows: [Row] = try await client
            .from("perfiles")
            .select("apariencia")
            .eq("id", value: userID.uuidString)
            .execute()
            .value
        return rows.first?.apariencia
    }

    // MARK: - Supermercados

    func fetchSupermercados() async throws -> [String] {
        let remotos: [SupermercadoRemoto] = try await client
            .from("supermercados")
            .select("nombre")
            .order("nombre")
            .execute()
            .value
        return remotos.map { $0.nombre }
    }
}

// MARK: - DTO público

struct CompraDTO {
    let id: UUID
    let fecha: Date
    let supermercado: String
    let total: Double
    let metodoPago: String
    let ticketURL: String?
}

// MARK: - Errores

enum SAError: LocalizedError {
    case noSession

    var errorDescription: String? {
        "No hay sesión activa. Iniciá sesión nuevamente."
    }
}
