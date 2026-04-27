import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    private let tabs: [(icon: String, label: String)] = [
        ("house.fill", "Inicio"),
        ("clock.fill", "Historial"),
        ("chart.bar.fill", "Estadísticas"),
        ("person.fill", "Perfil"),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            // TabView sin swipe: usa .tabViewStyle(.automatic) implícito
            // pero ocultamos la tab bar nativa con toolbarVisibility
            TabView(selection: $selectedTab) {
                NavigationStack { HomeView() }
                    .tag(0)
                    .toolbar(.hidden, for: .tabBar)

                NavigationStack { HistorialView() }
                    .tag(1)
                    .toolbar(.hidden, for: .tabBar)

                NavigationStack { EstadisticasView() }
                    .tag(2)
                    .toolbar(.hidden, for: .tabBar)

                NavigationStack { PerfilView() }
                    .tag(3)
                    .toolbar(.hidden, for: .tabBar)
            }
            .ignoresSafeArea(edges: .bottom)

            // Custom liquid-glass pill tab bar
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { idx, tab in
                    tabItem(icon: tab.icon, label: tab.label, tag: idx)
                }
            }
            .frame(height: 64)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 32).fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 32).stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                }
            )
            .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
            .padding(.horizontal, 12)
            .padding(.bottom, 20)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private func tabItem(icon: String, label: String, tag: Int) -> some View {
        let active = selectedTab == tag
        Button(action: { selectedTab = tag }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: active ? .semibold : .regular))
                    .foregroundStyle(active ? Color.saGreen : Color.saLabel3)
                Text(label)
                    .font(.system(size: 10, weight: active ? .semibold : .regular))
                    .foregroundStyle(active ? Color.saGreen : Color.saLabel3)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
