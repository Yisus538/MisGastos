import SwiftUI
import SwiftData

struct HistorialView: View {
    @Query(sort: \Compra.fecha, order: .reverse) private var todas: [Compra]
    @State private var busqueda = ""
    @State private var filtroSuper = "Todas"

    private var supermercados: [String] {
        ["Todas"] + Array(Set(todas.map { $0.supermercado })).sorted()
    }

    private var filtradas: [Compra] {
        todas.filter { c in
            let matchSuper = filtroSuper == "Todas" || c.supermercado == filtroSuper
            let matchSearch = busqueda.isEmpty ||
                c.supermercado.localizedCaseInsensitiveContains(busqueda) ||
                c.metodoPago.localizedCaseInsensitiveContains(busqueda)
            return matchSuper && matchSearch
        }
    }

    // Group by YYYY-MM (ISO key for reliable sorting)
    private let groupCal = Calendar.current

    private var grupos: [(key: String, compras: [Compra])] {
        let grouped = Dictionary(grouping: filtradas) { compra -> String in
            let c = groupCal.dateComponents([.year, .month], from: compra.fecha)
            return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (key: $0.key, compras: $0.value.sorted { $0.fecha > $1.fecha }) }
    }

    private func nombreMes(_ key: String) -> String {
        if let compra = filtradas.first(where: { c in
            let comps = groupCal.dateComponents([.year, .month], from: c.fecha)
            return String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0) == key
        }) {
            return compra.fecha.formatted(.dateTime.month(.wide).year()).capitalized
        }
        return key
    }

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Title
                    Text("Historial")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color.saLabel)
                        .tracking(-1)
                        .padding(.top, 60)
                        .padding(.horizontal, 20)

                    // Search field
                    SAField(placeholder: "Buscar tienda, método...", text: $busqueda, icon: "magnifyingglass")
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    // Store filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(supermercados, id: \.self) { s in
                                let active = filtroSuper == s
                                Button(action: { filtroSuper = s }) {
                                    Text(s)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(active ? .white : Color.saLabel)
                                        .tracking(-0.2)
                                        .padding(.horizontal, 14)
                                        .frame(height: 34)
                                        .background(
                                            active
                                                ? AnyShapeStyle(Color.saGreen)
                                                : AnyShapeStyle(Color.saCard),
                                            in: Capsule()
                                        )
                                        .shadow(
                                            color: active ? .clear : .black.opacity(0.04),
                                            radius: 2, y: 1
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 4)
                    }

                    // Groups
                    VStack(spacing: 20) {
                        if grupos.isEmpty {
                            Text("Sin resultados")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.saLabel3)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else {
                            ForEach(grupos, id: \.key) { grupo in
                                mesGroup(nombre: nombreMes(grupo.key), compras: grupo.compras)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 140)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }

    @ViewBuilder
    private func mesGroup(nombre: String, compras: [Compra]) -> some View {
        let total = compras.reduce(0) { $0 + $1.total }
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(nombre.uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.saLabel3)
                    .tracking(0.2)
                Spacer()
                Text(total.formatted(.currency(code: "ARS")))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.saLabel3)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 10)

            SACard(padding: 0) {
                ForEach(Array(compras.enumerated()), id: \.element.id) { idx, compra in
                    NavigationLink {
                        DetalleCompraView(compra: compra)
                    } label: {
                        historialRow(compra: compra, isLast: idx == compras.count - 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func historialRow(compra: Compra, isLast: Bool) -> some View {
        HStack(spacing: 12) {
            SAStoreAvatar(name: compra.supermercado, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(compra.supermercado)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.saLabel)
                    .tracking(-0.3)
                Text("\(compra.fecha.formatted(date: .abbreviated, time: .omitted)) · \(compra.productos.count) items")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.saLabel3)
            }

            Spacer()

            Text(compra.total.formatted(.currency(code: "ARS")))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.saLabel)
                .tracking(-0.3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(Color.saSep).frame(height: 0.5).padding(.leading, 68)
            }
        }
        .contentShape(Rectangle())
    }
}
