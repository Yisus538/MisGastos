import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Compra.fecha, order: .reverse) private var compras: [Compra]
    @AppStorage("usuarioNombre") private var nombre: String = "Usuario"
    @State private var showNuevaCompra = false

    private var cal: Calendar { .current }

    private var comprasEsteMes: [Compra] {
        compras.filter {
            cal.isDate($0.fecha, equalTo: Date(), toGranularity: .month)
        }
    }

    private var comprasMesAnterior: [Compra] {
        guard let prevMonth = cal.date(byAdding: .month, value: -1, to: Date()) else { return [] }
        return compras.filter {
            cal.isDate($0.fecha, equalTo: prevMonth, toGranularity: .month)
        }
    }

    private var totalEsteMes: Double { comprasEsteMes.reduce(0) { $0 + $1.total } }
    private var totalMesAnterior: Double { comprasMesAnterior.reduce(0) { $0 + $1.total } }
    private var delta: Double {
        guard totalMesAnterior > 0 else { return 0 }
        return (totalEsteMes - totalMesAnterior) / totalMesAnterior * 100
    }

    private var promedioEsteMes: Double {
        guard !comprasEsteMes.isEmpty else { return 0 }
        return totalEsteMes / Double(comprasEsteMes.count)
    }

    private var tiendas: Int {
        Set(comprasEsteMes.map { $0.supermercado }).count
    }

    private var mesActual: String {
        Date().formatted(.dateTime.month(.wide))
    }

    private var primerNombre: String {
        nombre.components(separatedBy: " ").first?.uppercased() ?? nombre.uppercased()
    }

    private var statusBarHeight: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.top }
            .first ?? 44
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.saBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                    recentSection
                        .padding(.top, 24)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 140)
                }
            }
            .ignoresSafeArea(edges: .top)

            // FAB
            Button(action: { showNuevaCompra = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(LinearGradient.saGreen, in: Circle())
                    .shadow(color: Color.saGreen.opacity(0.4), radius: 12, y: 6)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 104)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showNuevaCompra) { NuevaCompraView() }
    }

    // MARK: - Header
    private var header: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient.saGreen

            // decorative blob
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 260, height: 260)
                .offset(x: 100, y: -80)

            VStack(alignment: .leading, spacing: 0) {
                // Status bar space
                Color.clear.frame(height: statusBarHeight)

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("HOLA, \(primerNombre) 👋")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .tracking(0.2)
                        Text("Tu resumen de \(mesActual.lowercased())")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .tracking(-0.6)
                    }

                    Spacer()

                    Circle()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 40, height: 40)
                        .overlay(Image(systemName: "bell").font(.system(size: 18)).foregroundStyle(.white))
                }
                .padding(.bottom, 24)

                Text("Gastado este mes")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.85))

                Text(totalEsteMes.formatted(.currency(code: "ARS")))
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.white)
                    .tracking(-1.5)
                    .padding(.top, 4)

                HStack(spacing: 8) {
                    // Delta badge
                    HStack(spacing: 4) {
                        Image(systemName: delta < 0 ? "arrow.down" : "arrow.up")
                            .font(.system(size: 10, weight: .bold))
                        Text(String(format: "%.1f%%", abs(delta)))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(
                        delta < 0
                            ? Color.white.opacity(0.22)
                            : Color.black.opacity(0.18),
                        in: RoundedRectangle(cornerRadius: 10)
                    )

                    if totalMesAnterior > 0 {
                        Text("vs. mes anterior")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding(.top, 8)

                // Quick stats pills
                HStack(spacing: 10) {
                    statPill(label: "Compras", value: "\(comprasEsteMes.count)")
                    statPill(label: "Promedio", value: promedioEsteMes.formatted(.currency(code: "ARS")))
                    statPill(label: "Tiendas", value: "\(tiendas)")
                }
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 20)
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 32,
                bottomTrailingRadius: 32, topTrailingRadius: 0
            )
        )
    }

    @ViewBuilder
    private func statPill(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .tracking(-0.3)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Recent
    @ViewBuilder
    private var recentSection: some View {
        if compras.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Compras recientes")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.saLabel)
                        .tracking(-0.5)
                    Spacer()
                    NavigationLink {
                        HistorialView()
                    } label: {
                        Text("Ver todas")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.saGreen)
                    }
                }

                SACard(padding: 0) {
                    ForEach(Array(compras.prefix(8).enumerated()), id: \.element.id) { idx, compra in
                        NavigationLink {
                            DetalleCompraView(compra: compra)
                        } label: {
                            recentRow(compra: compra, isLast: idx == min(7, compras.count - 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func recentRow(compra: Compra, isLast: Bool) -> some View {
        HStack(spacing: 12) {
            SAStoreAvatar(name: compra.supermercado, size: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(compra.supermercado)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.saLabel)
                    .tracking(-0.3)
                Text("\(compra.fecha.formatted(date: .abbreviated, time: .omitted)) · \(compra.productos.count) items")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.saLabel3)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(compra.total.formatted(.currency(code: "ARS")))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.saLabel)
                    .tracking(-0.3)
                Text(compra.metodoPago.components(separatedBy: " ").first ?? "")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.saLabel3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Color.saSep)
                    .frame(height: 0.5)
                    .padding(.leading, 70)
            }
        }
        .contentShape(Rectangle())
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 60)
            ZStack {
                Circle().fill(Color.saGreenBg).frame(width: 120, height: 120)
                Image(systemName: "cart.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.saGreen)
            }
            Text("Sin compras aún")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.saLabel)
            Text("Tocá el + para registrar\ntu primera compra")
                .font(.system(size: 15))
                .foregroundStyle(Color.saLabel3)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }
}
