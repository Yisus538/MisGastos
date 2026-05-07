import SwiftUI
import SwiftData

struct EditarCompraView: View {
    @Bindable var compra: Compra
    @Environment(\.dismiss) private var dismiss

    @State private var supermercado: String
    @State private var totalStr: String
    @State private var metodoPago: String
    @State private var fecha: Date
    @State private var showStorePicker = false
    @State private var showPaymentPicker = false
    @State private var isGuardando = false

    init(compra: Compra) {
        self._compra = Bindable(compra)
        self._supermercado = State(initialValue: compra.supermercado)
        let t = compra.total
        let str = t.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(t))
            : String(format: "%.2f", t)
        self._totalStr = State(initialValue: str)
        self._metodoPago = State(initialValue: compra.metodoPago)
        self._fecha = State(initialValue: compra.fecha)
    }

    private var canSave: Bool {
        (Double(totalStr.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
    }

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()

            VStack(spacing: 0) {
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
                        VStack(spacing: 4) {
                            Text("TOTAL")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.saLabel3)
                                .tracking(0.2)
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("$")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(Color.saLabel3)
                                TextField("0", text: $totalStr)
                                    .font(.system(size: 56, weight: .bold))
                                    .foregroundStyle(Color.saLabel)
                                    .tracking(-2)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.center)
                                    .fixedSize()
                                    .onChange(of: totalStr) { _, v in
                                        totalStr = v.filter { $0.isNumber || $0 == "." || $0 == "," }
                                    }
                            }
                            Text("Pesos argentinos")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.saLabel3)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)

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

    private func guardar() {
        guard !isGuardando,
              let total = Double(totalStr.replacingOccurrences(of: ",", with: ".")) else { return }
        isGuardando = true
        compra.supermercado = supermercado
        compra.total = total
        compra.metodoPago = metodoPago
        compra.fecha = fecha
        let snap = (id: compra.id, supermercado: supermercado, fecha: fecha,
                    total: total, metodoPago: metodoPago, ticketURL: compra.ticketURL)
        Task {
            try? await SupabaseService.shared.actualizarCompra(
                id: snap.id, supermercado: snap.supermercado, fecha: snap.fecha,
                total: snap.total, metodoPago: snap.metodoPago, ticketURL: snap.ticketURL
            )
        }
        dismiss()
    }
}
