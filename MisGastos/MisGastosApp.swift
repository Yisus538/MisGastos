import SwiftUI
import SwiftData

@main
struct MisGastosApp: App {
    var body: some Scene {
        WindowGroup {
            SplashView()
                .task {
                    // Restaura la sesión Supabase antes de que cualquier vista
                    // intente acceder a currentUserID
                    await SupabaseService.shared.restaurarSesion()
                }
        }
        .modelContainer(for: [Compra.self, Producto.self, Usuario.self])
    }
}
