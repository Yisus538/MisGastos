import Foundation

struct SupermercadoAPI: Codable, Identifiable {
    let id: String
    let nombre: String
    let logo: String?
}

final class NetworkService {
    static let shared = NetworkService()
    private let base = "https://jsonplaceholder.typicode.com"

    let supermercadosFallback = [
        "Carrefour", "Dia", "Coto", "Jumbo", "La Anonima",
        "Vea", "Walmart", "El Super", "Disco", "Norte"
    ]

    func fetchSupermercados() async throws -> [String] {
        struct UserAPIResponse: Codable {
            struct Company: Codable { let name: String }
            let company: Company
        }
        let url = URL(string: "\(base)/users")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let users = try JSONDecoder().decode([UserAPIResponse].self, from: data)
        return users.map { $0.company.name }
    }
}
