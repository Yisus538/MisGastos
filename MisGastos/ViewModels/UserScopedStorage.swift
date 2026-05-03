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

@Observable
@MainActor
final class UserScopedStorage {
    static let shared = UserScopedStorage()
    private init() {}

    private var uid: String { SessionStore.shared.currentUserID }

    // ── Estado observable en memoria ──────────────────────────────────────
    // SwiftUI trackea el acceso a estas propiedades y re-renderiza la vista
    // cuando cambian.
    private(set) var nombre:               String = ""
    private(set) var email:                String = ""
    private(set) var avatarData:           Data   = Data()
    private(set) var presupuestoActivo:    Bool   = false
    private(set) var presupuestoMensual:   Double = 0
    private(set) var presupuestoAlertaMes: String = ""
    // Preferencias globales de dispositivo (sin scope de usuario)
    private(set) var currencyCode:         String = "ARS"
    private(set) var languageCode:         String = "es"
    // Tasa de cambio: cuántas unidades de currencyCode vale 1 ARS
    private(set) var exchangeRate:         Double = 1.0

    // ── Sincronización UserDefaults → estado en memoria ───────────────────
    // Llamar: tras login, tras logout, y dentro de cada set().
    func reload() {
        nombre               = rawString("usuarioNombre")
        email                = rawString("usuarioEmail")
        avatarData           = rawData("avatarData") ?? Data()
        presupuestoActivo    = rawBool("presupuestoActivo",  default: false)
        presupuestoMensual   = rawDouble("presupuestoMensual", default: 0)
        presupuestoAlertaMes = rawString("presupuestoAlertaMes")
        currencyCode         = UserDefaults.standard.string(forKey: "app_currencyCode") ?? "ARS"
        languageCode         = UserDefaults.standard.string(forKey: "app_languageCode") ?? "es"
        if let data = UserDefaults.standard.data(forKey: "cachedCurrencyRates"),
           let rates = try? JSONDecoder().decode([String: Double].self, from: data) {
            exchangeRate = rates[currencyCode] ?? 1.0
        }
    }

    // Convierte un monto guardado en ARS a la moneda seleccionada
    func convert(_ amount: Double) -> Double {
        amount * exchangeRate
    }

    // Símbolo legible de la moneda actual
    var currencySymbol: String {
        switch currencyCode {
        case "USD": return "US$"
        case "EUR": return "€"
        case "BRL": return "R$"
        default:    return "$"
        }
    }

    // Nombre legible de la moneda actual
    var currencyName: String {
        switch currencyCode {
        case "USD": return "Dólares (USD)"
        case "EUR": return "Euros (EUR)"
        case "BRL": return "Reales (BRL)"
        default:    return "Pesos argentinos (ARS)"
        }
    }

    // Fetcha tasas desde la API y actualiza exchangeRate
    func refreshExchangeRates() {
        Task {
            let rates = await CurrencyService.shared.fetchRates()
            exchangeRate = rates[currencyCode] ?? 1.0
        }
    }

    func setCurrencyCode(_ code: String) {
        UserDefaults.standard.set(code, forKey: "app_currencyCode")
        currencyCode = code
        Task {
            let rates = await CurrencyService.shared.fetchRates()
            exchangeRate = rates[code] ?? 1.0
        }
    }

    func setLanguageCode(_ code: String) {
        UserDefaults.standard.set(code, forKey: "app_languageCode")
        UserDefaults.standard.set([code], forKey: "AppleLanguages")
        languageCode = code
    }

    // ── Lecturas genéricas (compatibilidad con callsites existentes) ──────
    func string(_ key: String, default fallback: String = "") -> String {
        rawString(key, fallback: fallback)
    }
    func bool(_ key: String, default fallback: Bool = false) -> Bool {
        rawBool(key, default: fallback)
    }
    func double(_ key: String, default fallback: Double = 0) -> Double {
        rawDouble(key, default: fallback)
    }
    func data(_ key: String) -> Data? {
        rawData(key)
    }

    // ── Escrituras: UserDefaults + observable state ───────────────────────
    func set(_ value: String, for key: String) {
        UserDefaults.standard.set(value, forKey: scopedKey(key))
        reload()
    }
    func set(_ value: Bool, for key: String) {
        UserDefaults.standard.set(value, forKey: scopedKey(key))
        reload()
    }
    func set(_ value: Double, for key: String) {
        UserDefaults.standard.set(value, forKey: scopedKey(key))
        reload()
    }
    func set(_ value: Data, for key: String) {
        UserDefaults.standard.set(value, forKey: scopedKey(key))
        reload()
    }
    func remove(_ key: String) {
        UserDefaults.standard.removeObject(forKey: scopedKey(key))
        reload()
    }

    // ── Clave con scope de usuario ────────────────────────────────────────
    func scopedKey(_ key: String) -> String {
        uid.isEmpty ? key : "\(key)_\(uid)"
    }

    // ── Helpers privados de lectura ───────────────────────────────────────
    private func rawString(_ key: String, fallback: String = "") -> String {
        UserDefaults.standard.string(forKey: scopedKey(key)) ?? fallback
    }
    private func rawBool(_ key: String, default fallback: Bool) -> Bool {
        let k = scopedKey(key)
        guard UserDefaults.standard.object(forKey: k) != nil else { return fallback }
        return UserDefaults.standard.bool(forKey: k)
    }
    private func rawDouble(_ key: String, default fallback: Double) -> Double {
        let k = scopedKey(key)
        guard UserDefaults.standard.object(forKey: k) != nil else { return fallback }
        return UserDefaults.standard.double(forKey: k)
    }
    private func rawData(_ key: String) -> Data? {
        UserDefaults.standard.data(forKey: scopedKey(key))
    }
}
