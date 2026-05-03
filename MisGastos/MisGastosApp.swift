import SwiftUI
import SwiftData

@main
struct MisGastosApp: App {
    var body: some Scene {
        WindowGroup {
            SplashView()
                .task {
                    // Inicializa SessionStore para que suscriba a authStateChanges de Supabase
                    // antes de que SplashView decida el routing (2.2s de animación de margen).
                    _ = SessionStore.shared
                }
        }
        .modelContainer(for: [Compra.self, Producto.self, Usuario.self])
    }
}
