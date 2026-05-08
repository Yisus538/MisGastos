// =============================================================================
// UserScopedStorage.swift — Capa de almacenamiento con scope por usuario
// =============================================================================
// Rol en la app:
//   Singleton `@Observable` que centraliza el acceso a `UserDefaults` con
//   aislamiento por usuario (todas las claves tienen el sufijo `_<userID>`).
//   Actúa como "caché de propiedades de usuario" en memoria, observable
//   por las vistas SwiftUI.
//
// Equivalente Android:
//   `SharedPreferences` / `DataStore<Preferences>` + un `StateFlow` en un
//   ViewModel. Aquí el patrón equivale a un Repositorio de preferencias con
//   caché en memoria, donde `reload()` sincroniza el disco con el estado
//   observable (similar a `DataStore.data.collect { }` en Android).
//
// Por qué scope de usuario:
//   En apps multi-cuenta, las preferencias de un usuario (avatar, presupuesto,
//   apariencia) no deben "contaminar" la sesión del siguiente usuario que
//   inicie sesión en el mismo dispositivo. Agregar `_<userID>` al sufijo de
//   cada clave garantiza el aislamiento.
//
// Integración con SwiftUI:
//   Como clase `@Observable`, las vistas acceden a `UserScopedStorage.shared`
//   con `@State private var store = UserScopedStorage.shared`. SwiftUI trackea
//   automáticamente qué propiedades se leen y re-renderiza solo lo necesario.
// =============================================================================

import SwiftUI

// ─────────────────────────────────────────────────────────────────
// UserScopedStorage
// ─────────────────────────────────────────────────────────────────
// Clase @Observable: cualquier vista que lea una de sus propiedades
// se re-renderiza automáticamente cuando ese valor cambia.
//
// Las propiedades son la fuente de verdad en memoria; UserDefaults
// actúa como persistencia. Cada `set()` escribe en UserDefaults Y
// actualiza el estado observable via `reload()`.
//
// USO en una View:
//   @State private var store = UserScopedStorage.shared
//   Text(store.nombre)
// ─────────────────────────────────────────────────────────────────

/// Almacenamiento de preferencias de usuario con scope por UID de Supabase.
///
/// Equivalente Android: `DataStore<Preferences>` observado desde un ViewModel,
/// con claves prefijadas por el UID del usuario para aislamiento multi-cuenta.
@Observable
@MainActor
final class UserScopedStorage {

    // MARK: - Singleton

    static let shared = UserScopedStorage()
    private init() {}

    // MARK: - UID del usuario activo

    /// Obtiene el UID del usuario activo desde `SessionStore`.
    /// Todas las claves de UserDefaults se sufijan con este valor.
    private var uid: String { SessionStore.shared.currentUserID }

    // MARK: - Estado observable en memoria

    // SwiftUI trackea el acceso a estas propiedades y re-renderiza la vista
    // cuando cambian. Equivalente a `StateFlow.value` en Kotlin.

    /// Nombre completo del usuario activo.
    private(set) var nombre:               String = ""

    /// Email del usuario activo (de Supabase Auth).
    private(set) var email:                String = ""

    /// Foto de perfil en formato Data (JPEG comprimido 300×300).
    private(set) var avatarData:           Data   = Data()

    /// Si el usuario activó el control de presupuesto mensual.
    private(set) var presupuestoActivo:    Bool   = false

    /// Monto límite del presupuesto mensual en ARS.
    private(set) var presupuestoMensual:   Double = 0

    /// Clave del mes en que se mostró la alerta de presupuesto (ej: "2026-05").
    /// Evita mostrar la alerta más de una vez por mes.
    private(set) var presupuestoAlertaMes: String = ""

    // Preferencias globales de dispositivo (sin scope de usuario)
    /// Código ISO 4217 de la moneda seleccionada (ej: "ARS", "USD", "EUR").
    private(set) var currencyCode:         String = "ARS"

    /// Código ISO 639-1 del idioma seleccionado (ej: "es", "en").
    private(set) var languageCode:         String = "es"

    /// Tasa de cambio: cuántas unidades de `currencyCode` equivalen a 1 ARS.
    /// Se obtiene de la API de CurrencyService y se cachea en UserDefaults.
    private(set) var exchangeRate:         Double = 1.0

    // Plan de membresía (Gratis / Pro)
    /// Plan activo del usuario: `"gratis"` o `"pro"`.
    private(set) var planActivo:           String = "gratis"

    /// Ciclo de facturación del plan Pro: `"mensual"` o `"anual"`.
    private(set) var billingCyclePlan:     String = "mensual"

    /// Precio del plan Pro en ARS (0 si es plan Gratis).
    private(set) var precioPlan:           Double = 0

    /// Fecha de próxima renovación del plan Pro (nil si plan Gratis).
    private(set) var fechaRenovacion:      Date?  = nil

    // MARK: - Sincronización UserDefaults → estado en memoria

    /// Carga todas las preferencias desde UserDefaults al estado observable.
    ///
    /// Llamar en: tras login, tras logout, y dentro de cada `set()`.
    /// Equivalente Android: `preferences.data.first()` + actualizar el ViewModel.
    func reload() {
        nombre               = rawString("usuarioNombre")
        email                = rawString("usuarioEmail")
        avatarData           = rawData("avatarData") ?? Data()
        presupuestoActivo    = rawBool("presupuestoActivo",  default: false)
        presupuestoMensual   = rawDouble("presupuestoMensual", default: 0)
        presupuestoAlertaMes = rawString("presupuestoAlertaMes")
        // Preferencias sin scope (globales del dispositivo)
        currencyCode         = UserDefaults.standard.string(forKey: "app_currencyCode") ?? "ARS"
        languageCode         = UserDefaults.standard.string(forKey: "app_languageCode") ?? "es"
        // Restaurar tasa de cambio desde caché
        if let data = UserDefaults.standard.data(forKey: "cachedCurrencyRates"),
           let rates = try? JSONDecoder().decode([String: Double].self, from: data) {
            exchangeRate = rates[currencyCode] ?? 1.0
        }
        // Datos de membresía (sin scope: son globales de la cuenta Supabase)
        planActivo       = UserDefaults.standard.string(forKey: "app_planActivo")    ?? "gratis"
        billingCyclePlan = UserDefaults.standard.string(forKey: "app_billingCycle")  ?? "mensual"
        precioPlan       = UserDefaults.standard.double(forKey: "app_precioPlan")
        let ts           = UserDefaults.standard.double(forKey: "app_fechaRenovacion")
        fechaRenovacion  = ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    // MARK: - Actualización del plan de membresía

    /// Actualiza el plan activo en UserDefaults y en el estado observable.
    ///
    /// Llamado por `MembresiaService` tras confirmar el cambio en Supabase.
    func actualizarPlan(plan: String, billingCycle: String, precio: Double, fechaRenovacion: Date?) {
        UserDefaults.standard.set(plan,         forKey: "app_planActivo")
        UserDefaults.standard.set(billingCycle, forKey: "app_billingCycle")
        UserDefaults.standard.set(precio,       forKey: "app_precioPlan")
        if let f = fechaRenovacion {
            UserDefaults.standard.set(f.timeIntervalSince1970, forKey: "app_fechaRenovacion")
        } else {
            UserDefaults.standard.removeObject(forKey: "app_fechaRenovacion")
        }
        reload()
    }

    // MARK: - Conversión de moneda

    /// Convierte un monto guardado en ARS a la moneda seleccionada por el usuario.
    ///
    /// - Parameter amount: Monto en ARS.
    /// - Returns: Monto en la moneda configurada (`currencyCode`).
    func convert(_ amount: Double) -> Double {
        amount * exchangeRate
    }

    /// Símbolo legible de la moneda actual para mostrar en la UI.
    var currencySymbol: String {
        switch currencyCode {
        case "USD": return "US$"
        case "EUR": return "€"
        case "BRL": return "R$"
        default:    return "$"
        }
    }

    /// Nombre completo de la moneda actual para mostrar en configuración.
    var currencyName: String {
        switch currencyCode {
        case "USD": return "Dólares (USD)"
        case "EUR": return "Euros (EUR)"
        case "BRL": return "Reales (BRL)"
        default:    return "Pesos argentinos (ARS)"
        }
    }

    // MARK: - Tasas de cambio

    /// Descarga tasas actualizadas desde `CurrencyService` y actualiza `exchangeRate`.
    ///
    /// Se llama en `SplashView.onAppear` para tener tasas frescas al iniciar.
    func refreshExchangeRates() {
        Task {
            let rates = await CurrencyService.shared.fetchRates()
            exchangeRate = rates[currencyCode] ?? 1.0
        }
    }

    /// Cambia la moneda seleccionada y descarga la tasa de cambio correspondiente.
    ///
    /// - Parameter code: Código ISO 4217 de la nueva moneda (ej: "USD").
    func setCurrencyCode(_ code: String) {
        UserDefaults.standard.set(code, forKey: "app_currencyCode")
        currencyCode = code
        Task {
            let rates = await CurrencyService.shared.fetchRates()
            exchangeRate = rates[code] ?? 1.0
        }
    }

    /// Cambia el idioma de la app y persiste en `UserDefaults`.
    /// La app requiere reinicio para aplicar el cambio (limitación de iOS).
    ///
    /// - Parameter code: Código ISO 639-1 del idioma (ej: "es", "en").
    func setLanguageCode(_ code: String) {
        UserDefaults.standard.set(code, forKey: "app_languageCode")
        // `AppleLanguages` es la clave del sistema que iOS lee para determinar el idioma
        UserDefaults.standard.set([code], forKey: "AppleLanguages")
        languageCode = code
    }

    // MARK: - Lecturas genéricas (compatibilidad con callsites existentes)

    /// Lee un `String` de UserDefaults con scope de usuario.
    func string(_ key: String, default fallback: String = "") -> String {
        rawString(key, fallback: fallback)
    }

    /// Lee un `Bool` de UserDefaults con scope de usuario.
    func bool(_ key: String, default fallback: Bool = false) -> Bool {
        rawBool(key, default: fallback)
    }

    /// Lee un `Double` de UserDefaults con scope de usuario.
    func double(_ key: String, default fallback: Double = 0) -> Double {
        rawDouble(key, default: fallback)
    }

    /// Lee un `Data` de UserDefaults con scope de usuario.
    func data(_ key: String) -> Data? {
        rawData(key)
    }

    // MARK: - Escrituras con scope de usuario

    /// Guarda un `String` en UserDefaults con scope de usuario y refresca el estado observable.
    func set(_ value: String, for key: String) {
        UserDefaults.standard.set(value, forKey: scopedKey(key))
        reload()
    }

    /// Guarda un `Bool` en UserDefaults con scope de usuario y refresca el estado observable.
    func set(_ value: Bool, for key: String) {
        UserDefaults.standard.set(value, forKey: scopedKey(key))
        reload()
    }

    /// Guarda un `Double` en UserDefaults con scope de usuario y refresca el estado observable.
    func set(_ value: Double, for key: String) {
        UserDefaults.standard.set(value, forKey: scopedKey(key))
        reload()
    }

    /// Guarda un `Data` en UserDefaults con scope de usuario y refresca el estado observable.
    func set(_ value: Data, for key: String) {
        UserDefaults.standard.set(value, forKey: scopedKey(key))
        reload()
    }

    /// Elimina una clave de UserDefaults con scope de usuario.
    func remove(_ key: String) {
        UserDefaults.standard.removeObject(forKey: scopedKey(key))
        reload()
    }

    // MARK: - Clave con scope de usuario

    /// Construye la clave con scope de usuario: `"\(key)_\(uid)"`.
    /// Si no hay usuario activo, usa la clave sin scope.
    func scopedKey(_ key: String) -> String {
        uid.isEmpty ? key : "\(key)_\(uid)"
    }

    // MARK: - Helpers privados de lectura

    /// Lee un `String` de UserDefaults usando la clave con scope de usuario.
    private func rawString(_ key: String, fallback: String = "") -> String {
        UserDefaults.standard.string(forKey: scopedKey(key)) ?? fallback
    }

    /// Lee un `Bool` de UserDefaults; retorna `fallback` si la clave no existe.
    private func rawBool(_ key: String, default fallback: Bool) -> Bool {
        let k = scopedKey(key)
        guard UserDefaults.standard.object(forKey: k) != nil else { return fallback }
        return UserDefaults.standard.bool(forKey: k)
    }

    /// Lee un `Double` de UserDefaults; retorna `fallback` si la clave no existe.
    private func rawDouble(_ key: String, default fallback: Double) -> Double {
        let k = scopedKey(key)
        guard UserDefaults.standard.object(forKey: k) != nil else { return fallback }
        return UserDefaults.standard.double(forKey: k)
    }

    /// Lee un `Data` de UserDefaults (retorna nil si no existe).
    private func rawData(_ key: String) -> Data? {
        UserDefaults.standard.data(forKey: scopedKey(key))
    }
}
