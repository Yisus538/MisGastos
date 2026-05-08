// =============================================================================
// ComparativaView.swift — Comparativa de precios entre supermercados
// =============================================================================
// Rol en la app:
//   Analiza los productos registrados en todas las compras y agrupa aquellos con
//   el mismo nombre que aparecen en 2 o más supermercados distintos. Para cada
//   producto, muestra el precio en cada tienda, indicando el más barato y el más
//   caro, y calcula el ahorro potencial.
//   Se navega desde el Tab "Comparar" en `MainTabView`.
//
// Equivalente Android:
//   Un `Fragment` con `RecyclerView` que consume un `StateFlow<List<ComparativaItem>>`
//   del ViewModel. El procesamiento de datos equivale a queries `GROUP BY producto_nombre`
//   con `JOIN` a `compras` en Room, o procesamiento en memoria con `.groupBy { }`.
//
// Estrategia de agrupación:
//   1. Iterar todas las compras del usuario.
//   2. Para cada producto, agregar su precio y supermercado al mapa `[nombre: [entradas]]`.
//   3. Filtrar solo productos que aparecen en 2+ supermercados distintos.
//   4. Para cada supermercado, tomar el precio más reciente (puede haber variaciones).
//   5. Ordenar los precios de menor a mayor y calcular el ahorro.
//
// Datos locales vs. tiempo real:
//   Los datos provienen de SwiftData local (compras registradas por el usuario).
//   No es un comparador de precios en tiempo real — muestra los precios que el
//   usuario pagó en sus propias compras, lo que es más relevante para su contexto.
// =============================================================================

import SwiftUI
import SwiftData

/// Pantalla de comparativa de precios entre supermercados.
///
/// Equivalente Android: `ComparativaFragment` con `RecyclerView` de cards por producto.
struct ComparativaView: View {

    // MARK: - Fuentes de datos

    /// Todas las compras de SwiftData — filtro de userId se aplica en `compras`.
    @Query(sort: \Compra.fecha, order: .reverse) private var todasCompras: [Compra]

    /// Estado de sesión para obtener el userId del usuario activo.
    @State private var session = SessionStore.shared

    /// Preferencias de moneda para convertir y formatear precios.
    @State private var store = UserScopedStorage.shared

    // MARK: - Estado de UI

    /// Texto de búsqueda para filtrar productos por nombre.
    @State private var busqueda = ""

    // MARK: - Compras del usuario

    /// Compras del usuario activo — filtradas reactivamente.
    private var compras: [Compra] {
        let uid = session.currentUserID
        guard !uid.isEmpty else { return [] }
        return todasCompras.filter { $0.userId == uid }
    }

    // MARK: - Tipos de datos internos

    /// Precio de un producto en un supermercado específico.
    private struct PrecioEnSuper: Identifiable {
        let id = UUID()
        let supermercado: String
        let precio: Double
        let fecha: Date    // Fecha de la compra (para "precio más reciente")
    }

    /// Item de comparativa: un producto con sus precios en distintos supermercados.
    private struct ItemComparativa: Identifiable {
        let id = UUID()
        let nombre: String
        let precios: [PrecioEnSuper]  // Ordenados de menor a mayor precio

        var minPrecio: Double      { precios.first?.precio ?? 0 }
        var maxPrecio: Double      { precios.last?.precio ?? 0 }
        var ahorro: Double         { maxPrecio - minPrecio }          // Diferencia entre más caro y más barato
        var superMasBarato: String { precios.first?.supermercado ?? "" }
    }

    // MARK: - Datos computados

    /// Lista de comparativas calculadas desde las compras del usuario.
    ///
    /// Algoritmo:
    /// 1. Construir mapa `[nombreProducto: [(super, precio, fecha)]]`.
    /// 2. Filtrar solo productos en 2+ supermercados distintos.
    /// 3. Para cada supermercado, tomar el registro más reciente.
    /// 4. Ordenar por mayor ahorro potencial.
    private var comparativas: [ItemComparativa] {
        // Mapa: nombre normalizado → lista de (supermercado, precio, fecha)
        var map: [String: [(super: String, precio: Double, fecha: Date)]] = [:]
        for compra in compras {
            for producto in compra.productos {
                let key = producto.nombre.lowercased().trimmingCharacters(in: .whitespaces)
                map[key, default: []].append((compra.supermercado, producto.precio, compra.fecha))
            }
        }

        return map.compactMap { nombre, entradas -> ItemComparativa? in
            // Solo incluir si aparece en 2 o más supermercados distintos
            guard Set(entradas.map(\.super)).count >= 2 else { return nil }

            // Tomar el último precio registrado por supermercado (precio más reciente)
            var latest: [String: (super: String, precio: Double, fecha: Date)] = [:]
            for e in entradas.sorted(by: { $0.fecha < $1.fecha }) { latest[e.super] = e }

            // Convertir a PrecioEnSuper y ordenar de menor a mayor precio
            let precios = latest.values
                .map { PrecioEnSuper(supermercado: $0.super, precio: $0.precio, fecha: $0.fecha) }
                .sorted { $0.precio < $1.precio }
            return ItemComparativa(nombre: nombre.capitalized, precios: precios)
        }
        .sorted { $0.ahorro > $1.ahorro }   // Los productos con más ahorro potencial primero
    }

    /// Comparativas filtradas por búsqueda de texto.
    private var filtradas: [ItemComparativa] {
        busqueda.isEmpty ? comparativas
            : comparativas.filter { $0.nombre.localizedCaseInsensitiveContains(busqueda) }
    }

    private var statusBarHeight: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.top }
            .first ?? 50
    }

    // MARK: - Vista principal

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Encabezado de la pantalla
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

                // Barra de búsqueda por nombre de producto
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

                // Contenido principal según el estado de los datos
                if comparativas.isEmpty {
                    // Estado vacío: no hay suficientes datos para comparar
                    ContentUnavailableView {
                        Label("Sin comparativas", systemImage: "scalemass")
                    } description: {
                        Text("Registrá el mismo producto en 2 o más supermercados para ver la comparativa de precios.")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filtradas.isEmpty {
                    // Sin resultados para la búsqueda actual
                    ContentUnavailableView.search(text: busqueda)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Card de estadísticas globales (solo cuando no hay búsqueda activa)
                            if busqueda.isEmpty {
                                statsHeader
                                    .padding(.bottom, 16)
                            }

                            // Lista de cards de comparativa por producto
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

    // MARK: - Card de estadísticas globales

    /// Muestra el total de productos comparados, tiendas únicas y mayor ahorro.
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
                    value: store.convert(comparativas.map(\.ahorro).max() ?? 0).formatted(.currency(code: store.currencyCode)),
                    label: "Mayor\nahorro"
                )
            }
        }
    }

    /// Celda de estadística individual con ícono, valor y etiqueta multilínea.
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

    // MARK: - Card de comparativa por producto

    /// Card que muestra los precios de un producto en cada supermercado.
    ///
    /// - Header: nombre del producto + badge de ahorro.
    /// - Filas: precio por supermercado, ordenados de más barato a más caro.
    ///   El más barato se marca en verde ("MÁS BARATO"), el más caro en rojo ("MÁS CARO").
    /// - Footer: recomendación de compra con el ahorro calculado.
    @ViewBuilder
    private func comparativaCard(_ item: ItemComparativa) -> some View {
        SACard(padding: 0) {
            VStack(spacing: 0) {
                // Encabezado: nombre del producto y badge de ahorro potencial
                HStack {
                    Text(item.nombre)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.saLabel)
                        .tracking(-0.3)
                    Spacer()
                    // Badge verde con el ahorro en moneda
                    if item.ahorro > 0 {
                        Text("−" + store.convert(item.ahorro).formatted(.currency(code: store.currencyCode)))
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

                // Filas de precios por supermercado (ordenados de más barato a más caro)
                ForEach(Array(item.precios.enumerated()), id: \.element.id) { idx, precio in
                    let isCheapest = precio.precio == item.minPrecio
                    let isMostExp  = precio.precio == item.maxPrecio && item.ahorro > 0

                    HStack(spacing: 12) {
                        // Avatar circular del supermercado
                        SAStoreAvatar(name: precio.supermercado, size: 36)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(precio.supermercado)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.saLabel)
                            // Fecha de la última compra en este supermercado
                            Text(precio.fecha.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 11))
                                .foregroundStyle(Color.saLabel4)
                        }

                        Spacer()

                        // Badge de "MÁS BARATO" / "MÁS CARO"
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

                        // Precio en la moneda del usuario — color semáforo
                        Text(store.convert(precio.precio).formatted(.currency(code: store.currencyCode)))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(
                                isCheapest ? Color.saGreen     // Verde: más barato
                                : isMostExp ? Color.saDanger    // Rojo: más caro
                                : Color.saLabel                 // Neutral: precio intermedio
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

                // Footer: recomendación con el supermercado más barato y el ahorro
                if item.ahorro > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.saGreen)
                        Text("Comprá en **\(item.superMasBarato)** y ahorrás \(store.convert(item.ahorro).formatted(.currency(code: store.currencyCode)))")
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
