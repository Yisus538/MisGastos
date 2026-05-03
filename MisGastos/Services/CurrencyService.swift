import Foundation

final class CurrencyService {
    static let shared = CurrencyService()
    private init() {}

    // Tasas de fallback (1 ARS = X moneda), aproximadas 2025
    private let fallbackRates: [String: Double] = [
        "ARS": 1.0,
        "USD": 0.00091,   // ~1100 ARS/USD
        "EUR": 0.00083,   // ~1200 ARS/EUR
        "BRL": 0.0046,    // ~217 ARS/BRL
    ]

    func fetchRates() async -> [String: Double] {
        guard let url = URL(string: "https://open.er-api.com/v6/latest/ARS") else {
            return cached() ?? fallbackRates
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                return cached() ?? fallbackRates
            }
            let decoded = try JSONDecoder().decode(ERResponse.self, from: data)
            guard decoded.result == "success" else { return cached() ?? fallbackRates }
            var rates = decoded.rates
            rates["ARS"] = 1.0
            save(rates)
            return rates
        } catch {
            return cached() ?? fallbackRates
        }
    }

    private func save(_ rates: [String: Double]) {
        guard let data = try? JSONEncoder().encode(rates) else { return }
        UserDefaults.standard.set(data, forKey: "cachedCurrencyRates")
    }

    private func cached() -> [String: Double]? {
        guard let data = UserDefaults.standard.data(forKey: "cachedCurrencyRates"),
              let rates = try? JSONDecoder().decode([String: Double].self, from: data)
        else { return nil }
        return rates
    }
}

private struct ERResponse: Decodable {
    let result: String
    let rates: [String: Double]
}
