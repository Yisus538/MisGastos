import SwiftUI
import SwiftData

struct ComparativaView: View {
    @Query(sort: \Compra.fecha, order: .reverse) private var compras: [Compra]
    @State private var busqueda = ""

    // MARK: - Private types

    private struct PrecioEnSuper: Identifiable {
        let id = UUID()
        let supermercado: String
        let precio: Double
        let fecha: Date
    }

    private struct ItemComparativa: Identifiable {
        let id = UUID()
        let nombre: String
        let precios: [PrecioEnSuper]  // ordenados de menor a mayor precio
        var minPrecio: Double { precios.first?.precio ?? 0 }
        var maxPrecio: Double { precios.last?.precio ?? 0 }
        var ahorro: Double { maxPrecio - minPrecio }
        var superMasBarato: String { precios.first?.supermercado ?? "" }
    }

    // MARK: - Computed data

    private var comparativas: [ItemComparativa] {
        var map: [String: [(super: String, precio: Double, fecha: Date)]] = [:]
        for compra in compras {
            for producto in compra.productos {
                let key = producto.nombre.lowercased().trimmingCharacters(in: .whitespaces)
                map[key, default: []].append((compra.supermercado, producto.precio, compra.fecha))
            }
        }
        return map.compactMap { nombre, entradas -> ItemComparativa? in
            guard Set(entradas.map(\.super)).count >= 2 else { return nil }
            // Último precio registrado por supermercado
            var latest: [String: (super: String, precio: Double, fecha: Date)] = [:]
            for e in entradas.sorted(by: { $0.fecha < $1.fecha }) { latest[e.super] = e }
            let precios = latest.values
                .map { PrecioEnSuper(supermercado: $0.super, precio: $0.precio, fecha: $0.fecha) }
                .sorted { $0.precio < $1.precio }
            return ItemComparativa(nombre: nombre.capitalized, precios: precios)
        }
        .sorted { $0.ahorro > $1.ahorro }
    }

    private var filtradas: [ItemComparativa] {
        busqueda.isEmpty ? comparativas
            : comparativas.filter { $0.nombre.localizedCaseInsensitiveContains(busqueda) }
    }

    private var statusBarHeight: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.top }
            .first ?? 50
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 2) {
                    Text("Comparativa")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color.saLabel)
                        .tracking(-1)
                    Text("Encontrá dónde comprás más barato")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.saLabel3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, statusBarHeight + 8)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.saLabel3)
                        .font(.system(size: 15))
                    TextField("Buscar producto...", text: $busqueda)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.saLabel)
                    if !busqueda.isEmpty {
                        Button { busqueda = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.saLabel4)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Color.saCard, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                // Content
                if comparativas.isEmpty {
                    ContentUnavailableView {
                        Label("Sin comparativas", systemImage: "scalemass")
                    } description: {
                        Text("Registrá el mismo producto en 2 o más supermercados para ver la comparativa de precios.")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filtradas.isEmpty {
                    ContentUnavailableView.search(text: busqueda)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Stats pill
                            if busqueda.isEmpty {
                                statsHeader
                                    .padding(.bottom, 16)
                            }

                            VStack(spacing: 12) {
                                ForEach(filtradas) { item in
                                    comparativaCard(item)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Subviews

    private var statsHeader: some View {
        SACard(padding: 14) {
            HStack(spacing: 0) {
                statCell(
                    icon: "scalemass.fill",
                    color: Color.saGreen,
                    value: "\(comparativas.count)",
                    label: "Productos\ncomparados"
                )
                Divider().frame(height: 36).padding(.horizontal, 12)
                statCell(
                    icon: "building.2.fill",
                    color: Color(hex: "#F97316"),
                    value: "\(Set(comparativas.flatMap { $0.precios.map(\.supermercado) }).count)",
                    label: "Tiendas\ncomparadas"
                )
                Divider().frame(height: 36).padding(.horizontal, 12)
                statCell(
                    icon: "tag.fill",
                    color: Color(hex: "#8B5CF6"),
                    value: (comparativas.map(\.ahorro).max() ?? 0).formatted(.currency(code: "ARS")),
                    label: "Mayor\nahorro"
                )
            }
        }
    }

    @ViewBuilder
    private func statCell(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.saLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.saLabel3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func comparativaCard(_ item: ItemComparativa) -> some View {
        SACard(padding: 0) {
            VStack(spacing: 0) {
                // Product name + savings badge
                HStack {
                    Text(item.nombre)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.saLabel)
                        .tracking(-0.3)
                    Spacer()
                    if item.ahorro > 0 {
                        Text("−" + item.ahorro.formatted(.currency(code: "ARS")))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.saGreen)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.saGreenBg, in: Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.saSep).frame(height: 0.5)
                }

                // Price rows (already sorted cheapest → most expensive)
                ForEach(Array(item.precios.enumerated()), id: \.element.id) { idx, precio in
                    let isCheapest = precio.precio == item.minPrecio
                    let isMostExp  = precio.precio == item.maxPrecio && item.ahorro > 0

                    HStack(spacing: 12) {
                        SAStoreAvatar(name: precio.supermercado, size: 36)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(precio.supermercado)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.saLabel)
                            Text(precio.fecha.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 11))
                                .foregroundStyle(Color.saLabel4)
                        }

                        Spacer()

                        if isCheapest {
                            Text("MÁS BARATO")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.saGreen)
                                .tracking(0.3)
                        } else if isMostExp {
                            Text("MÁS CARO")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.saDanger)
                                .tracking(0.3)
                        }

                        Text(precio.precio.formatted(.currency(code: "ARS")))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(
                                isCheapest ? Color.saGreen
                                : isMostExp ? Color.saDanger
                                : Color.saLabel
                            )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) {
                        if idx < item.precios.count - 1 {
                            Rectangle().fill(Color.saSep).frame(height: 0.5).padding(.leading, 64)
                        }
                    }
                }

                // Footer: recommendation
                if item.ahorro > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.saGreen)
                        Text("Comprá en **\(item.superMasBarato)** y ahorrás \(item.ahorro.formatted(.currency(code: "ARS")))")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.saLabel3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .overlay(alignment: .top) {
                        Rectangle().fill(Color.saSep).frame(height: 0.5)
                    }
                }
            }
        }
    }
}
