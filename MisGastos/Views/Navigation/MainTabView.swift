import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @AppStorage("avatarData") private var avatarData: Data = Data()

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                NavigationStack { HomeView() }.tag(0)
                NavigationStack { HistorialView() }.tag(1)
                NavigationStack { EstadisticasView() }.tag(2)
                NavigationStack { ComparativaView() }.tag(3)
                NavigationStack { PerfilView() }.tag(4)
            }
            .tint(Color.saGreen)
            // Contenido se puede desplazar detrás del glass — inset solo reserva
            // espacio para que el último item no quede permanentemente oculto
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: pillHeight + safeAreaBottom)
            }

            SATabBar(selected: $selectedTab, avatarData: avatarData)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var safeAreaBottom: CGFloat { UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.bottom }.first ?? 0 }

    private var pillHeight: CGFloat { 68 }
}

// MARK: - Liquid Glass Tab Bar (iOS 26)

private struct SATabBar: View {
    @Binding var selected: Int
    let avatarData: Data

    private let items: [(icon: String, label: String)] = [
        ("house.fill",     "Inicio"),
        ("clock.fill",     "Historial"),
        ("chart.bar.fill", "Estadísticas"),
        ("scalemass.fill", "Comparar"),
    ]

    private var safeAreaBottom: CGFloat { UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.bottom }.first ?? 0 }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { i in
                iconTab(index: i, icon: items[i].icon, label: items[i].label)
            }
            perfilTab
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .glassEffect(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.bottom, safeAreaBottom + 12)
    }

    // MARK: - Icon tab

    private func iconTab(index: Int, icon: String, label: String) -> some View {
        let active = selected == index
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) { selected = index }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    // Indicador del tab activo (glass bubble)
                    if active {
                        Capsule()
                            .fill(Color.saGreen.opacity(0.14))
                            .frame(width: 52, height: 30)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: active ? .semibold : .regular))
                        .foregroundStyle(active ? Color.saGreen : .secondary)
                        .scaleEffect(active ? 1.08 : 1)
                        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: active)
                }
                .frame(height: 32)

                Text(label)
                    .font(.system(size: 10, weight: active ? .medium : .regular))
                    .foregroundStyle(active ? Color.saGreen : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Perfil tab con avatar real

    private var perfilTab: some View {
        let active = selected == 4
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) { selected = 4 }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if active {
                        Capsule()
                            .fill(Color.saGreen.opacity(0.14))
                            .frame(width: 52, height: 30)
                            .transition(.scale.combined(with: .opacity))
                    }
                    avatarIcon(active: active)
                }
                .frame(height: 32)

                Text("Perfil")
                    .font(.system(size: 10, weight: active ? .medium : .regular))
                    .foregroundStyle(active ? Color.saGreen : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func avatarIcon(active: Bool) -> some View {
        if !avatarData.isEmpty, let uiImg = UIImage(data: avatarData) {
            Image(uiImage: uiImg)
                .resizable()
                .scaledToFill()
                .frame(width: 24, height: 24)
                .clipShape(Circle())
                .overlay(Circle().stroke(active ? Color.saGreen : Color(.tertiaryLabel), lineWidth: 1.5))
                .scaleEffect(active ? 1.08 : 1)
                .animation(.spring(response: 0.35, dampingFraction: 0.72), value: active)
        } else {
            Image(systemName: "person.fill")
                .font(.system(size: 20, weight: active ? .semibold : .regular))
                .foregroundStyle(active ? Color.saGreen : .secondary)
                .scaleEffect(active ? 1.08 : 1)
                .animation(.spring(response: 0.35, dampingFraction: 0.72), value: active)
        }
    }
}
