import SwiftUI

@Observable
final class ComprasViewModel {
    var supermercados: [String] = []
    var isLoading: Bool = false
    var errorMessage: String?

    func cargarSupermercados() async {
        isLoading = true
        defer { isLoading = false }
        do {
            supermercados = try await NetworkService.shared.fetchSupermercados()
        } catch {
            errorMessage = error.localizedDescription
            supermercados = NetworkService.shared.supermercadosFallback
        }
    }
}
