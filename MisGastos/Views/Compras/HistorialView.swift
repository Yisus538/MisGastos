import SwiftUI
import SwiftData

struct HistorialView: View {
    @Query(sort: \Compra.fecha, order: .reverse) private var todas: [Compra]
    @State private var busqueda = ""
    @State private var filtroSuper = "Todas"
    @State private var showExportSheet = false
    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false

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

    private var statusBarHeight: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.top }
            .first ?? 50
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
                    // Title + export button
                    HStack(alignment: .bottom) {
                        Text("Historial")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Color.saLabel)
                            .tracking(-1)
                        Spacer()
                        if !todas.isEmpty {
                            Button { showExportSheet = true } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Color.saGreen)
                                    .frame(width: 36, height: 36)
                                    .background(Color.saCard, in: Circle())
                            }
                        }
                    }
                    .padding(.top, statusBarHeight + 8)
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
                                        .shadow(color: active ? .clear : .black.opacity(0.04), radius: 2, y: 1)
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
                        if todas.isEmpty {
                            ContentUnavailableView {
                                Label("Sin compras", systemImage: "cart")
                            } description: {
                                Text("Aún no registraste ninguna compra.\nUsá el **+** en Inicio para comenzar.")
                            }
                            .padding(.top, 20)
                        } else if grupos.isEmpty {
                            ContentUnavailableView.search(text: busqueda)
                                .padding(.top, 20)
                        } else {
                            ForEach(grupos, id: \.key) { grupo in
                                mesGroup(nombre: nombreMes(grupo.key), compras: grupo.compras)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(compras: todas) { url in
                shareItems = [url]
                // Esperamos a que el sheet se cierre antes de abrir el share sheet
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    showShareSheet = true
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ActivitySheet(items: shareItems)
        }
    }

    // MARK: - Subviews

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

// MARK: - Export Sheet

struct ExportSheet: View {
    let compras: [Compra]
    let onExport: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    private var totalProductos: Int { compras.reduce(0) { $0 + $1.productos.count } }
    private var totalGastado: Double { compras.reduce(0) { $0 + $1.total } }

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(Color.saSep)
                    .frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Exportar historial")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.saLabel)
                        .tracking(-0.5)
                    Text("Elegí el formato para exportar tus compras")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.saLabel3)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                // Stats summary card
                SACard(padding: 14) {
                    HStack(spacing: 0) {
                        statCell(
                            icon: "cart.fill",
                            color: Color.saGreen,
                            value: "\(compras.count)",
                            label: "Compras"
                        )
                        Rectangle().fill(Color.saSep).frame(width: 0.5, height: 36)
                        statCell(
                            icon: "bag.fill",
                            color: Color(hex: "#F97316"),
                            value: "\(totalProductos)",
                            label: "Productos"
                        )
                        Rectangle().fill(Color.saSep).frame(width: 0.5, height: 36)
                        statCell(
                            icon: "dollarsign.circle.fill",
                            color: Color(hex: "#8B5CF6"),
                            value: totalGastado.formatted(.currency(code: "ARS")),
                            label: "Total"
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                // Export options
                VStack(spacing: 10) {
                    exportRow(
                        icon: "tablecells.fill",
                        iconColor: Color.saGreen,
                        title: "Exportar como CSV",
                        subtitle: "Compatible con Excel y Google Sheets"
                    ) {
                        if let url = ExportService.shared.generarCSV(compras: compras) {
                            dismiss()
                            onExport(url)
                        }
                    }

                    exportRow(
                        icon: "doc.richtext.fill",
                        iconColor: Color(hex: "#F97316"),
                        title: "Exportar como PDF",
                        subtitle: "Documento formateado listo para imprimir"
                    ) {
                        if let url = ExportService.shared.generarPDF(compras: compras) {
                            dismiss()
                            onExport(url)
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .presentationDetents([.height(370)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
    }

    @ViewBuilder
    private func statCell(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.saLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.saLabel3)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func exportRow(icon: String, iconColor: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SACard(padding: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(iconColor.opacity(0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: icon)
                            .font(.system(size: 22))
                            .foregroundStyle(iconColor)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.saLabel)
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.saLabel3)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.saLabel4)
                }
                .padding(16)
            }
        }
        .buttonStyle(.plain)
    }
}
