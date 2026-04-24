import SwiftUI
import SwiftData

@main
struct MisGastosApp: App {
    var body: some Scene {
        WindowGroup {
            SplashView()
        }
        .modelContainer(for: [Compra.self, Producto.self, Usuario.self])
    }
}
