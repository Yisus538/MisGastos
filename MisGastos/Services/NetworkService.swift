import Foundation

final class NetworkService {
    static let shared = NetworkService()

    let supermercadosFallback = [
        "Coto", "Carrefour", "Día", "Jumbo", "Disco",
        "Vea", "Chino local", "Walmart"
    ]

    private let cacheKey = "cachedSupermercados"

    func fetchSupermercados() async throws -> [String] {
        // 1. Intentar desde Supabase (fuente de verdad)
        if let nombres = try? await SupabaseService.shared.fetchSupermercados(), !nombres.isEmpty {
            UserDefaults.standard.set(nombres, forKey: cacheKey)
            return nombres
        }
        // 2. Fallback: caché local (funciona offline)
        if let cached = UserDefaults.standard.stringArray(forKey: cacheKey), !cached.isEmpty {
            return cached
        }
        // 3. Fallback: lista hardcodeada
        return supermercadosFallback
    }
}
