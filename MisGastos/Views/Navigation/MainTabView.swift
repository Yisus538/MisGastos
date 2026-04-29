import SwiftUI

struct MainTabView: View {
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
    }
}
