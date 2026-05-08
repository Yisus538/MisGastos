// =============================================================================
// HistorialView.swift — Historial completo de compras con filtros y exportación
// =============================================================================
// Rol en la app:
//   Muestra todas las compras del usuario agrupadas por mes, con capacidades de:
//   - Búsqueda por texto (tienda, método de pago).
//   - Filtro rápido por supermercado (pills horizontales).
//   - Filtros avanzados (fecha desde/hasta, monto mínimo/máximo, orden).
//   - Exportación a CSV o PDF via `ExportService`.
//   - Pills de filtros activos con botón de eliminar individual.
//
// Equivalente Android:
//   `HistorialFragment` con `RecyclerView` + `SearchView` + `BottomSheet` de filtros.
//   La agrupación por mes se hace con `DiffUtil.ItemCallback` o `groupBy` en Kotlin.
//   La exportación usa `FileProvider` + `Intent.ACTION_SEND`.
//
// Filtrado en memoria vs. predicado de SwiftData:
//   Se hace filtrado en memoria (no en el predicate de @Query) porque:
//   1. El userId no está disponible al inicializar la view (sesión puede cargar tarde).
//   2. Los filtros múltiples con fechas y rangos son difíciles de expresar con
//      `#Predicate` de SwiftData (limitaciones del macro).
//   Con grandes volúmenes de datos (miles de compras), sería mejor usar predicates.
//
// Agrupación por mes:
//   `Dictionary(grouping:by:)` agrupa las compras por "YYYY-MM" y luego se ordena.
//   Equivalente Android: `.groupBy { it.fecha.month }` en una colección de Kotlin,
//   o `SectionIndexTitles` en un adaptador de `RecyclerView`.
//
// Exportación:
//   `ExportSheet` genera el archivo (CSV o PDF) via `ExportService` y llama
//   el closure `onExport(url)` con la URL temporal del archivo.
//   Luego se presenta `ActivitySheet` (UIActivityViewController) para compartir.
// =============================================================================

import SwiftUI
import SwiftData

// MARK: - Enum de orden del historial

/// Opciones de ordenamiento disponibles para el historial de compras.
///
/// Implementa `CaseIterable` para poder iterar todos los casos en la UI.
/// Equivalente Android: un `enum class` con las opciones de `ORDER BY` de Room.
enum OrdenHistorial: String, CaseIterable {
    case fechaReciente = "Más reciente"
    case fechaAntigua  = "Más antigua"
    case mayorTotal    = "Mayor total"
    case menorTotal    = "Menor total"

    /// SF Symbol correspondiente a cada opción de orden.
    var icon: String {
        switch self {
        case .fechaReciente: return "arrow.down.circle.fill"
        case .fechaAntigua:  return "arrow.up.circle.fill"
        case .mayorTotal:    return "arrow.up.right.circle.fill"
        case .menorTotal:    return "arrow.down.right.circle.fill"
        }
    }
}

// MARK: - Vista principal de Historial

/// Pantalla de historial de compras con filtros, búsqueda y exportación.
///
/// Equivalente Android: `HistorialActivity` con `RecyclerView` secccionado por mes.
struct HistorialView: View {

    // MARK: - Fuentes de datos

    /// Todas las compras de SwiftData, ordenadas por fecha descendente.
    ///
    /// Sin predicate fijo — el filtro de userId se aplica en `todasDelUsuario` para
    /// evitar el problema de captura de userId en el momento de inicialización de la view.
    @Query(sort: \Compra.fecha, order: .reverse) private var todas: [Compra]

    /// Estado de sesión para obtener el userId del usuario activo.
    @State private var session = SessionStore.shared

    /// Preferencias de moneda del usuario.
    @State private var store = UserScopedStorage.shared

    // MARK: - Filtrado reactivo por usuario

    /// Compras del usuario actual — reactivas al cambio de `session.currentUserID`.
    private var todasDelUsuario: [Compra] {
        let uid = session.currentUserID
        guard !uid.isEmpty else { return [] }
        return todas.filter { $0.userId == uid }
    }

    // MARK: - Estado de filtros

    /// Texto de búsqueda — filtra por supermercado y método de pago.
    @State private var busqueda = ""

    /// Filtro de supermercado seleccionado ("Todas" muestra todas las tiendas).
    @State private var filtroSuper = "Todas"

    /// Controla si se muestra la sheet de exportación.
    @State private var showExportSheet = false

    /// Ítems a compartir en `ActivitySheet` (URL del archivo exportado).
    @State private var shareItems: [Any] = []

    /// Controla si se muestra el `ActivitySheet` de compartir.
    @State private var showShareSheet = false

    /// Controla si se muestra la sheet de filtros avanzados.
    @State private var showFiltrosSheet = false

    // MARK: - Filtros avanzados

    @State private var fechaDesde: Date? = nil
    @State private var fechaHasta: Date? = nil
    @State private var montoMin   = ""
    @State private var montoMax   = ""
    @State private var orden      = OrdenHistorial.fechaReciente

    // MARK: - Propiedades computadas

    /// `true` si hay algún filtro avanzado activo (para mostrar el badge rojo).
    private var hayFiltrosActivos: Bool {
        fechaDesde != nil || fechaHasta != nil || !montoMin.isEmpty || !montoMax.isEmpty || orden != .fechaReciente
    }

    /// Lista de supermercados únicos en las compras del usuario (para los pills de filtro).
    private var supermercados: [String] {
        ["Todas"] + Array(Set(todasDelUsuario.map { $0.supermercado })).sorted()
    }

    /// Compras filtradas por todos los criterios activos.
    ///
    /// Se aplican en orden: supermercado → búsqueda → fecha desde → fecha hasta → monto min/max.
    /// Equivalente Android: query `WHERE` con múltiples condiciones en Room.
    private var filtradas: [Compra] {
        let cal = Calendar.current
        let minVal = Double(montoMin.replacingOccurrences(of: ",", with: "."))
        let maxVal = Double(montoMax.replacingOccurrences(of: ",", with: "."))

        return todasDelUsuario.filter { c in
            let matchSuper  = filtroSuper == "Todas" || c.supermercado == filtroSuper
            let matchSearch = busqueda.isEmpty ||
                c.supermercado.localizedCaseInsensitiveContains(busqueda) ||
                c.metodoPago.localizedCaseInsensitiveContains(busqueda)
            // Filtro de fecha: incluye todo el día (desde el inicio hasta el final)
            let matchDesde  = fechaDesde.map { c.fecha >= cal.startOfDay(for: $0) } ?? true
            let matchHasta  = fechaHasta.map { c.fecha < cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: $0))! } ?? true
            let matchMin    = minVal.map { c.total >= $0 } ?? true
            let matchMax    = maxVal.map { c.total <= $0 } ?? true
            return matchSuper && matchSearch && matchDesde && matchHasta && matchMin && matchMax
        }
    }

    private let groupCal = Calendar.current

    /// Compras filtradas y agrupadas por mes, con el orden seleccionado.
    ///
    /// `Dictionary(grouping:by:)` agrupa por "YYYY-MM" para ordenar cronológicamente.
    /// Equivalente Android: Kotlin `groupBy { fecha.format("yyyy-MM") }`.
    private var grupos: [(key: String, compras: [Compra])] {
        let sorted: [Compra] = filtradas.sorted {
            switch orden {
            case .fechaReciente: return $0.fecha > $1.fecha
            case .fechaAntigua:  return $0.fecha < $1.fecha
            case .mayorTotal:    return $0.total > $1.total
            case .menorTotal:    return $0.total < $1.total
            }
        }

        // Agrupar por "YYYY-MM" para ordenar los grupos cronológicamente
        let grouped = Dictionary(grouping: sorted) { compra -> String in
            let c = groupCal.dateComponents([.year, .month], from: compra.fecha)
            return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
        }

        let groupsSorted = grouped.sorted {
            switch orden {
            case .fechaReciente, .mayorTotal, .menorTotal: return $0.key > $1.key
            case .fechaAntigua: return $0.key < $1.key
            }
        }

        return groupsSorted.map { (key: $0.key, compras: $0.value.sorted {
            switch orden {
            case .fechaReciente: return $0.fecha > $1.fecha
            case .fechaAntigua:  return $0.fecha < $1.fecha
            case .mayorTotal:    return $0.total > $1.total
            case .menorTotal:    return $0.total < $1.total
            }
        }) }
    }

    private var statusBarHeight: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.top }
            .first ?? 50
    }

    /// Convierte la clave "YYYY-MM" al nombre del mes en español (ej: "Mayo 2026").
    private func nombreMes(_ key: String) -> String {
        if let compra = filtradas.first(where: { c in
            let comps = groupCal.dateComponents([.year, .month], from: c.fecha)
            return String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0) == key
        }) {
            return compra.fecha.formatted(.dateTime.month(.wide).year()).capitalized
        }
        return key
    }

    // MARK: - Vista principal

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // Header con título, botón de filtros y botón de exportar
                    HStack(alignment: .bottom) {
                        Text("Historial")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Color.saLabel)
                            .tracking(-1)
                        Spacer()

                        // Botón de filtros avanzados — con badge rojo si hay filtros activos
                        Button { showFiltrosSheet = true } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(hayFiltrosActivos ? .white : Color.saGreen)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        hayFiltrosActivos ? AnyShapeStyle(Color.saGreen) : AnyShapeStyle(Color.saCard),
                                        in: Circle()
                                    )
                                // Badge rojo indicando que hay filtros activos
                                if hayFiltrosActivos {
                                    Circle()
                                        .fill(Color.saDanger)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 2, y: -2)
                                }
                            }
                        }

                        // Botón de exportar (solo si hay compras)
                        if !todasDelUsuario.isEmpty {
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

                    // Campo de búsqueda
                    SAField(placeholder: "Buscar tienda, método...", text: $busqueda, icon: "magnifyingglass")
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    // Pills de filtros activos (con botón X para eliminar cada uno)
                    if hayFiltrosActivos {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                if let desde = fechaDesde {
                                    filtroActivoPill("Desde \(desde.formatted(date: .abbreviated, time: .omitted))") { fechaDesde = nil }
                                }
                                if let hasta = fechaHasta {
                                    filtroActivoPill("Hasta \(hasta.formatted(date: .abbreviated, time: .omitted))") { fechaHasta = nil }
                                }
                                if !montoMin.isEmpty { filtroActivoPill("Mín $\(montoMin)") { montoMin = "" } }
                                if !montoMax.isEmpty { filtroActivoPill("Máx $\(montoMax)") { montoMax = "" } }
                                if orden != .fechaReciente { filtroActivoPill(orden.rawValue) { orden = .fechaReciente } }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                        }
                    }

                    // Pills de filtro rápido por supermercado
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
                                            active ? AnyShapeStyle(Color.saGreen) : AnyShapeStyle(Color.saCard),
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

                    // Contador de resultados (visible solo cuando hay filtros activos)
                    if hayFiltrosActivos || filtroSuper != "Todas" || !busqueda.isEmpty {
                        Text("\(filtradas.count) resultado\(filtradas.count == 1 ? "" : "s")")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.saLabel3)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    }

                    // Lista de grupos por mes o estado vacío
                    VStack(spacing: 20) {
                        if todasDelUsuario.isEmpty {
                            // Estado vacío: no hay compras registradas
                            ContentUnavailableView {
                                Label("Sin compras", systemImage: "cart")
                            } description: {
                                Text("Aún no registraste ninguna compra.\nUsá el **+** en Inicio para comenzar.")
                            }
                            .padding(.top, 20)
                        } else if grupos.isEmpty {
                            // Sin resultados para los filtros activos
                            ContentUnavailableView {
                                Label("Sin resultados", systemImage: "line.3.horizontal.decrease.circle")
                            } description: {
                                Text("Ninguna compra coincide con los filtros aplicados.")
                            }
                            .padding(.top, 20)
                        } else {
                            // Grupos de compras por mes
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
        // Sheet de filtros avanzados
        .sheet(isPresented: $showFiltrosSheet) {
            FiltrosAvanzadosSheet(
                fechaDesde: $fechaDesde,
                fechaHasta: $fechaHasta,
                montoMin: $montoMin,
                montoMax: $montoMax,
                orden: $orden
            )
        }
        // Sheet de exportación (CSV/PDF)
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(compras: todasDelUsuario) { url in
                shareItems = [url]
                // Pequeño delay para que el dismiss del ExportSheet termine antes del share
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { showShareSheet = true }
            }
        }
        // ActivitySheet (UIActivityViewController) para compartir el archivo exportado
        .sheet(isPresented: $showShareSheet) { ActivitySheet(items: shareItems) }
    }

    // MARK: - Subvistas

    /// Pill de filtro activo con botón X para eliminarlo.
    @ViewBuilder
    private func filtroActivoPill(_ label: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(Color.saGreen)
            Button(action: onRemove) {
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.saGreen)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Color.saGreen.opacity(0.12), in: Capsule())
    }

    /// Grupo de compras de un mes con encabezado de total y lista de filas.
    @ViewBuilder
    private func mesGroup(nombre: String, compras: [Compra]) -> some View {
        let total = compras.reduce(0) { $0 + $1.total }
        VStack(alignment: .leading, spacing: 0) {
            // Encabezado: nombre del mes y total de ese mes
            HStack {
                Text(nombre.uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.saLabel3)
                    .tracking(0.2)
                Spacer()
                Text(store.convert(total).formatted(.currency(code: store.currencyCode)))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.saLabel3)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 10)

            // Lista de compras del mes en una SACard
            SACard(padding: 0) {
                ForEach(Array(compras.enumerated()), id: \.element.id) { idx, compra in
                    NavigationLink { DetalleCompraView(compra: compra) } label: {
                        historialRow(compra: compra, isLast: idx == compras.count - 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Fila de una compra en el historial con avatar del supermercado, fecha y total.
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
            Text(store.convert(compra.total).formatted(.currency(code: store.currencyCode)))
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

// MARK: - Sheet de filtros avanzados

/// Sheet de filtros avanzados para el historial: período, monto y orden.
///
/// Usa estado local que solo se aplica al historial al tocar "Aplicar filtros".
/// Equivalente Android: un `BottomSheetDialogFragment` con controles de filtro.
struct FiltrosAvanzadosSheet: View {
    @Binding var fechaDesde: Date?
    @Binding var fechaHasta: Date?
    @Binding var montoMin: String
    @Binding var montoMax: String
    @Binding var orden: OrdenHistorial

    @Environment(\.dismiss) private var dismiss

    // Estado local (no se aplica hasta que el usuario toca "Aplicar filtros")
    @State private var localDesde: Date  = Calendar.current.date(byAdding: .month, value: -1, to: .now)!
    @State private var localHasta: Date  = .now
    @State private var useDesde          = false
    @State private var useHasta          = false
    @State private var localMin          = ""
    @State private var localMax          = ""
    @State private var localOrden        = OrdenHistorial.fechaReciente

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Indicador de drag de la sheet
                Capsule().fill(Color.saSep).frame(width: 36, height: 4).frame(maxWidth: .infinity).padding(.top, 12).padding(.bottom, 20)

                HStack {
                    Text("Filtros avanzados").font(.system(size: 22, weight: .bold)).foregroundStyle(Color.saLabel).tracking(-0.5)
                    Spacer()
                    // Botón para limpiar todos los filtros a sus valores por defecto
                    Button("Limpiar") {
                        useDesde = false; useHasta = false; localMin = ""; localMax = ""; localOrden = .fechaReciente
                    }
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(Color.saGreen)
                }
                .padding(.horizontal, 20).padding(.bottom, 24)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Sección: filtro por período con toggles de fecha
                        filtroSeccion(titulo: "Período", icono: "calendar") {
                            VStack(spacing: 0) {
                                toggleDateRow(label: "Desde", enabled: $useDesde, date: $localDesde)
                                Rectangle().fill(Color.saSep).frame(height: 0.5).padding(.leading, 16)
                                toggleDateRow(label: "Hasta", enabled: $useHasta, date: $localHasta)
                            }
                        }
                        // Sección: filtro por rango de monto
                        filtroSeccion(titulo: "Monto (ARS)", icono: "dollarsign.circle") {
                            VStack(spacing: 0) {
                                montoRow(label: "Mínimo", placeholder: "0", text: $localMin)
                                Rectangle().fill(Color.saSep).frame(height: 0.5).padding(.leading, 16)
                                montoRow(label: "Máximo", placeholder: "Sin límite", text: $localMax)
                            }
                        }
                        // Sección: opciones de ordenamiento
                        filtroSeccion(titulo: "Ordenar por", icono: "arrow.up.arrow.down") {
                            VStack(spacing: 0) {
                                ForEach(Array(OrdenHistorial.allCases.enumerated()), id: \.element) { idx, op in
                                    let isLast = idx == OrdenHistorial.allCases.count - 1
                                    Button { localOrden = op } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: op.icon).font(.system(size: 16)).foregroundStyle(localOrden == op ? Color.saGreen : Color.saLabel3).frame(width: 24)
                                            Text(op.rawValue).font(.system(size: 15, weight: localOrden == op ? .semibold : .regular)).foregroundStyle(localOrden == op ? Color.saLabel : Color.saLabel2)
                                            Spacer()
                                            if localOrden == op { Image(systemName: "checkmark").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.saGreen) }
                                        }
                                        .padding(.horizontal, 16).padding(.vertical, 13).contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    if !isLast { Rectangle().fill(Color.saSep).frame(height: 0.5).padding(.leading, 16) }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 16)
                }

                // Botón de aplicar — copia los valores locales a los bindings del padre
                SAButton(title: "Aplicar filtros") {
                    fechaDesde = useDesde ? localDesde : nil
                    fechaHasta = useHasta ? localHasta : nil
                    montoMin = localMin; montoMax = localMax; orden = localOrden
                    dismiss()
                }
                .padding(.horizontal, 20).padding(.bottom, 28)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
        // Inicializar estado local con los valores actuales del padre al abrir
        .onAppear {
            localDesde = fechaDesde ?? Calendar.current.date(byAdding: .month, value: -1, to: .now)!
            localHasta = fechaHasta ?? .now
            useDesde = fechaDesde != nil; useHasta = fechaHasta != nil
            localMin = montoMin; localMax = montoMax; localOrden = orden
        }
    }

    /// Sección con título, ícono y contenido genérico.
    @ViewBuilder
    private func filtroSeccion<Content: View>(titulo: String, icono: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icono).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.saGreen)
                Text(titulo.uppercased()).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.saLabel3).tracking(0.4)
            }
            .padding(.horizontal, 4)
            SACard(padding: 0) { content() }
        }
    }

    /// Fila con toggle para habilitar/deshabilitar el filtro de fecha.
    @ViewBuilder
    private func toggleDateRow(label: String, enabled: Binding<Bool>, date: Binding<Date>) -> some View {
        HStack {
            Toggle(isOn: enabled) {
                Text(label).font(.system(size: 15)).foregroundStyle(enabled.wrappedValue ? Color.saLabel : Color.saLabel3)
            }
            .toggleStyle(SwitchToggleStyle(tint: Color.saGreen)).frame(maxWidth: 130)
            Spacer()
            if enabled.wrappedValue { DatePicker("", selection: date, displayedComponents: .date).labelsHidden().tint(Color.saGreen) }
            else { Text("—").font(.system(size: 15)).foregroundStyle(Color.saLabel4) }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    /// Fila para ingresar un monto mínimo o máximo.
    @ViewBuilder
    private func montoRow(label: String, placeholder: String, text: Binding<String>) -> some View {
        HStack {
            Text(label).font(.system(size: 15)).foregroundStyle(Color.saLabel)
            Spacer()
            TextField(placeholder, text: text).keyboardType(.decimalPad).multilineTextAlignment(.trailing).font(.system(size: 15, weight: .medium)).foregroundStyle(Color.saLabel).frame(width: 130)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
    }
}

// MARK: - Sheet de exportación

/// Sheet para elegir el formato de exportación del historial (CSV o PDF).
///
/// Llama a `ExportService` para generar el archivo y retorna la URL via closure.
/// Equivalente Android: un `BottomSheetDialogFragment` con opciones de formato.
struct ExportSheet: View {
    /// Todas las compras del usuario para exportar.
    let compras: [Compra]

    /// Closure que recibe la URL del archivo generado para compartir.
    let onExport: (URL) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var store = UserScopedStorage.shared

    private var totalProductos: Int   { compras.reduce(0) { $0 + $1.productos.count } }
    private var totalGastado: Double  { compras.reduce(0) { $0 + $1.total } }

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                // Indicador de drag
                Capsule().fill(Color.saSep).frame(width: 36, height: 4).frame(maxWidth: .infinity).padding(.top, 12).padding(.bottom, 20)
                // Título y subtítulo
                VStack(alignment: .leading, spacing: 4) {
                    Text("Exportar historial").font(.system(size: 22, weight: .bold)).foregroundStyle(Color.saLabel).tracking(-0.5)
                    Text("Elegí el formato para exportar tus compras").font(.system(size: 14)).foregroundStyle(Color.saLabel3)
                }
                .padding(.horizontal, 20).padding(.bottom, 20)
                // Card con estadísticas del historial a exportar
                SACard(padding: 14) {
                    HStack(spacing: 0) {
                        statCell(icon: "cart.fill", color: Color.saGreen, value: "\(compras.count)", label: "Compras")
                        Rectangle().fill(Color.saSep).frame(width: 0.5, height: 36)
                        statCell(icon: "bag.fill", color: Color(hex: "#F97316"), value: "\(totalProductos)", label: "Productos")
                        Rectangle().fill(Color.saSep).frame(width: 0.5, height: 36)
                        statCell(icon: "dollarsign.circle.fill", color: Color(hex: "#8B5CF6"), value: store.convert(totalGastado).formatted(.currency(code: store.currencyCode)), label: "Total")
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 16)
                // Botones de formato de exportación
                VStack(spacing: 10) {
                    // Exportar como CSV — compatible con Excel y Google Sheets
                    exportRow(icon: "tablecells.fill", iconColor: Color.saGreen, title: "Exportar como CSV", subtitle: "Compatible con Excel y Google Sheets") {
                        if let url = ExportService.shared.generarCSV(compras: compras) { dismiss(); onExport(url) }
                    }
                    // Exportar como PDF — documento formateado para imprimir
                    exportRow(icon: "doc.richtext.fill", iconColor: Color(hex: "#F97316"), title: "Exportar como PDF", subtitle: "Documento formateado listo para imprimir") {
                        if let url = ExportService.shared.generarPDF(compras: compras) { dismiss(); onExport(url) }
                    }
                }
                .padding(.horizontal, 20)
                Spacer()
            }
        }
        .presentationDetents([.height(370)]).presentationDragIndicator(.hidden).presentationCornerRadius(28)
    }

    /// Celda de estadística con ícono, valor y etiqueta.
    @ViewBuilder private func statCell(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 17)).foregroundStyle(color)
            Text(value).font(.system(size: 13, weight: .bold)).foregroundStyle(Color.saLabel).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.system(size: 11)).foregroundStyle(Color.saLabel3)
        }.frame(maxWidth: .infinity)
    }

    /// Fila de opción de exportación con ícono, título y subtítulo.
    @ViewBuilder private func exportRow(icon: String, iconColor: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SACard(padding: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(iconColor.opacity(0.12)).frame(width: 48, height: 48)
                        Image(systemName: icon).font(.system(size: 22)).foregroundStyle(iconColor)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.saLabel)
                        Text(subtitle).font(.system(size: 13)).foregroundStyle(Color.saLabel3)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.saLabel4)
                }.padding(16)
            }
        }.buttonStyle(.plain)
    }
}
