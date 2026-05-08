// =============================================================================
// Usuario.swift — Modelo de usuario (DEPRECADO, solo compatibilidad)
// =============================================================================
// Rol en la app:
//   Originalmente almacenaba los datos del usuario (nombre, email, contraseña)
//   directamente en SwiftData. Fue reemplazado por Supabase Auth, que gestiona
//   autenticación con bcrypt + JWT de forma segura en el servidor.
//
// Estado actual:
//   DEPRECADO. No se crean nuevas instancias de este modelo. Se mantiene en el
//   `modelContainer` únicamente para que SwiftData no falle la migración del
//   schema existente en dispositivos con datos previos.
//
// Equivalente Android:
//   Sería una @Entity de Room, pero el equivalente moderno es usar Firebase Auth
//   o Supabase Auth en lugar de persistir credenciales localmente.
//
// Lección aprendida:
//   Guardar contraseñas en texto plano en SQLite local (como hacía esta clase
//   originalmente) es una práctica insegura. Supabase Auth maneja hashing con
//   bcrypt y tokens JWT firmados — nunca toca la contraseña en texto plano.
// =============================================================================

import SwiftData
import Foundation

// Modelo deprecado — auth se delega a Supabase. Se mantiene en el container solo
// para compatibilidad con el schema existente. No crear nuevas instancias.

/// Modelo legacy de usuario para SwiftData.
///
/// **No usar en código nuevo.** La autenticación se delega completamente a
/// `SupabaseService`, que gestiona sesiones JWT con tokens en Keychain (seguro).
/// `UserScopedStorage` expone los datos del usuario activo a las vistas.
@Model
final class Usuario {

    // MARK: - Propiedades (legacy)

    /// Identificador único — no se usa en producción, solo para compatibilidad de schema.
    var id: UUID

    /// Nombre completo del usuario.
    var nombre: String

    /// Correo electrónico (normalizado a minúsculas en código nuevo).
    var email: String

    /// Número de teléfono opcional.
    var telefono: String

    /// Foto de perfil en formato Data — en código nuevo se usa Supabase Storage
    /// y `UserScopedStorage.shared.avatarData` como caché local.
    var avatarData: Data?

    // MARK: - Inicializador

    /// Inicializador solo para compatibilidad de schema de SwiftData.
    /// No llamar desde código nuevo.
    init(nombre: String, email: String, telefono: String = "") {
        self.id = UUID()
        self.nombre = nombre
        self.email = email
        self.telefono = telefono
    }
}
