import SwiftUI
import SwiftData
import PhotosUI

struct NuevaCompraView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var supermercado = saSupermercados[0]
    @State private var metodoPago = saMetodosPago[0]
    @State private var fecha = Date()
    @State private var productos: [ProductoDraft] = []
    @State private var showStorePicker = false
    @State private var showPaymentPicker = false
    @State private var showAgregarProducto = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var ticketData: Data?
    @State private var showTicketOptions = false
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var isScanning = false
    @State private var isGuardando = false
    @State private var ocrDetected: Int?
    @State private var editarProducto: ProductoDraft?
    @AppStorage("ocrAutomatico") private var ocrAutomatico: Bool = true
    @State private var store = UserScopedStorage.shared

    private var total: Double { productos.reduce(0) { $0 + $1.precio } }
    private var canSave: Bool { !productos.isEmpty && !isScanning && !isGuardando }

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()

            VStack(spacing: 0) {
                navHeader

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        totalHero

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

                        productosSection
                            .padding(.top, 24)

                        ticketSection
                            .padding(.top, 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
        }
        .sheet(isPresented: $showStorePicker) { StorePickerSheet(selected: $supermercado) }
        .sheet(isPresented: $showPaymentPicker) { PaymentPickerSheet(selected: $metodoPago) }
        .sheet(isPresented: $showAgregarProducto) { AgregarProductoSheet(productos: $productos) }
        .sheet(item: $editarProducto) { prod in
            AgregarProductoSheet(productos: $productos, editando: prod)
        }
        .confirmationDialog("Adjuntar ticket", isPresented: $showTicketOptions) {
            Button("Cámara") { showCamera = true }
            Button("Galería") { showGallery = true }
            Button("Cancelar", role: .cancel) {}
        }
        .photosPicker(isPresented: $showGallery, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    ticketData = data
                }
            }
        }
        .onChange(of: ticketData) { _, data in
            guard let data, ocrAutomatico else { return }
            Task { await escanearTicket(data) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView(imageData: $ticketData).ignoresSafeArea()
        }
    }

    // MARK: - Nav header

    private var navHeader: some View {
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
            Button("Guardar") { Task { await guardar() } }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(canSave ? Color.saGreen : Color.saLabel4)
                .disabled(!canSave)
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
        .padding(.bottom, 16)
    }

    // MARK: - Total hero (read-only, live)

    private var totalHero: some View {
        VStack(spacing: 4) {
            Text("TOTAL")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.saLabel3)
                .tracking(0.2)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("$")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.saLabel3)
                Text(total == 0 ? "0" : total.formatted(.number.precision(.fractionLength(2))))
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(total == 0 ? Color.saLabel4 : Color.saLabel)
                    .tracking(-2)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.3), value: total)
            }
            Text(store.currencyName)
                .font(.system(size: 13))
                .foregroundStyle(Color.saLabel3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    // MARK: - Products section

    private var productosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PRODUCTOS")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.saLabel3)
                    .tracking(0.2)
                    .padding(.horizontal, 4)
                Spacer()
                Button {
                    showAgregarProducto = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Agregar")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.saGreen)
                }
            }

            SACard(padding: 0) {
                if productos.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "cart")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.saLabel4)
                        Text("Agregá al menos un producto para guardar")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.saLabel3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                } else {
                    ForEach(Array(productos.enumerated()), id: \.element.id) { idx, prod in
                        productoRow(prod, isLast: idx == productos.count - 1)
                    }

                    Rectangle().fill(Color.saSep).frame(height: 0.5)

                    HStack {
                        Text("\(productos.count) producto\(productos.count == 1 ? "" : "s")")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.saLabel3)
                        Spacer()
                        Text(store.convert(total).formatted(.currency(code: store.currencyCode)))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.saGreen)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }

            if isScanning {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8)
                    Text("Escaneando ticket…")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.saLabel3)
                }
                .padding(.horizontal, 4)
            }

            if let n = ocrDetected {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.saGreen)
                    Text("Se detectaron **\(n)** producto\(n == 1 ? "" : "s") del ticket")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.saLabel3)
                }
                .padding(.horizontal, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(duration: 0.3), value: ocrDetected != nil)
    }

    @ViewBuilder
    private func productoRow(_ prod: ProductoDraft, isLast: Bool) -> some View {
        HStack(spacing: 12) {
            // Área tapeable para editar
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color.saGreenBg)
                    Image(systemName: "bag.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.saGreen)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(prod.nombre)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.saLabel)
                        .lineLimit(1)
                    if !prod.descripcion.isEmpty {
                        Text(prod.descripcion)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.saLabel3)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(store.convert(prod.precio).formatted(.currency(code: store.currencyCode)))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.saLabel)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.saLabel4)
            }
            .contentShape(Rectangle())
            .onTapGesture { editarProducto = prod }

            Button {
                withAnimation(.spring(duration: 0.25)) {
                    productos.removeAll { $0.id == prod.id }
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.saLabel4)
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(Color.saSep).frame(height: 0.5).padding(.leading, 60)
            }
        }
    }

    // MARK: - Ticket section

    private var ticketSection: some View {
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
                    Button { showTicketOptions = true } label: {
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
                            Text(ocrAutomatico
                                 ? "Los productos se detectarán automáticamente con OCR"
                                 : "OCR desactivado — agregá productos manualmente")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.saLabel3)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Row button helper

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

    // MARK: - OCR

    private func escanearTicket(_ data: Data) async {
        isScanning = true
        ocrDetected = nil
        let encontrados = await TicketOCRService.shared.extraerProductos(de: data)
        isScanning = false

        guard !encontrados.isEmpty else { return }
        let existentes = Set(productos.map { $0.nombre.lowercased() })
        let nuevos = encontrados.filter { !existentes.contains($0.nombre.lowercased()) }
        guard !nuevos.isEmpty else { return }

        withAnimation(.spring(duration: 0.3)) {
            productos.append(contentsOf: nuevos)
        }
        ocrDetected = nuevos.count
        try? await Task.sleep(for: .seconds(4))
        withAnimation { ocrDetected = nil }
    }

    // MARK: - Save

    private func guardar() async {
        isGuardando = true
        defer { isGuardando = false }

        let compra = Compra(fecha: fecha, supermercado: supermercado, total: total, metodoPago: metodoPago)
        // Corrección: SupabaseService.currentUserID puede ser nil en el init si la sesión
        // aún no cargó en memoria. Acá sí somos @MainActor y SessionStore ya tiene el valor.
        let uid = SessionStore.shared.currentUserID
        if !uid.isEmpty { compra.userId = uid }

        // Intentar subir ticket a Supabase Storage; si falla, guardar localmente
        if let data = ticketData {
            if let url = try? await SupabaseService.shared.subirTicket(data, compraID: compra.id) {
                compra.ticketURL = url
            } else {
                compra.imagenTicket = data
            }
        }

        modelContext.insert(compra)

        for draft in productos {
            let producto = Producto(codigo: draft.codigo, nombre: draft.nombre, descripcion: draft.descripcion, precio: draft.precio)
            producto.compra = compra
            modelContext.insert(producto)
        }

        // Guardar a disco antes del sync para no perder datos si hay error de red.
        try? modelContext.save()

        // Intenta sync inmediato; si falla, isSynced queda false y
        // SyncService.sincronizarPendientes() reintentará en el próximo arranque.
        Task {
            do {
                try await SupabaseService.shared.crearCompra(
                    id: compra.id, fecha: compra.fecha, supermercado: compra.supermercado,
                    total: compra.total, metodoPago: compra.metodoPago, ticketURL: compra.ticketURL
                )
                compra.isSynced = true
                for producto in compra.productos {
                    try await SupabaseService.shared.crearProducto(
                        id: producto.id, compraID: compra.id, nombre: producto.nombre,
                        descripcion: producto.descripcion, codigo: producto.codigo, precio: producto.precio
                    )
                    producto.isSynced = true
                }
                try? modelContext.save()
            } catch {
                // Sin conexión: isSynced = false persiste para reintento posterior
            }
        }

        dismiss()
    }
}

// MARK: - Agregar Producto Sheet

struct AgregarProductoSheet: View {
    @Binding var productos: [ProductoDraft]
    var editando: ProductoDraft? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var nombre = ""
    @State private var descripcion = ""
    @State private var precioStr = ""

    private var precio: Double {
        Double(precioStr.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var canConfirm: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty && precio > 0
    }

    private var isEditing: Bool { editando != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.saBg.ignoresSafeArea()

                VStack(spacing: 12) {
                    SAField(placeholder: "Nombre del producto", text: $nombre, icon: "tag")
                    SAField(placeholder: "Descripción (opcional)", text: $descripcion, icon: "text.alignleft")
                    SAField(placeholder: "Precio", text: $precioStr, icon: "dollarsign")
                        .keyboardType(.decimalPad)
                        .onChange(of: precioStr) { _, v in
                            precioStr = v.filter { $0.isNumber || $0 == "." || $0 == "," }
                        }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .navigationTitle(isEditing ? "Editar producto" : "Nuevo producto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Color.saGreen)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Guardar" : "Agregar") {
                        let nombreFinal = nombre.trimmingCharacters(in: .whitespaces)
                        if let p = editando, let idx = productos.firstIndex(where: { $0.id == p.id }) {
                            productos[idx].nombre = nombreFinal
                            productos[idx].descripcion = descripcion
                            productos[idx].precio = precio
                        } else {
                            productos.append(ProductoDraft(
                                nombre: nombreFinal,
                                descripcion: descripcion,
                                precio: precio
                            ))
                        }
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(canConfirm ? Color.saGreen : Color.saLabel4)
                    .disabled(!canConfirm)
                }
            }
            .onAppear {
                if let p = editando {
                    nombre = p.nombre
                    descripcion = p.descripcion
                    precioStr = p.precio == 0 ? "" : String(format: "%.2f", p.precio)
                }
            }
        }
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
