// =============================================================================
// SupabaseService.swift — Servicio central de acceso a Supabase (BaaS)
// =============================================================================
// Rol en la app:
//   Singleton que encapsula toda la comunicación con Supabase: autenticación,
//   operaciones CRUD en tablas PostgreSQL, subida de archivos a Storage y
//   gestión de preferencias de perfil. Es el equivalente a un conjunto de
//   repositorios en una arquitectura Android con Clean Architecture.
//
// Equivalente Android:
//   En Android con backend propio: Retrofit + OkHttp para networking.
//   Con Firebase: FirebaseAuth, Firestore, FirebaseStorage.
//   Con Supabase en Android: `supabase-kt` SDK con coroutines.
//   URLSession (iOS) ↔ OkHttp/Retrofit (Android).
//
// Supabase como BaaS (Backend as a Service):
//   Supabase provee: Auth (usuarios con JWT), PostgreSQL (base de datos),
//   Storage (archivos), y Realtime (websockets). El cliente iOS usa el SDK
//   `supabase-swift` que internamente usa URLSession con async/await.
//
// Seguridad con RLS (Row Level Security):
//   Cada tabla tiene políticas RLS en PostgreSQL que garantizan que un usuario
//   solo pueda leer/escribir sus propios datos. El JWT de la sesión activa
//   se envía automáticamente en cada request y Supabase lo valida en el servidor.
//
// DTOs vs Modelos:
//   Los structs `CompraRemota`, `ProductoRemoto` y `SupermercadoRemoto` son DTOs
//   privados que mapean las columnas de PostgreSQL (snake_case) a Swift (camelCase).
//   Los DTOs públicos `CompraDTO` y `ProductoDTO` exponen los datos al resto de la app.
// =============================================================================

import Foundation
import Supabase

// MARK: - Codable DTOs (snake_case ↔ PostgreSQL)

/// DTO privado para leer/escribir compras desde la tabla `compras` de Supabase.
/// El mapeo snake_case ↔ camelCase se hace con `CodingKeys`.
/// Equivalente Android: data class con `@SerializedName` de Gson.
private struct CompraRemota: Codable {
    let id: UUID
    let userId: UUID       // UUID del usuario propietario (FK a auth.users)
    let fecha: Date
    let supermercado: String
    let total: Double
    let metodoPago: String
    let ticketUrl: String? // URL firmada de Supabase Storage (nullable)

    enum CodingKeys: String, CodingKey {
        case id, fecha, supermercado, total
        case userId     = "user_id"
        case metodoPago = "metodo_pago"
        case ticketUrl  = "ticket_url"
    }
}

/// DTO privado para leer/escribir productos desde la tabla `productos`.
private struct ProductoRemoto: Codable {
    let id: UUID
    let compraId: UUID     // FK a la tabla compras
    let nombre: String
    let descripcion: String
    let codigo: String
    let precio: Double

    enum CodingKeys: String, CodingKey {
        case id, nombre, descripcion, codigo, precio
        case compraId = "compra_id"
    }
}

/// DTO privado para leer supermercados desde la tabla `supermercados`.
private struct SupermercadoRemoto: Codable {
    let nombre: String
}

// MARK: - SupabaseService

/// Singleton de acceso a Supabase. Gestiona auth, compras, productos, storage y perfiles.
///
/// Equivalente Android: conjunto de `Repository` clases + `RetrofitInstance` / Firebase config.
/// En iOS, el SDK `supabase-swift` abstrae URLSession con async/await.
final class SupabaseService {

    // MARK: - Singleton

    static let shared = SupabaseService()

    // MARK: - Configuración (credenciales del proyecto Supabase)

    /// URL del proyecto Supabase — equivalente al `serverUrl` de Retrofit en Android.
    private static let supabaseURL = URL(string: "https://umbxwxsikjvqkybraipi.supabase.co")!

    /// Clave anónima (anon key) — clave pública para queries RLS desde el cliente.
    /// NO es una clave secreta: es segura para incluir en el código del cliente,
    /// ya que las políticas RLS en el servidor controlan el acceso real a los datos.
    private static let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVtYnh3eHNpa2p2cWt5YnJhaXBpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3NTI3MDcsImV4cCI6MjA5MzMyODcwN30.IXUZhe39Pu_QrpBXlr5neDEV0UduyaoQ0ZU0TCXMNmk"

    // MARK: - Cliente Supabase

    /// Instancia del cliente Supabase. Gestiona automáticamente:
    /// - La sesión JWT (guardada en Keychain, no en UserDefaults).
    /// - El refresco automático del token cuando expira.
    /// - La cola de requests pendientes mientras el token se refresca.
    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: Self.supabaseURL,
            supabaseKey: Self.supabaseKey
        )
    }

    // MARK: - Propiedades de sesión

    /// UUID del usuario activo (del JWT de Supabase). `nil` si no hay sesión.
    var currentUserID: UUID? { client.auth.currentUser?.id }

    /// `true` si hay una sesión JWT válida en memoria/Keychain.
    var isSessionActive: Bool { client.auth.currentSession != nil }

    // MARK: - Restauración de sesión

    /// Intenta restaurar la sesión guardada en Keychain al arrancar la app.
    ///
    /// El SDK guarda el JWT en Keychain automáticamente. Al restaurar, se verifica
    /// si el token sigue siendo válido; si expiró pero hay refresh token, se refresca.
    /// Llamar antes de cualquier operación de base de datos.
    func restaurarSesion() async {
        _ = try? await client.auth.session
    }

    // MARK: - Auth

    /// Inicia sesión con email y contraseña.
    ///
    /// Si tiene éxito, el SDK guarda el JWT en Keychain y emite `.signedIn`
    /// en `authStateChanges`, que `SessionStore` detecta para actualizar la UI.
    /// Equivalente Android: `FirebaseAuth.signInWithEmailAndPassword()`.
    func login(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    /// Registra un nuevo usuario en Supabase Auth.
    ///
    /// El nombre se guarda en `userMetadata` del usuario de Supabase Auth,
    /// disponible en `user.userMetadata["nombre"]` sin consultar tablas adicionales.
    ///
    /// Equivalente Android: `FirebaseAuth.createUserWithEmailAndPassword()`.
    func register(email: String, password: String, nombre: String) async throws {
        try await client.auth.signUp(
            email: email,
            password: password,
            data: ["nombre": .string(nombre)]  // Metadata embebida en el JWT
        )
    }

    /// Cierra sesión en el servidor y limpia el JWT del Keychain.
    ///
    /// `SessionStore` detecta el evento `.signedOut` y navega a `LoginView`.
    func logout() async throws {
        try await client.auth.signOut()
    }

    /// Envía un email de recuperación de contraseña al usuario.
    ///
    /// Por seguridad, siempre mostramos "email enviado" aunque el email no exista,
    /// para no revelar si una dirección está registrada (user enumeration attack).
    func resetPassword(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
    }

    /// Extrae el nombre del usuario desde el metadata del JWT.
    ///
    /// No requiere llamada a red — el metadata está en el JWT ya cargado en memoria.
    func nombreFromMetadata() -> String? {
        guard let user = client.auth.currentUser,
              case .string(let n) = user.userMetadata["nombre"] else { return nil }
        return n
    }

    // MARK: - Compras

    /// Obtiene todas las compras del usuario activo desde Supabase.
    ///
    /// RLS garantiza que solo se devuelven las compras del usuario del JWT.
    /// Las compras se ordenan por fecha descendente (más reciente primero).
    ///
    /// - Returns: Array de `CompraDTO` ordenado por fecha descendente.
    func fetchCompras() async throws -> [CompraDTO] {
        let remotas: [CompraRemota] = try await client
            .from("compras")
            .select()
            .order("fecha", ascending: false)
            .execute()
            .value

        // Convertir DTOs remotos (con snake_case) a DTOs públicos (con camelCase)
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

    /// Inserta una nueva compra en Supabase.
    ///
    /// Usa INSERT (no upsert) — para reintento en caso de conflicto, usar `upsertCompra`.
    /// Se llama desde `NuevaCompraView.guardar()` en un Task background.
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

    /// Hace upsert (INSERT OR UPDATE) de una compra en Supabase.
    ///
    /// Usado por `SyncService` para evitar el error de clave duplicada cuando
    /// `isSynced` quedó `false` en disco pero la compra ya llegó a Supabase
    /// en un intento anterior (crash, fallo de red al marcar synced, etc.).
    /// Equivalente SQL: `INSERT ... ON CONFLICT (id) DO UPDATE SET ...`
    func upsertCompra(id: UUID, fecha: Date, supermercado: String, total: Double, metodoPago: String, ticketURL: String?) async throws {
        guard let userID = currentUserID else { throw SAError.noSession }
        let remota = CompraRemota(
            id: id, userId: userID, fecha: fecha,
            supermercado: supermercado, total: total,
            metodoPago: metodoPago, ticketUrl: ticketURL
        )
        try await client.from("compras").upsert(remota, onConflict: "id").execute()
    }

    /// Actualiza los campos de una compra existente en Supabase.
    ///
    /// El filtro `.eq("id", value:)` garantiza que solo se actualiza la compra
    /// del usuario activo (la política RLS en Supabase también lo verifica).
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
            .eq("id", value: id.uuidString)  // WHERE id = ?
            .execute()
    }

    /// Elimina una compra de Supabase por su UUID.
    ///
    /// El cascade delete en la base de datos elimina también los productos asociados.
    /// Equivalente SQL: `DELETE FROM compras WHERE id = ?`
    func borrarCompra(id: UUID) async throws {
        try await client
            .from("compras")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Productos

    /// Obtiene los productos de múltiples compras en una sola query.
    ///
    /// Usa `.in("compra_id", values:)` para hacer un `WHERE compra_id IN (...)`,
    /// más eficiente que hacer una query por cada compra.
    ///
    /// - Parameter compraIDs: Array de UUIDs de compras cuyos productos se quieren.
    /// - Returns: Array de `ProductoDTO` de todas las compras consultadas.
    func fetchProductos(compraIDs: [UUID]) async throws -> [ProductoDTO] {
        guard !compraIDs.isEmpty else { return [] }
        let remotos: [ProductoRemoto] = try await client
            .from("productos")
            .select()
            .in("compra_id", values: compraIDs.map { $0.uuidString })  // WHERE compra_id IN (...)
            .execute()
            .value
        return remotos.map {
            ProductoDTO(
                id: $0.id,
                compraId: $0.compraId,
                nombre: $0.nombre,
                descripcion: $0.descripcion,
                codigo: $0.codigo,
                precio: $0.precio
            )
        }
    }

    /// Inserta un nuevo producto en Supabase asociado a una compra.
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

    /// Hace upsert de un producto — usado por `SyncService` para idempotencia.
    func upsertProducto(id: UUID, compraID: UUID, nombre: String, descripcion: String, codigo: String, precio: Double) async throws {
        let remoto = ProductoRemoto(
            id: id, compraId: compraID,
            nombre: nombre, descripcion: descripcion,
            codigo: codigo, precio: precio
        )
        try await client.from("productos").upsert(remoto, onConflict: "id").execute()
    }

    /// Actualiza los campos de un producto existente en Supabase.
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

    /// Elimina un producto de Supabase por su UUID.
    func borrarProducto(id: UUID) async throws {
        try await client
            .from("productos")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Storage de tickets

    /// Sube la imagen del ticket a Supabase Storage y retorna la URL firmada.
    ///
    /// Ruta en el bucket: `tickets-usuarios/{userID}/{compraID}.jpg`
    /// Esto permite usar RLS en Storage: cada usuario solo accede a su carpeta.
    ///
    /// URL firmada: válida por 1 hora (3600 segundos). Si vence, `DetalleCompraView`
    /// cae al fallback de `imagenTicket` (Data local).
    ///
    /// Equivalente Android: Firebase Storage `storageRef.child(path).putBytes(data)`.
    ///
    /// - Parameters:
    ///   - data: Imagen en formato JPEG.
    ///   - compraID: UUID de la compra, usado para el nombre del archivo.
    /// - Returns: URL firmada (String) del archivo en Supabase Storage.
    func subirTicket(_ data: Data, compraID: UUID) async throws -> String {
        guard let userID = currentUserID else { throw SAError.noSession }

        // Estructura de carpeta que aísla archivos por usuario
        let path = "\(userID.uuidString)/\(compraID.uuidString).jpg"

        try await client.storage
            .from("tickets-usuarios")
            .upload(
                path: path,
                file: data,
                options: FileOptions(contentType: "image/jpeg")
            )

        // URL firmada con 1 hora de validez — más segura que URLs públicas permanentes
        let signedURL = try await client.storage
            .from("tickets-usuarios")
            .createSignedURL(path: path, expiresIn: 3600)

        return signedURL.absoluteString
    }

    // MARK: - Storage de avatares

    /// Sube la foto de perfil del usuario a Supabase Storage.
    ///
    /// Usa `upsert: true` porque el archivo se sobreescribe cada vez que el
    /// usuario cambia su foto (siempre el mismo path por usuario).
    /// La URL firmada dura 1 año para evitar refrescos frecuentes.
    func subirAvatar(_ data: Data) async throws -> String {
        guard let userID = currentUserID else { throw SAError.noSession }
        let path = "\(userID.uuidString)/avatar.jpg"
        try await client.storage
            .from("avatares-usuarios")
            .upload(path: path, file: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
        let signedURL = try await client.storage
            .from("avatares-usuarios")
            .createSignedURL(path: path, expiresIn: 60 * 60 * 24 * 365) // 1 año
        return signedURL.absoluteString
    }

    /// Descarga la foto de perfil del usuario desde Supabase Storage.
    ///
    /// Retorna `Data` binario para guardar en `UserScopedStorage.avatarData` como caché local.
    func fetchAvatarData() async -> Data? {
        guard let userID = currentUserID else { return nil }
        let path = "\(userID.uuidString)/avatar.jpg"
        return try? await client.storage
            .from("avatares-usuarios")
            .download(path: path)
    }

    // MARK: - Preferencias de perfil

    /// Guarda el modo de apariencia (claro/oscuro/sistema) en la tabla `perfiles`.
    ///
    /// Permite sincronizar la preferencia entre dispositivos del mismo usuario.
    func guardarApariencia(_ mode: String) async throws {
        guard let userID = currentUserID else { throw SAError.noSession }
        try await client
            .from("perfiles")
            .update(["apariencia": mode])
            .eq("id", value: userID.uuidString)
            .execute()
    }

    /// Obtiene el modo de apariencia guardado en Supabase para el usuario activo.
    ///
    /// Se llama en `SplashView.onAppear` para sincronizar la preferencia remota.
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

    /// Obtiene el perfil del usuario (nombre, teléfono, URL del avatar).
    ///
    /// Se usa en `EditarPerfilView` para mostrar los datos actuales
    /// y en `PerfilView` para verificar si hay avatar en la nube.
    func fetchPerfil() async throws -> (nombre: String, telefono: String, avatarURL: String?) {
        guard let userID = currentUserID else { throw SAError.noSession }
        struct Row: Decodable {
            let nombre: String
            let telefono: String?
            let avatar_url: String?
        }
        let rows: [Row] = try await client
            .from("perfiles")
            .select("nombre, telefono, avatar_url")
            .eq("id", value: userID.uuidString)
            .execute()
            .value
        let row = rows.first
        return (nombre: row?.nombre ?? "", telefono: row?.telefono ?? "", avatarURL: row?.avatar_url)
    }

    /// Actualiza el nombre (y opcionalmente la URL del avatar) en la tabla `perfiles`.
    ///
    /// Usa dos variantes de Payload según si hay avatar nuevo para evitar
    /// sobreescribir el `avatar_url` existente cuando no hay cambio de foto.
    func guardarPerfil(nombre: String, avatarURL: String? = nil) async throws {
        guard let userID = currentUserID else { throw SAError.noSession }
        if let url = avatarURL {
            struct Payload: Encodable { let nombre: String; let avatar_url: String }
            try await client.from("perfiles")
                .update(Payload(nombre: nombre, avatar_url: url))
                .eq("id", value: userID.uuidString).execute()
        } else {
            // Sin avatar: actualizar solo el nombre para no limpiar la URL existente
            struct Payload: Encodable { let nombre: String }
            try await client.from("perfiles")
                .update(Payload(nombre: nombre))
                .eq("id", value: userID.uuidString).execute()
        }
    }

    // MARK: - Supermercados

    /// Obtiene la lista de supermercados desde la tabla `supermercados` de Supabase.
    ///
    /// Esta tabla permite actualizar la lista de tiendas disponibles en el servidor
    /// sin necesitar una nueva versión de la app (sin hardcodear en el código).
    func fetchSupermercados() async throws -> [String] {
        let remotos: [SupermercadoRemoto] = try await client
            .from("supermercados")
            .select("nombre")
            .order("nombre")      // Orden alfabético para la UI
            .execute()
            .value
        return remotos.map { $0.nombre }
    }
}

// MARK: - DTOs públicos

/// DTO público para transferir datos de compras entre capas de la app.
/// Inmutable (solo let) — no se puede modificar una vez creado.
struct CompraDTO {
    let id: UUID
    let fecha: Date
    let supermercado: String
    let total: Double
    let metodoPago: String
    let ticketURL: String?
}

/// DTO público para transferir datos de productos entre capas de la app.
struct ProductoDTO {
    let id: UUID
    let compraId: UUID
    let nombre: String
    let descripcion: String
    let codigo: String
    let precio: Double
}

// MARK: - Errores

/// Errores personalizados de la capa de servicios de la app.
/// `LocalizedError` permite proveer un mensaje descriptivo en español.
enum SAError: LocalizedError {
    /// No hay sesión activa de Supabase al intentar una operación que la requiere.
    case noSession

    var errorDescription: String? {
        "No hay sesión activa. Iniciá sesión nuevamente."
    }
}
