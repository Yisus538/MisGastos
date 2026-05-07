import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { HomeView() }
                .tag(0)
                .tabItem { Label("Inicio", systemImage: "house.fill") }

            NavigationStack { HistorialView() }
                .tag(1)
                .tabItem { Label("Historial", systemImage: "clock.fill") }

            NavigationStack { EstadisticasView() }
                .tag(2)
                .tabItem { Label("Estadísticas", systemImage: "chart.bar.fill") }

            NavigationStack { ComparativaView() }
                .tag(3)
                .tabItem { Label("Comparar", systemImage: "scalemass.fill") }

            NavigationStack { PerfilView() }
                .tag(4)
                .tabItem { Label("Perfil", systemImage: "person.fill") }
        }
        .tint(Color.saGreen)
        .task {
            // Sincroniza datos al aparecer la UI autenticada.
            // Cubre login manual (donde SplashView ya corrió sin sesión activa)
            // y sesión restaurada desde Keychain con token expirado.
            await SyncService.shared.sincronizarPendientes(context: modelContext)
            await SyncService.shared.pullDesdeSupabase(context: modelContext)
        }
    }
}
