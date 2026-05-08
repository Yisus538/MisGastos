// =============================================================================
// BiometricService.swift — Servicio de autenticación biométrica
// =============================================================================
// Rol en la app:
//   Abstrae el uso del framework `LocalAuthentication` para verificar si el
//   dispositivo tiene Face ID o Touch ID disponible y autenticar al usuario
//   biométricamente. Se usa en el flujo de login y en el lock de app (al
//   volver de background con sesión activa).
//
// Equivalente Android:
//   `BiometricPrompt` + `BiometricManager` de AndroidX Biometric.
//   El flujo es análogo: verificar disponibilidad con `canAuthenticate()`,
//   luego llamar `biometricPrompt.authenticate(promptInfo)` con un callback.
//   iOS usa `LAContext.evaluatePolicy()` con async/await nativo (Swift 5.5+).
//
// Framework utilizado:
//   `LocalAuthentication` — framework nativo de iOS para Face ID / Touch ID.
//   Requiere la clave `NSFaceIDUsageDescription` en Info.plist.
//
// Diferencia clave iOS vs Android:
//   En iOS, la biometría autentica LOCALMENTE en el Secure Enclave del chip.
//   No reemplaza a Supabase Auth — valida que el usuario del dispositivo es
//   quien dice ser, luego la sesión JWT de Supabase (guardada en Keychain) se
//   restaura. En Android, `BiometricPrompt` puede integrarse con `CryptoObject`
//   para desencriptar claves del Keystore.
// =============================================================================

import Foundation
import LocalAuthentication

/// Servicio singleton para autenticación biométrica con Face ID o Touch ID.
///
/// Equivalente Android: `BiometricManager` + `BiometricPrompt`.
/// Abstrae las diferencias entre modelos de iPhone (Face ID en los modernos,
/// Touch ID en modelos más antiguos y iPad).
final class BiometricService {

    // MARK: - Singleton

    static let shared = BiometricService()
    private init() {}

    // MARK: - Tipo de biometría disponible

    /// Enum que diferencia los tipos de autenticación biométrica disponibles.
    /// Equivalente Android: `BiometricManager.BIOMETRIC_STRONG` (incluye ambos).
    enum BiometricType { case none, faceID, touchID }

    /// Detecta qué tipo de biometría está disponible en el dispositivo actual.
    ///
    /// `LAContext` es la clase principal del framework `LocalAuthentication`.
    /// `canEvaluatePolicy()` verifica si el hardware está disponible Y el usuario
    /// tiene Face ID/Touch ID configurado. Si no, retorna `.none`.
    var biometricType: BiometricType {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else { return .none }
        switch ctx.biometryType {
        case .faceID:  return .faceID
        case .touchID: return .touchID
        default:       return .none
        }
    }

    /// `true` si hay algún tipo de biometría disponible y configurada.
    /// Las vistas usan esto para mostrar/ocultar el botón de Face ID / Touch ID.
    var isAvailable: Bool { biometricType != .none }

    // MARK: - Autenticación

    /// Solicita autenticación biométrica al usuario.
    ///
    /// Presenta el diálogo del sistema (Face ID scan o huella digital).
    /// Retorna `true` si el usuario se autenticó correctamente, `false` si
    /// cancela o falla (demasiados intentos, biometría no configurada, etc.).
    ///
    /// `async/await` permite esperar el resultado sin bloquear el hilo principal.
    /// Equivalente Android: callback `onAuthenticationSucceeded` / `onAuthenticationFailed`.
    ///
    /// - Parameter reason: Mensaje que se muestra al usuario en el diálogo del sistema.
    /// - Returns: `true` si la autenticación fue exitosa.
    func authenticate(reason: String) async -> Bool {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else { return false }
        do {
            // `evaluatePolicy` lanza el diálogo nativo de Face ID / Touch ID.
            // En el simulador siempre retorna false (no hay biometría real).
            return try await ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        } catch {
            // El usuario canceló o hubo demasiados intentos fallidos
            return false
        }
    }
}
