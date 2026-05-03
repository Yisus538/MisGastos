import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Compra.fecha, order: .reverse) private var compras: [Compra]
    @AppStorage("usuarioNombre")       private var nombre: String = "Usuario"
    @AppStorage("presupuestoActivo")   private var presupuestoActivo: Bool = false
    @AppStorage("presupuestoMensual")  private var presupuesto: Double = 0
    @AppStorage("presupuestoAlertaMes") private var presupuestoAlertaMes: String = ""
    @State private var showNuevaCompra = false
    @State private var showBudgetAlert = false

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
                    if presupuestoActivo && presupuesto > 0 {
                        budgetCard
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                    }
                    recentSection
                        .padding(.top, 24)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
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
            .padding(.bottom, 28)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showNuevaCompra) { NuevaCompraView() }
        .alert("Presupuesto superado", isPresented: $showBudgetAlert) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text("Gastaste \(totalEsteMes.formatted(.currency(code: "ARS"))) este mes, superando tu límite de \(presupuesto.formatted(.currency(code: "ARS"))) por \((totalEsteMes - presupuesto).formatted(.currency(code: "ARS"))).")
        }
        .onAppear {
            verificarPresupuesto()
            writeWidgetData()
        }
        .onChange(of: totalEsteMes) { _, _ in
            verificarPresupuesto()
            writeWidgetData()
        }
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

    // MARK: - Budget card

    @ViewBuilder
    private var budgetCard: some View {
        let progress = presupuesto > 0 ? min(totalEsteMes / presupuesto, 1.0) : 0
        let pct      = Int(progress * 100)
        let excedido = totalEsteMes >= presupuesto
        let cercano  = progress >= 0.8
        let barColor: Color = excedido ? .saDanger : cercano ? Color(hex: "#F97316") : .saGreen

        SACard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: excedido ? "exclamationmark.triangle.fill"
                                     : cercano  ? "exclamationmark.circle.fill" : "target")
                        .font(.system(size: 15))
                        .foregroundStyle(barColor)
                    Text("Presupuesto de \(mesActual.lowercased())")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.saLabel)
                        .tracking(-0.3)
                    Spacer()
                    Text("\(pct)%")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(barColor)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.saBg).frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(barColor)
                            .frame(width: max(0, geo.size.width * CGFloat(progress)), height: 8)
                            .animation(.spring(duration: 0.4), value: progress)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text(totalEsteMes.formatted(.currency(code: "ARS")))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(barColor)
                    Text("/ \(presupuesto.formatted(.currency(code: "ARS")))")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.saLabel3)
                    Spacer()
                    if excedido {
                        Text("Límite superado")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.saDanger)
                    } else if cercano {
                        Text("Cerca del límite")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(hex: "#F97316"))
                    }
                }
            }
        }
    }

    private func verificarPresupuesto() {
        guard presupuestoActivo, presupuesto > 0, totalEsteMes >= presupuesto else { return }
        let mesKey = Date().formatted(.dateTime.year().month())
        guard presupuestoAlertaMes != mesKey else { return }
        presupuestoAlertaMes = mesKey
        showBudgetAlert = true
    }

    private func writeWidgetData() {
        WidgetDataWriter.write(
            totalMes: totalEsteMes,
            nombreMes: Date().formatted(.dateTime.month(.wide)).capitalized,
            cantidadCompras: comprasEsteMes.count,
            presupuesto: presupuesto,
            presupuestoActivo: presupuestoActivo
        )
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Sin compras aún", systemImage: "cart.fill")
        } description: {
            Text("Tocá el **+** para registrar\ntu primera compra")
        }
        .padding(.top, 40)
    }
}
