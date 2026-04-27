import SwiftUI
import SwiftData
import PhotosUI

struct NuevaCompraView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var supermercado = saSupermercados[0]
    @State private var totalStr = ""
    @State private var metodoPago = saMetodosPago[0]
    @State private var fecha = Date()
    @State private var showStorePicker = false
    @State private var showPaymentPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var ticketData: Data?

    private var canSave: Bool {
        (Double(totalStr.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
    }

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav header
                HStack {
                    Button("Cancelar") { dismiss() }
                        .font(.system(size: 16))
                        .foregroundStyle(Color.saLabel2)

                    Spacer()
                    Text("Nueva compra")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.saLabel)
                        .tracking(-0.4)
                    Spacer()

                    Button("Guardar") { guardar() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(canSave ? Color.saGreen : Color.saLabel4)
                        .disabled(!canSave)
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)
                .padding(.bottom, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Amount hero
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

                        // Form rows card
                        SACard(padding: 0) {
                            // Tienda
                            rowButton(
                                icon: "storefront",
                                iconBg: saStoreInfo(for: supermercado).color,
                                title: "Tienda",
                                value: supermercado,
                                isLast: false,
                                action: { showStorePicker = true }
                            )
                            // Fecha
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
                            // Método de pago
                            rowButton(
                                icon: "creditcard",
                                iconBg: Color(hex: "#8B5CF6"),
                                title: "Método de pago",
                                value: metodoPago,
                                isLast: true,
                                action: { showPaymentPicker = true }
                            )
                        }

                        // Ticket section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TICKET")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.saLabel3)
                                .tracking(0.2)
                                .padding(.horizontal, 4)

                            SACard(padding: 0) {
                                if let data = ticketData, let img = UIImage(data: data) {
                                    HStack(spacing: 12) {
                                        Image(uiImage: img)
                                            .resizable().scaledToFill()
                                            .frame(width: 60, height: 76)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("ticket.jpg")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(Color.saLabel)
                                            Text("Foto adjunta")
                                                .font(.system(size: 13))
                                                .foregroundStyle(Color.saLabel3)
                                        }
                                        Spacer()
                                        Button { ticketData = nil } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(Color.saDanger)
                                        }
                                    }
                                    .padding(16)
                                } else {
                                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                        VStack(spacing: 10) {
                                            Circle()
                                                .fill(Color.saGreenBg)
                                                .frame(width: 56, height: 56)
                                                .overlay(
                                                    Image(systemName: "camera.fill")
                                                        .font(.system(size: 24))
                                                        .foregroundStyle(Color.saGreen)
                                                )
                                            Text("Adjuntar foto del ticket")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(Color.saLabel)
                                            Text("Detectaremos productos automáticamente")
                                                .font(.system(size: 13))
                                                .foregroundStyle(Color.saLabel3)
                                                .multilineTextAlignment(.center)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(24)
                                    }
                                    .onChange(of: selectedPhoto) { _, item in
                                        Task { ticketData = try? await item?.loadTransferable(type: Data.self) }
                                    }
                                }
                            }
                        }
                        .padding(.top, 24)
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
    private func rowButton(icon: String, iconBg: Color, title: String, value: String, isLast: Bool, action: @escaping () -> Void) -> some View {
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
        guard let total = Double(totalStr.replacingOccurrences(of: ",", with: ".")) else { return }
        let compra = Compra(fecha: fecha, supermercado: supermercado, total: total, metodoPago: metodoPago)
        compra.imagenTicket = ticketData
        modelContext.insert(compra)
        dismiss()
    }
}

// MARK: - Store Picker Sheet
struct StorePickerSheet: View {
    @Binding var selected: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(saSupermercados, id: \.self) { nombre in
                Button(action: { selected = nombre; dismiss() }) {
                    HStack(spacing: 14) {
                        SAStoreAvatar(name: nombre, size: 36)
                        Text(nombre)
                            .font(.system(size: 17))
                            .foregroundStyle(Color.saLabel)
                        Spacer()
                        if selected == nombre {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.saGreen)
                                .fontWeight(.semibold)
                        }
                    }
                    .contentShape(Rectangle())
                }
            }
            .navigationTitle("Elegí una tienda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(Color.saGreen)
                }
            }
        }
    }
}

// MARK: - Payment Picker Sheet
struct PaymentPickerSheet: View {
    @Binding var selected: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(saMetodosPago, id: \.self) { metodo in
                Button(action: { selected = metodo; dismiss() }) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).fill(Color(hex: "#8B5CF6"))
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 36, height: 36)
                        Text(metodo)
                            .font(.system(size: 17))
                            .foregroundStyle(Color.saLabel)
                        Spacer()
                        if selected == metodo {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.saGreen)
                                .fontWeight(.semibold)
                        }
                    }
                    .contentShape(Rectangle())
                }
            }
            .navigationTitle("Método de pago")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(Color.saGreen)
                }
            }
        }
    }
}
