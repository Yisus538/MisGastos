// =============================================================================
// CurrencyService.swift — Servicio de tasas de cambio de divisas
// =============================================================================
// Rol en la app:
//   Obtiene las tasas de cambio actualizadas desde la API pública de
//   `open.er-api.com` para convertir montos entre ARS y otras divisas
//   (USD, EUR, BRL). Implementa caché en UserDefaults y fallback a tasas
//   hardcodeadas para funcionar sin conexión.
//
// Equivalente Android:
//   Repositorio con Retrofit para llamar a la API REST + Room o DataStore
//   para el caché local. En Kotlin sería una `suspend fun` que retorna
//   `Map<String, Double>` y lanza excepción si hay error de red.
//
// URL Session en iOS vs Android:
//   iOS: `URLSession.shared.data(from: url)` con async/await.
//   Android: `okHttpClient.newCall(request).enqueue(callback)` con OkHttp,
//   o `retrofit.create(ApiService::class.java).getRates()` con Retrofit.
//   Ambos hacen una request HTTP GET y parsean el JSON de respuesta.
//
// Formato de respuesta de la API (open.er-api.com):
//   Base: ARS (1 peso argentino).
//   Respuesta: { "result": "success", "rates": { "USD": 0.00091, "EUR": 0.00083, ... } }
//   Significa: 1 ARS = 0.00091 USD, 1 ARS = 0.00083 EUR, etc.
// =============================================================================

import Foundation

/// Servicio singleton para obtener tasas de cambio de divisas con caché offline.
///
/// Equivalente Android: `ExchangeRateRepository` con Retrofit + DataStore.
final class CurrencyService {

    // MARK: - Singleton

    static let shared = CurrencyService()
    private init() {}

    // MARK: - Tasas de fallback

    /// Tasas de cambio hardcodeadas para usar cuando la API no está disponible.
    /// Base: 1 ARS = X unidades de la moneda destino.
    /// Estas tasas son aproximadas para 2025 y deben actualizarse periódicamente.
    private let fallbackRates: [String: Double] = [
        "ARS": 1.0,
        "USD": 0.00091,   // ~1100 ARS por dólar
        "EUR": 0.00083,   // ~1200 ARS por euro
        "BRL": 0.0046,    // ~217 ARS por real brasileño
    ]

    // MARK: - Fetch con caché y fallback

    /// Obtiene las tasas de cambio actualizadas con estrategia de fallback.
    ///
    /// Prioridad:
    /// 1. **API de open.er-api.com**: tasas en tiempo real, gratis, sin API key.
    /// 2. **Caché en UserDefaults**: tasas de la última request exitosa.
    /// 3. **Tasas hardcodeadas**: siempre disponibles, pueden estar desactualizadas.
    ///
    /// `URLSession.shared.data(from:)` es el equivalente iOS de `OkHttp.execute()`
    /// o `Retrofit.suspend fun`. Con async/await no necesita callbacks.
    ///
    /// - Returns: Diccionario `[codigoISO: tasa]` donde tasa = cuántas unidades
    ///   de la moneda equivalen a 1 ARS.
    func fetchRates() async -> [String: Double] {
        guard let url = URL(string: "https://open.er-api.com/v6/latest/ARS") else {
            return cached() ?? fallbackRates
        }
        do {
            // URLSession con async/await — equivalente Android: `suspend fun` con Retrofit
            let (data, response) = try await URLSession.shared.data(from: url)

            // Verificar que el servidor respondió con HTTP 200 OK
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                return cached() ?? fallbackRates
            }

            // Deserializar el JSON con Codable — equivalente Android: Gson/Moshi
            let decoded = try JSONDecoder().decode(ERResponse.self, from: data)
            guard decoded.result == "success" else { return cached() ?? fallbackRates }

            // Asegurar que ARS está en el diccionario con tasa 1.0 (base currency)
            var rates = decoded.rates
            rates["ARS"] = 1.0
            save(rates)   // Actualizar caché para uso offline
            return rates
        } catch {
            // Error de red o parsing: usar caché o fallback
            return cached() ?? fallbackRates
        }
    }

    // MARK: - Caché en UserDefaults

    /// Guarda las tasas en UserDefaults como JSON codificado.
    ///
    /// `UserDefaults` es el equivalente iOS de `SharedPreferences` en Android.
    /// Para datos más complejos o grandes, se usaría `DataStore` (Android) o
    /// `FileManager` con JSON en el directorio de documentos (iOS).
    private func save(_ rates: [String: Double]) {
        guard let data = try? JSONEncoder().encode(rates) else { return }
        UserDefaults.standard.set(data, forKey: "cachedCurrencyRates")
    }

    /// Lee las tasas cacheadas de UserDefaults.
    ///
    /// - Returns: Diccionario de tasas, o `nil` si no hay caché.
    private func cached() -> [String: Double]? {
        guard let data = UserDefaults.standard.data(forKey: "cachedCurrencyRates"),
              let rates = try? JSONDecoder().decode([String: Double].self, from: data)
        else { return nil }
        return rates
    }
}

// MARK: - DTO de respuesta de la API

/// Struct Decodable para parsear la respuesta JSON de open.er-api.com.
///
/// Solo se mapean los campos que la app necesita; los demás son ignorados.
/// Equivalente Android: data class con `@Json` de Moshi o `@SerializedName` de Gson.
private struct ERResponse: Decodable {
    let result: String              // "success" o "error"
    let rates: [String: Double]     // Diccionario de tasas por código ISO 4217
}
