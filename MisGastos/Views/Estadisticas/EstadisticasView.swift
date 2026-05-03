import SwiftUI
import SwiftData
import Charts

struct EstadisticasView: View {
    @Query private var compras: [Compra]
    @State private var rango = "6m"
    @State private var chartType = "bar"

    private let cal = Calendar.current

    init() {
        let uid = SessionStore.shared.currentUserID
        _compras = Query(
            filter: #Predicate<Compra> { compra in compra.userId == uid },
            sort: \Compra.fecha,
            order: .reverse
        )
    }

    private var comprasRango: [Compra] {
        let meses: Int
        switch rango {
        case "3m": meses = 3
        case "1y": meses = 12
        default:   meses = 6
        }
        guard let from = cal.date(byAdding: .month, value: -meses, to: Date()) else { return compras }
        return compras.filter { $0.fecha >= from }
    }

    private var comprasEsteMes: [Compra] {
        compras.filter { cal.isDate($0.fecha, equalTo: Date(), toGranularity: .month) }
    }

    private var comprasMesAnterior: [Compra] {
        guard let prev = cal.date(byAdding: .month, value: -1, to: Date()) else { return [] }
        return compras.filter { cal.isDate($0.fecha, equalTo: prev, toGranularity: .month) }
    }

    private var totalEsteMes: Double { comprasEsteMes.reduce(0) { $0 + $1.total } }
    private var totalMesAnterior: Double { comprasMesAnterior.reduce(0) { $0 + $1.total } }
    private var delta: Double {
        guard totalMesAnterior > 0 else { return 0 }
        return (totalEsteMes - totalMesAnterior) / totalMesAnterior * 100
    }
    private var diff: Double { totalEsteMes - totalMesAnterior }

    private var gastoMensual: [(mes: String, label: String, total: Double)] {
        let grouped = Dictionary(grouping: comprasRango) { compra -> String in
            let c = cal.dateComponents([.year, .month], from: compra.fecha)
            return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
        }
        return grouped.map { key, cs in
            let label = cs.first.map {
                $0.fecha.formatted(.dateTime.month(.abbreviated))
            } ?? key
            return (mes: key, label: label, total: cs.reduce(0) { $0 + $1.total })
        }
        .sorted { $0.mes < $1.mes }
    }

    private var gastosPorSuper: [(nombre: String, total: Double)] {
        Dictionary(grouping: comprasRango, by: { $0.supermercado })
            .map { (nombre: $0.key, total: $0.value.reduce(0) { $0 + $1.total }) }
            .sorted { $0.total > $1.total }
    }

    private var ticketPromedio: Double {
        guard !comprasEsteMes.isEmpty else { return 0 }
        return totalEsteMes / Double(comprasEsteMes.count)
    }

    private var mayorCompra: Double {
        comprasEsteMes.map { $0.total }.max() ?? 0
    }

    private var productosMasComprados: [(nombre: String, cantidad: Int)] {
        let todos = comprasRango.flatMap { $0.productos }
        return Dictionary(grouping: todos, by: { $0.nombre })
            .map { (nombre: $0.key, cantidad: $0.value.count) }
            .sorted { $0.cantidad > $1.cantidad }
            .prefix(5)
            .map { $0 }
    }

    private var statusBarHeight: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.top }
            .first ?? 50
    }

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Estadísticas")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Color.saLabel)
                            .tracking(-1)
                        Text("Tus gastos, visualizados")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.saLabel3)
                    }
                    .padding(.top, statusBarHeight + 8)
                    .padding(.horizontal, 20)

                    // Range picker
                    HStack(spacing: 0) {
                        ForEach([("3m", "3 meses"), ("6m", "6 meses"), ("1y", "1 año")], id: \.0) { k, l in
                            let active = rango == k
                            Button(action: { rango = k }) {
                                Text(l)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(active ? .white : Color.saLabel2)
                                    .tracking(-0.2)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 32)
                                    .background(active ? Color.saGreen : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(3)
                    .background(Color.saCard, in: RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 20)

                    VStack(spacing: 16) {
                        // Trend card
                        SACard {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Tendencia mensual")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.saLabel3)
                                    Text(totalEsteMes.formatted(.currency(code: "ARS")))
                                        .font(.system(size: 26, weight: .bold))
                                        .foregroundStyle(Color.saLabel)
                                        .tracking(-0.8)
                                }
                                Spacer()
                                // Chart type toggle
                                HStack(spacing: 2) {
                                    ForEach([("bar", "chart.bar.fill"), ("line", "chart.line.uptrend.xyaxis")], id: \.0) { k, icon in
                                        Button(action: { chartType = k }) {
                                            Image(systemName: icon)
                                                .font(.system(size: 13))
                                                .foregroundStyle(chartType == k ? Color.saLabel : Color.saLabel3)
                                                .frame(width: 30, height: 26)
                                                .background(chartType == k ? Color.saCard : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                                                .shadow(color: chartType == k ? .black.opacity(0.1) : .clear, radius: 2, y: 1)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(2)
                                .background(Color.saBg, in: RoundedRectangle(cornerRadius: 8))
                            }
                            .padding(.bottom, 14)

                            if gastoMensual.isEmpty {
                                Text("Sin datos para el período")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.saLabel3)
                                    .frame(height: 150)
                                    .frame(maxWidth: .infinity)
                            } else if chartType == "bar" {
                                Chart(gastoMensual, id: \.mes) { item in
                                    BarMark(x: .value("Mes", item.label), y: .value("Total", item.total))
                                        .foregroundStyle(LinearGradient.saGreen)
                                        .cornerRadius(6)
                                }
                                .frame(height: 150)
                                .chartYAxis { AxisMarks { _ in AxisGridLine().foregroundStyle(Color.saSep) } }
                                .chartXAxis { AxisMarks { v in AxisValueLabel().font(.system(size: 10)) } }
                            } else {
                                Chart(gastoMensual, id: \.mes) { item in
                                    LineMark(x: .value("Mes", item.label), y: .value("Total", item.total))
                                        .foregroundStyle(Color.saGreen)
                                        .interpolationMethod(.catmullRom)
                                    AreaMark(x: .value("Mes", item.label), y: .value("Total", item.total))
                                        .foregroundStyle(Color.saGreen.opacity(0.12))
                                        .interpolationMethod(.catmullRom)
                                }
                                .frame(height: 150)
                                .chartYAxis { AxisMarks { _ in AxisGridLine().foregroundStyle(Color.saSep) } }
                                .chartXAxis { AxisMarks { v in AxisValueLabel().font(.system(size: 10)) } }
                            }
                        }

                        // vs. Mes anterior
                        VStack(alignment: .leading, spacing: 10) {
                            Text("VS. MES ANTERIOR")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.saLabel3)
                                .tracking(0.2)
                                .padding(.horizontal, 4)

                            SACard {
                                HStack(spacing: 14) {
                                    Circle()
                                        .fill(delta < 0 ? Color.saGreenBg : Color.saDanger.opacity(0.1))
                                        .frame(width: 64, height: 64)
                                        .overlay(
                                            Image(systemName: delta < 0 ? "arrow.down" : "arrow.up")
                                                .font(.system(size: 24, weight: .bold))
                                                .foregroundStyle(delta < 0 ? Color.saGreen : Color.saDanger)
                                        )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(delta < 0 ? "Gastaste menos" : "Gastaste más")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color.saLabel3)
                                        Text((diff >= 0 ? "+" : "") + diff.formatted(.currency(code: "ARS")))
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundStyle(delta < 0 ? Color.saGreen : Color.saDanger)
                                            .tracking(-0.6)
                                        Text(String(format: "%.1f%% de variación", delta))
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.saLabel3)
                                    }
                                }

                                // Side by side bars
                                let maxVal = max(totalEsteMes, totalMesAnterior, 1)
                                HStack(spacing: 12) {
                                    monthBar(label: "Mes anterior", value: totalMesAnterior, max: maxVal, color: Color.saLabel4)
                                    monthBar(label: "Este mes", value: totalEsteMes, max: maxVal, color: Color.saGreen)
                                }
                                .padding(.top, 20)
                            }
                        }

                        // Insights 2x2
                        VStack(alignment: .leading, spacing: 10) {
                            Text("TU MES")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.saLabel3)
                                .tracking(0.2)
                                .padding(.horizontal, 4)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                insightCard(icon: "receipt", label: "Compras", value: "\(comprasEsteMes.count)", bg: Color(hex: "#3B82F6"))
                                insightCard(icon: "storefront", label: "Tiendas", value: "\(Set(comprasEsteMes.map { $0.supermercado }).count)", bg: Color(hex: "#F97316"))
                                insightCard(icon: "tag.fill", label: "Ticket promedio", value: ticketPromedio.formatted(.currency(code: "ARS")), bg: Color.saGreen, small: true)
                                insightCard(icon: "bookmark.fill", label: "Mayor compra", value: mayorCompra.formatted(.currency(code: "ARS")), bg: Color(hex: "#A855F7"), small: true)
                            }
                        }
                        // Distribución por tienda — SectorMark (donut)
                        if !gastosPorSuper.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("DISTRIBUCIÓN POR TIENDA")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.saLabel3)
                                    .tracking(0.2)
                                    .padding(.horizontal, 4)

                                SACard {
                                    Chart(gastosPorSuper.prefix(6), id: \.nombre) { item in
                                        SectorMark(
                                            angle: .value("Gasto", item.total),
                                            innerRadius: .ratio(0.55),
                                            angularInset: 2
                                        )
                                        .foregroundStyle(by: .value("Tienda", item.nombre))
                                        .cornerRadius(4)
                                    }
                                    .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
                                    .frame(height: 220)
                                }
                            }
                        }

                        // Productos más comprados — BarMark horizontal
                        if !productosMasComprados.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("PRODUCTOS MÁS COMPRADOS")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.saLabel3)
                                    .tracking(0.2)
                                    .padding(.horizontal, 4)

                                SACard {
                                    Chart(productosMasComprados, id: \.nombre) { item in
                                        BarMark(
                                            x: .value("Cantidad", item.cantidad),
                                            y: .value("Producto", item.nombre)
                                        )
                                        .foregroundStyle(LinearGradient.saGreen)
                                        .cornerRadius(6)
                                        .annotation(position: .trailing) {
                                            Text("\(item.cantidad)x")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(Color.saLabel3)
                                        }
                                    }
                                    .frame(height: CGFloat(productosMasComprados.count) * 46)
                                    .chartXAxis {
                                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                                            AxisGridLine().foregroundStyle(Color.saSep)
                                            AxisValueLabel()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }

    @ViewBuilder
    private func monthBar(label: String, value: Double, max: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12)).foregroundStyle(Color.saLabel3)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5).fill(Color.saBg).frame(height: 10)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(value / max), height: 10)
                        .animation(.easeInOut(duration: 0.7), value: value)
                }
            }
            .frame(height: 10)
            Text(value.formatted(.currency(code: "ARS")))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.saLabel)
                .tracking(-0.3)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func insightCard(icon: String, label: String, value: String, bg: Color, small: Bool = false) -> some View {
        SACard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(bg)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.system(size: 12)).foregroundStyle(Color.saLabel3).tracking(-0.1)
                    Text(value)
                        .font(.system(size: small ? 15 : 22, weight: .bold))
                        .foregroundStyle(Color.saLabel)
                        .tracking(-0.4)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }
}
