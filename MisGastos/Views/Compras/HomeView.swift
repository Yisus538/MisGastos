// =============================================================================
// HomeView.swift — Pantalla de inicio con resumen mensual de gastos
// =============================================================================
// Rol en la app:
//   Es la pantalla principal de la app autenticada (Tab "Inicio"). Muestra:
//   - Header con gradiente verde: total gastado este mes, delta vs mes anterior,
//     cantidad de compras, promedio y tiendas visitadas.
//   - Card de presupuesto (si está activo): barra de progreso con colores semáforo.
//   - Lista de las últimas 8 compras con navegación a su detalle.
//   - FAB (Floating Action Button) para agregar una nueva compra.
//
// Equivalente Android:
//   `HomeFragment` o `@Composable fun HomeScreen(viewModel: HomeViewModel)`.
//   La query de compras equivale a `viewModel.compras.collectAsState()` donde
//   el `ViewModel` expone un `StateFlow<List<Compra>>` desde Room.
//
// @Query de SwiftData:
//   `@Query(sort: \Compra.fecha, order: .reverse)` es la forma declarativa de
//   SwiftData de consultar la base de datos local. Es equivalente a:
//   ```kotlin
//   @Query("SELECT * FROM Compra ORDER BY fecha DESC")
//   fun getAll(): Flow<List<Compra>>
//   ```
//   SwiftUI se suscribe automáticamente y re-renderiza cuando los datos cambian.
//
// Filtro reactivo de userId:
//   No se usa un predicate fijo en @Query porque el `currentUserID` puede no
//   estar disponible en el momento en que la vista se crea. En cambio, se
//   filtra el array `todasLasCompras` con `compras: [Compra]` computado en el
//   body, que se re-evalúa automáticamente cuando `session.currentUserID` cambia.
//
// Widget data:
//   `writeWidgetData()` escribe en el App Group UserDefaults cada vez que
//   los totales cambian, para mantener el Widget sincronizado con los datos
//   más recientes sin que el usuario tenga que abrir la app.
// =============================================================================

import SwiftUI
import SwiftData

/// Pantalla de inicio con resumen de gastos del mes y acceso rápido a nueva compra.
///
/// Equivalente Android: `HomeScreen` en Compose con `LazyColumn` de compras
/// y un `FloatingActionButton` para agregar.
struct HomeView: View {

    // MARK: - Fuentes de datos

    /// Contexto de SwiftData — se usa para verificar las compras locales.
    @Environment(\.modelContext) private var modelContext

    /// Todas las compras locales ordenadas por fecha descendente.
    ///
    /// `@Query` es la integración de SwiftData con SwiftUI: cuando los datos cambian
    /// en la DB local, SwiftUI re-renderiza la vista automáticamente.
    /// Sin predicate fijo — el filtro por userId se aplica en `compras` computado.
    @Query(sort: \Compra.fecha, order: .reverse) private var todasLasCompras: [Compra]

    /// Preferencias del usuario (moneda, presupuesto, nombre).
    @State private var store = UserScopedStorage.shared

    /// Estado de autenticación — provee el `currentUserID` para filtrar compras.
    @State private var session = SessionStore.shared

    // MARK: - Propiedades del usuario

    /// Nombre del usuario desde `UserScopedStorage`. "Usuario" como fallback.
    private var nombre: String          { store.nombre.isEmpty ? "Usuario" : store.nombre }

    /// Si el usuario tiene un presupuesto mensual activo.
    private var presupuestoActivo: Bool { store.presupuestoActivo }

    /// Monto del presupuesto mensual.
    private var presupuesto: Double     { store.presupuestoMensual }

    // MARK: - Estado de UI

    /// Controla si se presenta la sheet de nueva compra.
    @State private var showNuevaCompra = false

    /// Controla si se muestra la alerta de presupuesto superado.
    @State private var showBudgetAlert = false

    /// Mes en que se mostró la última alerta de presupuesto (formato "2026-5").
    /// Persiste para no mostrar la alerta más de una vez por mes.
    @State private var presupuestoAlertaMes: String = ""

    // MARK: - Helpers de calendario

    private var cal: Calendar { .current }

    // MARK: - Compras filtradas

    /// Compras del usuario actual — filtradas reactivamente por `session.currentUserID`.
    ///
    /// Al cambiar `session.currentUserID`, SwiftUI re-evalúa esta propiedad y la vista
    /// se actualiza automáticamente. Equivalente Android: `StateFlow` con `filter { }`.
    private var compras: [Compra] {
        let uid = session.currentUserID
        guard !uid.isEmpty else { return [] }
        return todasLasCompras.filter { $0.userId == uid }
    }

    /// Compras del mes calendario actual.
    private var comprasEsteMes: [Compra] {
        compras.filter {
            cal.isDate($0.fecha, equalTo: Date(), toGranularity: .month)
        }
    }

    /// Compras del mes calendario anterior.
    private var comprasMesAnterior: [Compra] {
        guard let prevMonth = cal.date(byAdding: .month, value: -1, to: Date()) else { return [] }
        return compras.filter {
            cal.isDate($0.fecha, equalTo: prevMonth, toGranularity: .month)
        }
    }

    // MARK: - Métricas del mes

    /// Total gastado en el mes actual.
    private var totalEsteMes: Double     { comprasEsteMes.reduce(0) { $0 + $1.total } }

    /// Total gastado en el mes anterior.
    private var totalMesAnterior: Double { comprasMesAnterior.reduce(0) { $0 + $1.total } }

    /// Diferencia porcentual entre el mes actual y el anterior.
    /// `> 0` significa que se gastó más; `< 0` que se gastó menos.
    private var delta: Double {
        guard totalMesAnterior > 0 else { return 0 }
        return (totalEsteMes - totalMesAnterior) / totalMesAnterior * 100
    }

    /// Monto promedio por compra en el mes actual.
    private var promedioEsteMes: Double {
        guard !comprasEsteMes.isEmpty else { return 0 }
        return totalEsteMes / Double(comprasEsteMes.count)
    }

    /// Cantidad de supermercados distintos visitados en el mes.
    /// `Set` elimina duplicados automáticamente.
    private var tiendas: Int {
        Set(comprasEsteMes.map { $0.supermercado }).count
    }

    /// Nombre del mes actual en español (ej: "mayo").
    private var mesActual: String {
        Date().formatted(.dateTime.month(.wide))
    }

    /// Primer nombre del usuario en mayúsculas (ej: "JUAN").
    private var primerNombre: String {
        nombre.components(separatedBy: " ").first?.uppercased() ?? nombre.uppercased()
    }

    /// Altura de la status bar del dispositivo (para el padding del header).
    private var statusBarHeight: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.top }
            .first ?? 44
    }

    // MARK: - Vista principal

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.saBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header con gradiente verde y estadísticas del mes
                    header

                    // Card de presupuesto (solo si está activo)
                    if presupuestoActivo && presupuesto > 0 {
                        budgetCard
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                    }

                    // Lista de compras recientes o estado vacío
                    recentSection
                        .padding(.top, 24)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                }
            }
            .ignoresSafeArea(edges: .top)  // Para que el header llegue al borde superior

            // FAB (Floating Action Button) para agregar nueva compra
            // Equivalente Android: `FloatingActionButton` de Material Design
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
        // Alerta de presupuesto superado
        .alert("Presupuesto superado", isPresented: $showBudgetAlert) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text("Gastaste \(store.convert(totalEsteMes).formatted(.currency(code: store.currencyCode))) este mes, superando tu límite de \(store.convert(presupuesto).formatted(.currency(code: store.currencyCode))) por \(store.convert(totalEsteMes - presupuesto).formatted(.currency(code: store.currencyCode))).")
        }
        .onAppear {
            // Cargar el mes de la última alerta para no repetirla
            presupuestoAlertaMes = store.presupuestoAlertaMes
            verificarPresupuesto()
            writeWidgetData()
        }
        // Actualizar verificación y widget cuando cambia el total del mes
        .onChange(of: totalEsteMes) { _, _ in
            verificarPresupuesto()
            writeWidgetData()
        }
        // Actualizar widget cuando cambia la configuración de presupuesto
        .onChange(of: store.presupuestoActivo)  { _, _ in writeWidgetData() }
        .onChange(of: store.presupuestoMensual) { _, _ in writeWidgetData() }
    }

    // MARK: - Header

    /// Header con gradiente verde que muestra el saludo, total del mes y métricas.
    ///
    /// Usa `UnevenRoundedRectangle` para redondear solo las esquinas inferiores,
    /// creando el efecto de que el header "sale" del borde superior de la pantalla.
    private var header: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient.saGreen

            // Círculo decorativo semitransparente en la esquina superior derecha
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 260, height: 260)
                .offset(x: 100, y: -80)

            VStack(alignment: .leading, spacing: 0) {
                // Espacio para la status bar (Safe Area)
                Color.clear.frame(height: statusBarHeight)

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Saludo personalizado con el nombre del usuario
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

                    // Botón de notificaciones (decorativo)
                    Circle()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 40, height: 40)
                        .overlay(Image(systemName: "bell").font(.system(size: 18)).foregroundStyle(.white))
                }
                .padding(.bottom, 24)

                // Total gastado en el mes actual
                Text("Gastado este mes")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.85))

                // Monto principal — convertido a la moneda seleccionada por el usuario
                Text(store.convert(totalEsteMes).formatted(.currency(code: store.currencyCode)))
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.white)
                    .tracking(-1.5)
                    .padding(.top, 4)

                // Badge de delta vs mes anterior (verde si bajó, oscuro si subió)
                HStack(spacing: 8) {
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
                            ? Color.white.opacity(0.22)    // Fondo claro si disminuyó (bueno)
                            : Color.black.opacity(0.18),   // Fondo oscuro si aumentó (malo)
                        in: RoundedRectangle(cornerRadius: 10)
                    )

                    if totalMesAnterior > 0 {
                        Text("vs. mes anterior")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding(.top, 8)

                // Pills de estadísticas rápidas del mes
                HStack(spacing: 10) {
                    statPill(label: "Compras",  value: "\(comprasEsteMes.count)")
                    statPill(label: "Promedio",  value: store.convert(promedioEsteMes).formatted(.currency(code: store.currencyCode)))
                    statPill(label: "Tiendas",   value: "\(tiendas)")
                }
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 20)
        }
        // Esquinas inferiores redondeadas para el efecto de card flotante
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 32,
                bottomTrailingRadius: 32, topTrailingRadius: 0
            )
        )
    }

    /// Pill de estadística con etiqueta y valor.
    ///
    /// Se usa para mostrar Compras, Promedio y Tiendas en el header.
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
                .minimumScaleFactor(0.7)  // Reduce la fuente si el valor es muy largo
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Sección de compras recientes

    /// Sección de compras recientes o estado vacío si no hay compras.
    ///
    /// `ContentUnavailableView` es el componente nativo de iOS 17+ para estados vacíos.
    /// Equivalente Android: un `EmptyView` composable o una vista condicional.
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
                    // Link a la pantalla de Historial completo
                    NavigationLink {
                        HistorialView()
                    } label: {
                        Text("Ver todas")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.saGreen)
                    }
                }

                // Las últimas 8 compras en una SACard con filas separadas por divisores
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

    /// Fila individual de una compra reciente con avatar del supermercado, total y fecha.
    @ViewBuilder
    private func recentRow(compra: Compra, isLast: Bool) -> some View {
        HStack(spacing: 12) {
            // Avatar circular con color e iniciales del supermercado
            SAStoreAvatar(name: compra.supermercado, size: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(compra.supermercado)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.saLabel)
                    .tracking(-0.3)
                // Fecha y cantidad de productos
                Text("\(compra.fecha.formatted(date: .abbreviated, time: .omitted)) · \(compra.productos.count) items")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.saLabel3)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                // Total convertido a la moneda del usuario
                Text(store.convert(compra.total).formatted(.currency(code: store.currencyCode)))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.saLabel)
                    .tracking(-0.3)
                // Primera palabra del método de pago (ej: "Débito" en lugar de "Débito Visa")
                Text(compra.metodoPago.components(separatedBy: " ").first ?? "")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.saLabel3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            // Divisor horizontal entre filas (excepto la última)
            if !isLast {
                Rectangle()
                    .fill(Color.saSep)
                    .frame(height: 0.5)
                    .padding(.leading, 70)  // Alineado con el texto, no con el avatar
            }
        }
        .contentShape(Rectangle())  // Área tappable ocupa toda la fila (no solo el texto)
    }

    // MARK: - Card de presupuesto

    /// Card que muestra el progreso del presupuesto mensual con barra semáforo.
    ///
    /// Colores semáforo:
    /// - Verde (`.saGreen`): menos del 80% del presupuesto usado.
    /// - Naranja: entre 80% y 100% (advertencia).
    /// - Rojo (`.saDanger`): presupuesto superado.
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
                    // Ícono según el estado del presupuesto
                    Image(systemName: excedido ? "exclamationmark.triangle.fill"
                                     : cercano  ? "exclamationmark.circle.fill" : "target")
                        .font(.system(size: 15))
                        .foregroundStyle(barColor)
                    Text("Presupuesto de \(mesActual.lowercased())")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.saLabel)
                        .tracking(-0.3)
                    Spacer()
                    // Porcentaje usado del presupuesto
                    Text("\(pct)%")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(barColor)
                }

                // Barra de progreso con animación spring
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.saBg).frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(barColor)
                            .frame(width: max(0, geo.size.width * CGFloat(progress)), height: 8)
                            .animation(.spring(duration: 0.4), value: progress)  // Animación suave
                    }
                }
                .frame(height: 8)

                // Total gastado / límite del presupuesto
                HStack {
                    Text(store.convert(totalEsteMes).formatted(.currency(code: store.currencyCode)))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(barColor)
                    Text("/ \(store.convert(presupuesto).formatted(.currency(code: store.currencyCode)))")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.saLabel3)
                    Spacer()
                    // Etiqueta de estado (solo en casos límite)
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

    // MARK: - Estado vacío

    /// Vista de estado vacío — se muestra cuando el usuario no tiene compras registradas.
    ///
    /// `ContentUnavailableView` es el componente estándar de iOS 17+ para listas vacías.
    /// Equivalente Android: un `EmptyState` composable custom o `RecyclerView.Adapter`
    /// con vista de estado vacío.
    private var emptyState: some View {
        ContentUnavailableView {
            Label("Sin compras aún", systemImage: "cart.fill")
        } description: {
            Text("Tocá el **+** para registrar\ntu primera compra")
        }
        .padding(.top, 40)
    }

    // MARK: - Helpers

    /// Verifica si se superó el presupuesto y muestra una alerta (una vez por mes).
    ///
    /// Usa el mes como clave para no repetir la alerta si el usuario ya la vio.
    /// La clave se guarda en `UserScopedStorage` para persistir entre sesiones.
    private func verificarPresupuesto() {
        guard presupuestoActivo, presupuesto > 0, totalEsteMes >= presupuesto else { return }
        let mesKey = Date().formatted(.dateTime.year().month())
        // Solo mostrar si no se mostró ya en este mes
        guard presupuestoAlertaMes != mesKey else { return }
        presupuestoAlertaMes = mesKey
        store.set(mesKey, for: "presupuestoAlertaMes")
        showBudgetAlert = true
    }

    /// Escribe los datos del mes en el App Group para actualizar el Widget.
    ///
    /// Se llama cuando cambia el total del mes o la configuración del presupuesto.
    /// Equivalente Android: `AppWidgetManager.updateAppWidget()` con nuevos `RemoteViews`.
    private func writeWidgetData() {
        WidgetDataWriter.write(
            totalMes: totalEsteMes,
            nombreMes: Date().formatted(.dateTime.month(.wide)).capitalized,
            cantidadCompras: comprasEsteMes.count,
            presupuesto: presupuesto,
            presupuestoActivo: presupuestoActivo
        )
    }
}
