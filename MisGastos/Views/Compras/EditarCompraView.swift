// =============================================================================
// EditarCompraView.swift — Formulario de edición de compra existente
// =============================================================================
// Rol en la app:
//   Sheet que permite al usuario editar los datos de una compra ya guardada
//   (supermercado, total, método de pago y fecha). Se presenta desde
//   `DetalleCompraView` al tocar el botón de lápiz en el header.
//
// Equivalente Android:
//   `EditPurchaseActivity` o `EditPurchaseBottomSheet` que recibe el ID de la
//   compra, carga sus datos con ViewModel + Room, y al guardar actualiza
//   la base de datos local y sincroniza con Firestore/Supabase.
//
// @Bindable con estado local:
//   La edición se realiza en variables `@State` locales (no en el objeto
//   `Compra` directamente) hasta que el usuario confirma. Esto permite cancelar
//   sin efectos secundarios. Solo al tocar "Guardar" se copian los valores al
//   `@Bindable var compra`.
//
// Sincronización con Supabase:
//   `guardar()` aplica los cambios al objeto SwiftData localmente y luego llama
//   a `SupabaseService.actualizarCompra()` en un `Task {}` en background.
//   Si la conexión falla, SwiftData local está actualizado y Supabase puede
//   actualizarse en la próxima oportunidad (por ahora no hay retry automático
//   para ediciones — solo creaciones).
// =============================================================================

import SwiftUI
import SwiftData

/// Sheet de edición de una compra existente.
///
/// Equivalente Android: `EditPurchaseFragment` con `viewModel.updateCompra(id, data)`.
struct EditarCompraView: View {

    // MARK: - Dato principal

    /// Entidad `Compra` de SwiftData — los cambios se aplican al confirmar.
    @Bindable var compra: Compra

    /// Dismisses la sheet al guardar o cancelar.
    @Environment(\.dismiss) private var dismiss

    // MARK: - Estado local del formulario

    /// Copia local del supermercado para edición sin afectar el original hasta guardar.
    @State private var supermercado: String

    /// Copia local del total como string (editable con teclado numérico).
    @State private var totalStr: String

    /// Copia local del método de pago.
    @State private var metodoPago: String

    /// Copia local de la fecha.
    @State private var fecha: Date

    /// Controla si se presenta el selector de supermercado.
    @State private var showStorePicker = false

    /// Controla si se presenta el selector de método de pago.
    @State private var showPaymentPicker = false

    /// `true` mientras se procesa el guardado (deshabilita el botón).
    @State private var isGuardando = false

    // MARK: - Inicializador

    /// Inicializa los estados locales con los valores actuales de la compra.
    ///
    /// Se usa un inicializador custom porque `@State` requiere `State(initialValue:)`.
    /// Si el total es un entero (ej: 1500.0), lo muestra sin decimales ("1500").
    /// Si tiene decimales (ej: 1500.50), lo muestra con 2 decimales ("1500.50").
    init(compra: Compra) {
        self._compra = Bindable(compra)
        self._supermercado = State(initialValue: compra.supermercado)
        // Formatear el total: sin decimales si es entero, con .2f si no lo es
        let t = compra.total
        let str = t.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(t))
            : String(format: "%.2f", t)
        self._totalStr = State(initialValue: str)
        self._metodoPago = State(initialValue: compra.metodoPago)
        self._fecha = State(initialValue: compra.fecha)
    }

    // MARK: - Validación

    /// El total ingresado debe ser mayor a 0 para poder guardar.
    private var canSave: Bool {
        (Double(totalStr.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
    }

    // MARK: - Vista principal

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header con botones de Cancelar y Guardar
                HStack {
                    Button("Cancelar") { dismiss() }
                        .font(.system(size: 16))
                        .foregroundStyle(Color.saLabel2)

                    Spacer()
                    Text("Editar compra")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.saLabel)
                        .tracking(-0.4)
                    Spacer()

                    // Botón de guardar — deshabilitado si el total es 0 o está guardando
                    Button("Guardar") { guardar() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(canSave && !isGuardando ? Color.saGreen : Color.saLabel4)
                        .disabled(!canSave || isGuardando)
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)
                .padding(.bottom, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Total editable — a diferencia de NuevaCompraView donde es de solo lectura
                        VStack(spacing: 4) {
                            Text("TOTAL")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.saLabel3)
                                .tracking(0.2)
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("$")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(Color.saLabel3)
                                // TextField editable (en lugar del Text de solo lectura de NuevaCompraView)
                                TextField("0", text: $totalStr)
                                    .font(.system(size: 56, weight: .bold))
                                    .foregroundStyle(Color.saLabel)
                                    .tracking(-2)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.center)
                                    .fixedSize()   // Se ajusta al contenido, no expande al máximo
                                    .onChange(of: totalStr) { _, v in
                                        // Filtrar caracteres no numéricos
                                        totalStr = v.filter { $0.isNumber || $0 == "." || $0 == "," }
                                    }
                            }
                            Text("Pesos argentinos")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.saLabel3)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)

                        // Card de selección de tienda, fecha y método de pago
                        SACard(padding: 0) {
                            rowButton(
                                icon: "storefront",
                                iconBg: saStoreInfo(for: supermercado).color,
                                title: "Tienda",
                                value: supermercado,
                                isLast: false,
                                action: { showStorePicker = true }
                            )
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8).fill(Color(hex: "#FF9500"))
                                    Image(systemName: "calendar")
                                        .font(.system(size: 15))
                                        .foregroundStyle(.white)
                                }
                                .frame(width: 32, height: 32)

                                Text("Fecha")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.saLabel)
                                Spacer()
                                DatePicker("", selection: $fecha, displayedComponents: .date)
                                    .labelsHidden()
                                    .tint(Color.saGreen)
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 60)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Color.saSep).frame(height: 0.5).padding(.leading, 62)
                            }
                            rowButton(
                                icon: "creditcard",
                                iconBg: Color(hex: "#8B5CF6"),
                                title: "Método de pago",
                                value: metodoPago,
                                isLast: true,
                                action: { showPaymentPicker = true }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
        }
        .sheet(isPresented: $showStorePicker) {
            StorePickerSheet(selected: $supermercado)
        }
        .sheet(isPresented: $showPaymentPicker) {
            PaymentPickerSheet(selected: $metodoPago)
        }
    }

    // MARK: - Helper de fila con botón

    /// Fila estilo iOS Settings con ícono, título y valor seleccionado.
    @ViewBuilder
    private func rowButton(
        icon: String, iconBg: Color, title: String,
        value: String, isLast: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(iconBg)
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                }
                .frame(width: 32, height: 32)

                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.saLabel)
                Spacer()
                Text(value)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.saLabel2)
                    .tracking(-0.3)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.saLabel4)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 60)
            .overlay(alignment: .bottom) {
                if !isLast {
                    Rectangle().fill(Color.saSep).frame(height: 0.5).padding(.leading, 62)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Guardar cambios

    /// Aplica los cambios locales al objeto SwiftData y sincroniza con Supabase.
    ///
    /// Orden de operaciones:
    /// 1. Copiar los valores locales editados al `@Bindable var compra`.
    ///    SwiftData detecta los cambios y los persiste automáticamente en SQLite.
    /// 2. Dismiss de la sheet (el usuario ve el resultado inmediatamente).
    /// 3. `Task { }` sincroniza con Supabase en background sin bloquear la UI.
    ///
    /// Equivalente Android: `viewModel.updateCompra(id, datos)` en una coroutina
    /// que actualiza Room y luego Firebase/Supabase.
    private func guardar() {
        guard !isGuardando,
              let total = Double(totalStr.replacingOccurrences(of: ",", with: ".")) else { return }
        isGuardando = true

        // Aplicar cambios al objeto SwiftData (se persisten automáticamente)
        compra.supermercado = supermercado
        compra.total = total
        compra.metodoPago = metodoPago
        compra.fecha = fecha

        // Capturar snapshot para el Task en background (evitar capturar self/objetos SwiftData)
        let snap = (id: compra.id, supermercado: supermercado, fecha: fecha,
                    total: total, metodoPago: metodoPago, ticketURL: compra.ticketURL)

        // Sincronizar con Supabase en background
        Task {
            try? await SupabaseService.shared.actualizarCompra(
                id: snap.id, supermercado: snap.supermercado, fecha: snap.fecha,
                total: snap.total, metodoPago: snap.metodoPago, ticketURL: snap.ticketURL
            )
        }

        dismiss()
    }
}
