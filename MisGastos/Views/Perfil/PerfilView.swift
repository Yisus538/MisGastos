import SwiftUI
import SwiftData

struct PerfilView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var compras: [Compra]

    @State private var showSettings = false
    @State private var showEditar   = false

    // ── CORRECCIÓN: @State para que SwiftUI observe los cambios del store ──
    @State private var store = UserScopedStorage.shared

    // Datos del usuario — reactivos gracias a @Observable en UserScopedStorage
    private var nombre:     String { store.nombre }
    private var email:      String { store.email }
    private var avatarData: Data   { store.avatarData }

    init() {
        let uid = SessionStore.shared.currentUserID
        _compras = Query(
            filter: #Predicate<Compra> { compra in compra.userId == uid },
            sort: \Compra.fecha,
            order: .reverse
        )
    }

    private var totalGastado:          Double { compras.reduce(0) { $0 + $1.total } }
    private var supermercadosDistintos: Int   { Set(compras.map { $0.supermercado }).count }

    private var initials: String {
        let parts = nombre.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return nombre.prefix(2).uppercased().isEmpty ? "ML" : nombre.prefix(2).uppercased()
    }

    private var statusBarHeight: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.top }
            .first ?? 44
    }

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Green gradient header
                    ZStack(alignment: .topTrailing) {
                        LinearGradient.saGreen

                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 280, height: 280)
                            .offset(x: 100, y: -100)

                        VStack(spacing: 0) {
                            Color.clear.frame(height: statusBarHeight)

                            HStack {
                                Text("Perfil")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(.white)
                                    .tracking(-0.6)
                                Spacer()
                                Button(action: { showSettings = true }) {
                                    Circle()
                                        .fill(Color.white.opacity(0.22))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Image(systemName: "gearshape")
                                                .font(.system(size: 18))
                                                .foregroundStyle(.white)
                                        )
                                }
                            }
                            .padding(.bottom, 28)

                            HStack(spacing: 14) {
                                // Avatar
                                Group {
                                    if !avatarData.isEmpty, let uiImg = UIImage(data: avatarData) {
                                        Image(uiImage: uiImg)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 72, height: 72)
                                            .clipShape(Circle())
                                            .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                                    } else {
                                        ZStack {
                                            Circle()
                                                .fill(LinearGradient(
                                                    colors: [Color(hex: "#FEF3C7"), Color(hex: "#FBBF24")],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ))
                                                .frame(width: 72, height: 72)
                                                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                                            Text(initials)
                                                .font(.system(size: 28, weight: .bold))
                                                .foregroundStyle(Color(hex: "#92400E"))
                                        }
                                    }
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(nombre.isEmpty ? "Usuario" : nombre)
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundStyle(.white)
                                        .tracking(-0.6)
                                    Text(email.isEmpty ? "" : email)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white.opacity(0.9))

                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                        Text("Plan Pro")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 3)
                                    .background(Color.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 10))
                                    .padding(.top, 2)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 80)
                        }
                        .padding(.horizontal, 20)
                    }

                    // Stats overlay card
                    SACard(padding: 0) {
                        HStack(spacing: 0) {
                            statCell(value: "\(compras.count)", label: "COMPRAS", green: false)
                            Divider().frame(height: 60)
                            statCell(value: store.convert(totalGastado).formatted(.currency(code: store.currencyCode)), label: "TOTAL HISTÓRICO", green: false, small: true)
                            Divider().frame(height: 60)
                            statCell(value: store.convert(totalGastado * 0.12).formatted(.currency(code: store.currencyCode)), label: "AHORRADO", green: true, small: true)
                        }
                    }
                    .padding(.horizontal, 20)
                    .offset(y: -40)

                    // Main content
                    VStack(spacing: 0) {
                        sectionLabel("Cuenta")

                        SACard(padding: 0) {
                            menuRow(icon: "person.fill", iconBg: Color.saGreen, title: "Editar perfil", isLast: false) {
                                showEditar = true
                            }
                            menuRow(icon: "creditcard.fill", iconBg: Color(hex: "#8B5CF6"), title: "Métodos de pago", subtitle: "3 tarjetas guardadas", isLast: false) {}
                            menuRow(icon: "storefront.fill", iconBg: Color(hex: "#F97316"), title: "Tiendas favoritas", isLast: true) {}
                        }

                        sectionLabel("Objetivos").padding(.top, 22)

                        SACard {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.saGreenBg)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Image(systemName: "bookmark.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(Color.saGreen)
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Gasto mensual")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Color.saLabel)
                                        .tracking(-0.3)
                                    Text("\(store.convert(totalGastado).formatted(.currency(code: store.currencyCode))) de \(store.convert(500000.0).formatted(.currency(code: store.currencyCode)))")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.saLabel3)
                                }
                                Spacer()
                                Text("\(Int(min(totalGastado / 500000 * 100, 100)))%")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Color.saGreen)
                            }

                            let progress = min(totalGastado / 500000, 1.0)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4).fill(Color.saBg).frame(height: 8)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(LinearGradient(colors: [Color.saGreenLight, Color.saGreen], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: geo.size.width * CGFloat(progress), height: 8)
                                }
                            }
                            .frame(height: 8)
                            .padding(.top, 12)
                        }

                        sectionLabel("Más").padding(.top, 22)

                        SACard(padding: 0) {
                            menuRow(icon: "square.and.arrow.up.fill", iconBg: Color(hex: "#06B6D4"), title: "Invitar amigos", subtitle: "Ganá 1 mes Pro gratis", isLast: false) {}
                            menuRow(icon: "gearshape.fill", iconBg: Color.saLabel3, title: "Ajustes", isLast: true) {
                                showSettings = true
                            }
                        }

                        // Logout
                        Button {
                            Task { try? await SupabaseService.shared.logout() }
                        } label: {
                            Text("Cerrar sesión")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.saDanger)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.saCard, in: RoundedRectangle(cornerRadius: 14))
                                .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 24)
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 20)
                    .offset(y: -40)
                    .padding(.bottom, -40)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showSettings) { SettingsView() }
        // ── CORRECCIÓN: recargar datos al volver de EditarPerfilView ──
        .sheet(isPresented: $showEditar) {
            EditarPerfilView()
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func statCell(value: String, label: String, green: Bool, small: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: small ? 15 : 22, weight: .bold))
                .foregroundStyle(green ? Color.saGreen : Color.saLabel)
                .tracking(-0.4)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.saLabel3)
                .tracking(0.1)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 10)
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.saLabel3)
            .tracking(0.2)
            .padding(.horizontal, 4)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func menuRow(icon: String, iconBg: Color, title: String, subtitle: String? = nil, isLast: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(iconBg)
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.saLabel)
                    if let sub = subtitle {
                        Text(sub)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.saLabel3)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.saLabel4)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 60)
            .overlay(alignment: .bottom) {
                if !isLast {
                    Rectangle().fill(Color.saSep).frame(height: 0.5).padding(.leading, 62)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
