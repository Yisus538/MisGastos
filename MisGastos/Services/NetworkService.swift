// =============================================================================
// NetworkService.swift — Servicio de red con estrategia de fallback
// =============================================================================
// Rol en la app:
//   Obtiene la lista de supermercados disponibles implementando una estrategia
//   de fallback en cascada: Supabase (fuente de verdad) → caché en UserDefaults
//   (offline) → lista hardcodeada en el código (siempre disponible).
//
// Equivalente Android:
//   Repositorio con `NetworkBoundResource` de Android Architecture Components,
//   o un patrón manual con Retrofit + Room como caché:
//   1. Intenta fetch desde Retrofit (equivalente a Supabase).
//   2. Si falla, lee de Room/DataStore (equivalente al caché en UserDefaults).
//   3. Si tampoco hay datos, usa una lista hardcodeada.
//
// Networking en iOS vs Android:
//   iOS: `URLSession` con async/await (Swift 5.5+).
//   Android: Retrofit con `suspend fun` + Coroutines.
//   En este servicio, el networking real lo hace el SDK de Supabase (`supabase-swift`)
//   que internamente usa `URLSession`.
// =============================================================================

import Foundation

/// Servicio de red para obtener listas de referencia con fallback offline.
///
/// Singleton que provee la lista de supermercados con resiliencia ante fallas
/// de conectividad. Equivalente Android: `Repository` + `NetworkBoundResource`.
final class NetworkService {

    // MARK: - Singleton

    static let shared = NetworkService()

    // MARK: - Datos de fallback

    /// Lista hardcodeada de supermercados — último recurso si Supabase y caché fallan.
    /// En una app de producción, esta lista se actualizaría con una nueva versión de la app.
    let supermercadosFallback = [
        "Coto", "Carrefour", "Día", "Jumbo", "Disco",
        "Vea", "Chino local", "Walmart"
    ]

    // MARK: - Caché local

    /// Clave de UserDefaults para el caché de supermercados.
    /// `UserDefaults` es el equivalente Android de `SharedPreferences`.
    private let cacheKey = "cachedSupermercados"

    // MARK: - Fetch con fallback

    /// Obtiene la lista de supermercados con estrategia de fallback en cascada.
    ///
    /// Prioridad:
    /// 1. **Supabase** (tabla `supermercados`): datos dinámicos y actualizados.
    ///    Si la tabla está vacía o hay error, pasa al siguiente nivel.
    /// 2. **Caché UserDefaults**: datos de la última request exitosa.
    ///    Funciona sin internet (modo offline).
    /// 3. **Lista hardcodeada** (`supermercadosFallback`): siempre disponible,
    ///    sin dependencias externas.
    ///
    /// El resultado exitoso de Supabase se guarda en caché automáticamente.
    ///
    /// `async throws` → equivalente Android: `suspend fun` que puede lanzar excepciones.
    func fetchSupermercados() async throws -> [String] {
        // Nivel 1: Intentar desde Supabase (fuente de verdad remota)
        if let nombres = try? await SupabaseService.shared.fetchSupermercados(), !nombres.isEmpty {
            // Actualizar caché local con los datos frescos de la red
            UserDefaults.standard.set(nombres, forKey: cacheKey)
            return nombres
        }

        // Nivel 2: Fallback a caché local (funciona sin conexión a internet)
        if let cached = UserDefaults.standard.stringArray(forKey: cacheKey), !cached.isEmpty {
            return cached
        }

        // Nivel 3: Fallback final — lista hardcodeada en el código
        return supermercadosFallback
    }
}
