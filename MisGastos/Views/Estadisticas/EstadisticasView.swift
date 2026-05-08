// =============================================================================
// EstadisticasView.swift — Pantalla de estadísticas con Swift Charts
// =============================================================================
// Rol en la app:
//   Muestra al usuario un análisis visual de sus gastos en supermercados a lo
//   largo del tiempo. Incluye:
//     - Gráfico de barras o de líneas (toggle) con gasto mensual en el rango elegido.
//     - Comparación vs. mes anterior (diferencia absoluta y porcentual).
//     - Grilla 2×2 de métricas del mes actual (compras, tiendas, ticket promedio, mayor compra).
//     - Gráfico de dona (SectorMark) por distribución de gasto entre supermercados.
//     - Ranking horizontal (BarMark) de los 5 productos más comprados en el rango.
//   Se navega desde el Tab "Estadísticas" en `MainTabView`.
//
// Equivalente Android:
//   Un `Fragment` con `MPAndroidChart` (BarChart, LineChart, PieChart) consumiendo
//   un `StateFlow<EstadisticasUiState>` del ViewModel. El procesamiento de datos
//   equivale a queries con GROUP BY en Room o agregaciones en memoria en el
//   ViewModel. En iOS, toda la lógica vive en computed properties de la View,
//   ya que SwiftData con `@Query` dispara actualizaciones reactivas automáticamente.
//
// Framework de gráficos — Swift Charts (iOS 16+):
//   `import Charts` habilita el DSL declarativo de gráficos de Apple.
//   Los tipos de marcas son: `BarMark`, `LineMark`, `AreaMark`, `SectorMark`,
//   `PointMark`, `RuleMark`, `RectangleMark`. Equivalente a MPAndroidChart en Android.
//
// Patrón de `@Query` con `#Predicate` en el `init`:
//   A diferencia de otras vistas que usan `@Query` sin filtro y filtran en memoria,
//   `EstadisticasView` construye la query con un `#Predicate` en el inicializador.
//   Esto permite filtrar directamente en SQLite (SwiftData) solo las compras del
//   usuario activo, lo cual es más eficiente para colecciones grandes.
//   La razón de hacerlo en `init` es que el userId proviene de un singleton
//   (`SessionStore.shared`) disponible en ese momento, no de un `@Environment`.
//   Equivalente Android: query Room con `WHERE userId = :uid` en lugar de
//   cargar todos los registros y filtrar en el ViewModel.
// =============================================================================

import SwiftUI
import SwiftData
import Charts   // Framework nativo de Apple para gráficos declarativos (iOS 16+)

/// Pantalla de estadísticas visuales de gastos en supermercados.
///
/// Equivalente Android: `EstadisticasFragment` con `ViewPager2` o `ScrollView` +
/// `MPAndroidChart` y un `EstadisticasViewModel` con `StateFlow`.
struct EstadisticasView: View {

    // MARK: - Fuentes de datos

    /// Compras del usuario — filtradas por `userId` directamente en SQLite con `#Predicate`.
    ///
    /// Equivalente Android: `@Query("SELECT * FROM compras WHERE userId = :uid ORDER BY fecha DESC")`
    /// en Room DAO, o un `Flow<List<Compra>>` del DAO observado en el ViewModel.
    @Query private var compras: [Compra]

    // MARK: - Estado de UI

    /// Rango temporal seleccionado para el gráfico: "3m" (3 meses), "6m" (6 meses), "1y" (1 año).
    @State private var rango = "6m"

    /// Tipo de gráfico mensual: "bar" (barras) o "line" (línea + área).
    @State private var chartType = "bar"

    /// Preferencias de moneda para convertir y formatear precios.
    @State private var store = UserScopedStorage.shared

    // MARK: - Calendario

    /// Calendario del sistema — se reutiliza en todos los cálculos para evitar instanciar múltiples veces.
    private let cal = Calendar.current

    // MARK: - Inicializador con predicado dinámico

    /// Inicializador que construye la `@Query` con un `#Predicate` basado en el userId actual.
    ///
    /// Por qué se hace en `init` y no en la declaración de `@Query`:
    ///   - `#Predicate` requiere valores conocidos en tiempo de compilación o capturados en clausura.
    ///   - El userId proviene de `SessionStore.shared`, accesible en el `init` pero no disponible
    ///     como propiedad de instancia de la View en el momento de la declaración de `@Query`.
    ///   - Se usa `_compras = Query(filter:sort:order:)` con el prefijo `_` para acceder al
    ///     storage subyacente del property wrapper, patrón necesario para inicialización custom.
    ///
    /// Equivalente Android: el DAO recibe el `userId` como parámetro del método de consulta.
    init() {
        let uid = SessionStore.shared.currentUserID
        // Construir @Query con predicado: solo compras del usuario activo
        // Equivalente SQL: SELECT * FROM compras WHERE userId = uid ORDER BY fecha DESC
        _compras = Query(
            filter: #Predicate<Compra> { compra in compra.userId == uid },
            sort: \Compra.fecha,
            order: .reverse
        )
    }

    // MARK: - Datos filtrados por rango

    /// Compras dentro del rango temporal seleccionado (3m / 6m / 1y).
    ///
    /// Equivalente Android: el ViewModel hace una nueva consulta o aplica `.filter { }` al Flow.
    private var comprasRango: [Compra] {
        let meses: Int
        switch rango {
        case "3m": meses = 3
        case "1y": meses = 12
        default:   meses = 6   // "6m" es el default
        }
        // Calcular fecha de inicio restando meses al día de hoy
        guard let from = cal.date(byAdding: .month, value: -meses, to: Date()) else { return compras }
        return compras.filter { $0.fecha >= from }
    }

    // MARK: - Compras del mes actual y anterior

    /// Compras realizadas en el mes y año calendario actual.
    private var comprasEsteMes: [Compra] {
        compras.filter { cal.isDate($0.fecha, equalTo: Date(), toGranularity: .month) }
    }

    /// Compras realizadas el mes calendario anterior.
    private var comprasMesAnterior: [Compra] {
        guard let prev = cal.date(byAdding: .month, value: -1, to: Date()) else { return [] }
        return compras.filter { cal.isDate($0.fecha, equalTo: prev, toGranularity: .month) }
    }

    // MARK: - Métricas de comparación mensual

    /// Total gastado en el mes actual (suma de `total` de cada compra).
    private var totalEsteMes: Double { comprasEsteMes.reduce(0) { $0 + $1.total } }

    /// Total gastado el mes anterior.
    private var totalMesAnterior: Double { comprasMesAnterior.reduce(0) { $0 + $1.total } }

    /// Variación porcentual entre este mes y el anterior.
    /// Negativo = gastó menos (positivo para las finanzas). Cero si no hay mes anterior.
    private var delta: Double {
        guard totalMesAnterior > 0 else { return 0 }
        return (totalEsteMes - totalMesAnterior) / totalMesAnterior * 100
    }

    /// Diferencia absoluta en moneda entre este mes y el anterior.
    /// Negativo = gastó menos, positivo = gastó más.
    private var diff: Double { totalEsteMes - totalMesAnterior }

    // MARK: - Datos para gráficos

    /// Gasto total agrupado por mes dentro del rango seleccionado.
    ///
    /// Devuelve tuplas `(mes: "YYYY-MM", label: "Ene", total: Double)` ordenadas cronológicamente.
    /// El campo `mes` es la clave de ordenación; `label` es la etiqueta abreviada para el eje X.
    ///
    /// Equivalente Android: `groupBy { compra -> String }` en Kotlin sobre una lista, luego
    /// `.sumOf { it.total }` para agregar. En Room se haría con un DAO que retorna `List<GastoMensualDTO>`.
    private var gastoMensual: [(mes: String, label: String, total: Double)] {
        // Agrupar compras por "YYYY-MM" usando Calendar para extraer año y mes
        let grouped = Dictionary(grouping: comprasRango) { compra -> String in
            let c = cal.dateComponents([.year, .month], from: compra.fecha)
            return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
        }
        return grouped.map { key, cs in
            // Obtener la etiqueta abreviada del mes (ej: "Ene", "Feb") de la primera compra
            let label = cs.first.map {
                $0.fecha.formatted(.dateTime.month(.abbreviated))
            } ?? key
            return (mes: key, label: label, total: cs.reduce(0) { $0 + $1.total })
        }
        .sorted { $0.mes < $1.mes }   // Ordenar cronológicamente por "YYYY-MM"
    }

    /// Gasto total agrupado por supermercado dentro del rango, ordenado de mayor a menor.
    ///
    /// Usado en el gráfico de dona (SectorMark). Equivalente Android: `groupBy { it.supermercado }`.
    private var gastosPorSuper: [(nombre: String, total: Double)] {
        Dictionary(grouping: comprasRango, by: { $0.supermercado })
            .map { (nombre: $0.key, total: $0.value.reduce(0) { $0 + $1.total }) }
            .sorted { $0.total > $1.total }   // Mayor gasto primero
    }

    // MARK: - Métricas del mes actual

    /// Promedio de gasto por compra en el mes actual.
    private var ticketPromedio: Double {
        guard !comprasEsteMes.isEmpty else { return 0 }
        return totalEsteMes / Double(comprasEsteMes.count)
    }

    /// Compra de mayor monto realizada en el mes actual.
    private var mayorCompra: Double {
        comprasEsteMes.map { $0.total }.max() ?? 0
    }

    /// Top 5 productos más comprados (por cantidad de apariciones) en el rango seleccionado.
    ///
    /// Equivalente Android: `flatMap { it.productos }` + `groupingBy { it.nombre }` + `counting()`.
    private var productosMasComprados: [(nombre: String, cantidad: Int)] {
        // Aplanar todos los productos de todas las compras del rango
        let todos = comprasRango.flatMap { $0.productos }
        return Dictionary(grouping: todos, by: { $0.nombre })
            .map { (nombre: $0.key, cantidad: $0.value.count) }
            .sorted { $0.cantidad > $1.cantidad }   // Más comprado primero
            .prefix(5)   // Solo top 5
            .map { $0 }  // Convertir de ArraySlice a Array
    }

    // MARK: - Altura de la barra de estado

    /// Altura de la safe area superior para posicionar el header correctamente.
    private var statusBarHeight: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.top }
            .first ?? 50
    }

    // MARK: - Vista principal

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // MARK: Encabezado de pantalla
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

                    // MARK: Selector de rango temporal (3m / 6m / 1y)
                    // Segmented control custom — equivalente a `TabLayout` o `RadioGroup` en Android.
                    // Cuando cambia `rango`, SwiftUI re-evalúa `comprasRango` y todas las computed
                    // properties que dependen de él, lo que actualiza los gráficos reactivamente.
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
                                    // Fondo verde para el elemento activo, transparente para los demás
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

                        // MARK: Card de gráfico de tendencia mensual
                        SACard {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Tendencia mensual")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.saLabel3)
                                    // Total gastado en el mes actual con conversión de moneda
                                    Text(store.convert(totalEsteMes).formatted(.currency(code: store.currencyCode)))
                                        .font(.system(size: 26, weight: .bold))
                                        .foregroundStyle(Color.saLabel)
                                        .tracking(-0.8)
                                }
                                Spacer()

                                // Toggle bar/line: botones de ícono con fondo activo/inactivo
                                // Equivalente Android: `MaterialButtonToggleGroup` o dos `ImageButton`
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
                                // Estado vacío: no hay compras en el rango seleccionado
                                Text("Sin datos para el período")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.saLabel3)
                                    .frame(height: 150)
                                    .frame(maxWidth: .infinity)

                            } else if chartType == "bar" {
                                // MARK: Gráfico de barras — BarMark
                                // Equivalente Android: `BarChart` de MPAndroidChart con un `BarDataSet`.
                                // `BarMark(x:y:)` define cada barra. `.foregroundStyle(LinearGradient)`
                                // aplica el gradiente verde brand a todas las barras.
                                Chart(gastoMensual, id: \.mes) { item in
                                    BarMark(x: .value("Mes", item.label), y: .value("Total", item.total))
                                        .foregroundStyle(LinearGradient.saGreen)  // Gradiente verde brand
                                        .cornerRadius(6)
                                }
                                .frame(height: 150)
                                // Personalización de ejes: solo mostrar líneas de grilla en Y,
                                // y etiquetas pequeñas en X
                                .chartYAxis { AxisMarks { _ in AxisGridLine().foregroundStyle(Color.saSep) } }
                                .chartXAxis { AxisMarks { v in AxisValueLabel().font(.system(size: 10)) } }

                            } else {
                                // MARK: Gráfico de líneas + área — LineMark + AreaMark
                                // Equivalente Android: `LineChart` de MPAndroidChart con `FillFormatter`.
                                // `LineMark` dibuja la línea; `AreaMark` rellena el área debajo.
                                // `.interpolationMethod(.catmullRom)` suaviza la curva usando splines
                                // de Catmull-Rom, que pasan por los puntos exactos pero con curvas
                                // suaves entre ellos. Equivalente a `CubicLineDataSet` en MPAndroidChart.
                                Chart(gastoMensual, id: \.mes) { item in
                                    LineMark(x: .value("Mes", item.label), y: .value("Total", item.total))
                                        .foregroundStyle(Color.saGreen)
                                        .interpolationMethod(.catmullRom)  // Curva suave de Catmull-Rom
                                    AreaMark(x: .value("Mes", item.label), y: .value("Total", item.total))
                                        .foregroundStyle(Color.saGreen.opacity(0.12))  // Relleno semitransparente
                                        .interpolationMethod(.catmullRom)
                                }
                                .frame(height: 150)
                                .chartYAxis { AxisMarks { _ in AxisGridLine().foregroundStyle(Color.saSep) } }
                                .chartXAxis { AxisMarks { v in AxisValueLabel().font(.system(size: 10)) } }
                            }
                        }

                        // MARK: Sección "VS. MES ANTERIOR"
                        VStack(alignment: .leading, spacing: 10) {
                            Text("VS. MES ANTERIOR")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.saLabel3)
                                .tracking(0.2)
                                .padding(.horizontal, 4)

                            SACard {
                                // Ícono de flecha semáforo: verde (abajo = gastó menos) o rojo (arriba = gastó más)
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
                                        // Diferencia absoluta con signo explícito (+ o -)
                                        Text((diff >= 0 ? "+" : "") + store.convert(diff).formatted(.currency(code: store.currencyCode)))
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundStyle(delta < 0 ? Color.saGreen : Color.saDanger)
                                            .tracking(-0.6)
                                        Text(String(format: "%.1f%% de variación", delta))
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.saLabel3)
                                    }
                                }

                                // MARK: Barras de comparación mes anterior vs. este mes
                                // Normalización: el mes con mayor gasto ocupa el 100% del ancho.
                                // Equivalente a un `ProgressBar` horizontal en Android donde
                                // el máximo es el mayor de los dos valores.
                                let maxVal = max(totalEsteMes, totalMesAnterior, 1)  // Mínimo 1 para evitar división por cero
                                HStack(spacing: 12) {
                                    monthBar(label: "Mes anterior", value: totalMesAnterior, max: maxVal, color: Color.saLabel4)
                                    monthBar(label: "Este mes", value: totalEsteMes, max: maxVal, color: Color.saGreen)
                                }
                                .padding(.top, 20)
                            }
                        }

                        // MARK: Sección "TU MES" — Grid de métricas 2×2
                        VStack(alignment: .leading, spacing: 10) {
                            Text("TU MES")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.saLabel3)
                                .tracking(0.2)
                                .padding(.horizontal, 4)

                            // `LazyVGrid` con 2 columnas flexibles — equivalente a `GridLayoutManager(2)`
                            // en Android RecyclerView o a un `GridView` con 2 columnas
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                insightCard(icon: "receipt", label: "Compras", value: "\(comprasEsteMes.count)", bg: Color(hex: "#3B82F6"))
                                insightCard(icon: "storefront", label: "Tiendas", value: "\(Set(comprasEsteMes.map { $0.supermercado }).count)", bg: Color(hex: "#F97316"))
                                insightCard(icon: "tag.fill", label: "Ticket promedio", value: store.convert(ticketPromedio).formatted(.currency(code: store.currencyCode)), bg: Color.saGreen, small: true)
                                insightCard(icon: "bookmark.fill", label: "Mayor compra", value: store.convert(mayorCompra).formatted(.currency(code: store.currencyCode)), bg: Color(hex: "#A855F7"), small: true)
                            }
                        }

                        // MARK: Gráfico de dona — SectorMark
                        // Solo se muestra si hay compras en el rango
                        if !gastosPorSuper.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("DISTRIBUCIÓN POR TIENDA")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.saLabel3)
                                    .tracking(0.2)
                                    .padding(.horizontal, 4)

                                SACard {
                                    // `SectorMark` dibuja un sector de dona (pie chart con hueco central).
                                    // Equivalente Android: `PieChart` de MPAndroidChart con `.setHoleRadius()`.
                                    // `innerRadius: .ratio(0.55)` crea el hueco del 55% del radio total.
                                    // `angularInset: 2` agrega separación entre sectores.
                                    // `.foregroundStyle(by: .value("Tienda", item.nombre))` colorea
                                    // automáticamente cada sector con la paleta de Swift Charts.
                                    Chart(gastosPorSuper.prefix(6), id: \.nombre) { item in
                                        SectorMark(
                                            angle: .value("Gasto", item.total),   // Tamaño del sector proporcional al gasto
                                            innerRadius: .ratio(0.55),             // Radio del hueco central (dona vs tarta)
                                            angularInset: 2                        // Separación entre sectores en puntos
                                        )
                                        .foregroundStyle(by: .value("Tienda", item.nombre))  // Color automático por nombre
                                        .cornerRadius(4)
                                    }
                                    // Leyenda debajo del gráfico, alineada a la izquierda
                                    .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
                                    .frame(height: 220)
                                }
                            }
                        }

                        // MARK: Ranking horizontal — BarMark horizontal
                        // Solo se muestra si hay productos registrados en el rango
                        if !productosMasComprados.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("PRODUCTOS MÁS COMPRADOS")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.saLabel3)
                                    .tracking(0.2)
                                    .padding(.horizontal, 4)

                                SACard {
                                    // Gráfico de barras horizontal: x = cantidad, y = nombre del producto.
                                    // Equivalente Android: `HorizontalBarChart` de MPAndroidChart.
                                    // Cuando se intercambia x e y en BarMark (eje X es numérico, Y es string),
                                    // Swift Charts automáticamente genera barras horizontales.
                                    Chart(productosMasComprados, id: \.nombre) { item in
                                        BarMark(
                                            x: .value("Cantidad", item.cantidad),   // Eje X: número de compras
                                            y: .value("Producto", item.nombre)       // Eje Y: nombre del producto
                                        )
                                        .foregroundStyle(LinearGradient.saGreen)
                                        .cornerRadius(6)
                                        // `.annotation(position: .trailing)` dibuja una etiqueta
                                        // al final de cada barra — equivalente a `ValueFormatter` en MPAndroidChart
                                        .annotation(position: .trailing) {
                                            Text("\(item.cantidad)x")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(Color.saLabel3)
                                        }
                                    }
                                    // Altura dinámica: 46 puntos por producto para que quepan todas las barras
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

    // MARK: - Barra de comparación mensual

    /// Barra de progreso horizontal proporcional para comparar dos meses.
    ///
    /// Usa `GeometryReader` para obtener el ancho disponible y calcular el ancho
    /// de la barra como `width * (value / max)`. Tiene animación suave de 0.7 segundos
    /// cuando cambia el valor.
    ///
    /// Equivalente Android: `ProgressBar` horizontal con `max` y `progress` configurados,
    /// o una `View` custom con `layout_width` calculado en `onMeasure()`.
    ///
    /// - Parameters:
    ///   - label: Etiqueta descriptiva ("Mes anterior", "Este mes").
    ///   - value: Valor a mostrar (total gastado).
    ///   - max: Valor máximo para normalizar el ancho de la barra.
    ///   - color: Color de relleno de la barra.
    @ViewBuilder
    private func monthBar(label: String, value: Double, max: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12)).foregroundStyle(Color.saLabel3)
            // `GeometryReader` permite acceder al tamaño del contenedor en tiempo de renderizado.
            // Equivalente Android: se obtiene en `onMeasure()` o con `ViewTreeObserver`.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Pista de fondo (fondo de la barra — 100% del ancho)
                    RoundedRectangle(cornerRadius: 5).fill(Color.saBg).frame(height: 10)
                    // Relleno proporcional animado
                    RoundedRectangle(cornerRadius: 5)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(value / max), height: 10)
                        .animation(.easeInOut(duration: 0.7), value: value)  // Animación suave al cambiar el valor
                }
            }
            .frame(height: 10)
            // Valor en moneda del usuario debajo de la barra
            Text(store.convert(value).formatted(.currency(code: store.currencyCode)))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.saLabel)
                .tracking(-0.3)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Card de métrica individual

    /// Card cuadrado con ícono, etiqueta y valor para la grilla 2×2 de métricas del mes.
    ///
    /// El parámetro `small` reduce el tamaño de fuente del valor para valores largos
    /// (como precios con decimales) que podrían desbordarse. Complementado con
    /// `.minimumScaleFactor(0.7)` y `.lineLimit(1)` para comprimir si es necesario.
    ///
    /// Equivalente Android: un `CardView` con un `ConstraintLayout` interno,
    /// o un `@Composable` de Material3 `ElevatedCard`.
    ///
    /// - Parameters:
    ///   - icon: SF Symbol name para el ícono.
    ///   - label: Etiqueta descriptiva debajo del valor.
    ///   - value: Texto del valor a mostrar (ya formateado).
    ///   - bg: Color de fondo del ícono.
    ///   - small: Si `true`, usa fuente más pequeña (15pt vs 22pt) para valores extensos.
    @ViewBuilder
    private func insightCard(icon: String, label: String, value: String, bg: Color, small: Bool = false) -> some View {
        SACard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                // Ícono con fondo de color redondeado
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
                        .font(.system(size: small ? 15 : 22, weight: .bold))   // Fuente adaptada al tipo de dato
                        .foregroundStyle(Color.saLabel)
                        .tracking(-0.4)
                        .lineLimit(1)               // Nunca ocupa más de una línea
                        .minimumScaleFactor(0.7)    // Se comprime hasta el 70% antes de truncar
                }
            }
        }
    }
}
