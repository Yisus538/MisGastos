// =============================================================================
// NuevaCompraView.swift — Formulario de creación de nueva compra
// =============================================================================
// Rol en la app:
//   Sheet que permite al usuario registrar una nueva compra de supermercado.
//   El flujo es:
//   1. Seleccionar tienda, fecha y método de pago.
//   2. Agregar productos (manualmente o desde OCR del ticket).
//   3. Adjuntar foto del ticket (cámara o galería, opcional).
//   4. Guardar: persiste en SwiftData local y sincroniza con Supabase en background.
//
// Equivalente Android:
//   `AddPurchaseFragment` o `@Composable fun NewPurchaseScreen(viewModel)` con:
//   - `LazyColumn` para los productos.
//   - `ActivityResultContracts.TakePicture()` para la cámara.
//   - `ActivityResultContracts.GetContent()` para la galería.
//   - Coroutinas + `viewModelScope.launch { }` para guardar.
//
// PhotosPickerItem (iOS 16+):
//   `PhotosPicker` es el selector de fotos nativo del sistema.
//   `PhotosPickerItem.loadTransferable(type: Data.self)` carga la imagen como `Data`.
//   Equivalente Android: `Intent(Intent.ACTION_PICK)` con `MediaStore.Images.Media.EXTERNAL_CONTENT_URI`
//   o la API moderna `ActivityResultContracts.PickVisualMedia()`.
//
// OCR automático:
//   Cuando el usuario adjunta un ticket (cámara o galería), `TicketOCRService`
//   extrae los productos automáticamente si `ocrAutomatico == true`.
//   Los productos detectados se agregan a la lista filtrando duplicados.
//
// Estrategia de guardado offline-first:
//   1. Crear `Compra` y `Producto` en SwiftData local inmediatamente.
//   2. Guardar a disco (`modelContext.save()`).
//   3. Dismiss de la sheet (el usuario ve el resultado de inmediato).
//   4. Sincronizar con Supabase en background con `Task { }`.
//   Si el sync falla, `isSynced = false` y `SyncService` reintentará al próximo arranque.
// =============================================================================

import SwiftUI
import SwiftData
import PhotosUI

/// Sheet de creación de nueva compra con soporte de OCR de ticket.
///
/// Equivalente Android: `AddPurchaseActivity` o un `BottomSheetDialogFragment` con formulario.
struct NuevaCompraView: View {

    // MARK: - Dependencias

    /// Contexto de SwiftData para insertar la compra y sus productos.
    @Environment(\.modelContext) private var modelContext

    /// Dismisses la sheet al guardar o cancelar.
    @Environment(\.dismiss) private var dismiss

    // MARK: - Estado del formulario

    /// Supermercado seleccionado (por defecto el primero de la lista).
    @State private var supermercado = saSupermercados[0]

    /// Método de pago seleccionado (por defecto el primero de la lista).
    @State private var metodoPago = saMetodosPago[0]

    /// Fecha de la compra (por defecto hoy).
    @State private var fecha = Date()

    /// Lista de productos en borrador antes de guardar en SwiftData.
    @State private var productos: [ProductoDraft] = []

    // MARK: - Estado de presentación de sheets

    @State private var showStorePicker = false       // Selector de tienda
    @State private var showPaymentPicker = false     // Selector de método de pago
    @State private var showAgregarProducto = false   // Sheet para agregar producto

    // MARK: - Ticket y cámara

    /// Ítem seleccionado de la galería — `PhotosPickerItem` es el nuevo API de iOS 16+.
    @State private var selectedPhoto: PhotosPickerItem?

    /// Datos JPEG de la imagen del ticket (de cámara o galería).
    @State private var ticketData: Data?

    /// Muestra el `confirmationDialog` para elegir cámara o galería.
    @State private var showTicketOptions = false

    /// Presenta `CameraPickerView` en pantalla completa para tomar foto.
    @State private var showCamera = false

    /// Presenta el `PhotosPicker` nativo de iOS.
    @State private var showGallery = false

    // MARK: - Estado del OCR

    /// `true` mientras `TicketOCRService` está procesando la imagen.
    @State private var isScanning = false

    /// Cantidad de productos detectados por OCR (para mostrar el banner de resultado).
    @State private var ocrDetected: Int?

    // MARK: - Estado de guardado

    /// `true` mientras se está guardando la compra (deshabilita el botón de guardar).
    @State private var isGuardando = false

    // MARK: - Edición de producto

    /// Producto en borrador siendo editado en `AgregarProductoSheet`.
    @State private var editarProducto: ProductoDraft?

    // MARK: - Preferencias

    /// Si el OCR se ejecuta automáticamente al adjuntar un ticket.
    @AppStorage("ocrAutomatico") private var ocrAutomatico: Bool = true

    /// Preferencias de moneda del usuario.
    @State private var store = UserScopedStorage.shared

    // MARK: - Propiedades computadas

    /// Suma de los precios de todos los productos en borrador.
    private var total: Double { productos.reduce(0) { $0 + $1.precio } }

    /// Condición para habilitar el botón de guardar: al menos un producto y sin ops en curso.
    private var canSave: Bool { !productos.isEmpty && !isScanning && !isGuardando }

    // MARK: - Vista principal

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header con botones de Cancelar y Guardar
                navHeader

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Total animado que se actualiza al agregar/quitar productos
                        totalHero

                        // Card con selección de tienda, fecha y método de pago
                        SACard(padding: 0) {
                            rowButton(
                                icon: "storefront",
                                iconBg: saStoreInfo(for: supermercado).color,
                                title: "Tienda",
                                value: supermercado,
                                isLast: false,
                                action: { showStorePicker = true }
                            )
                            // DatePicker nativo de iOS para seleccionar la fecha
                            // Equivalente Android: `DatePickerDialog` de Material Design
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

                        // Lista de productos + estado vacío + banner OCR
                        productosSection
                            .padding(.top, 24)

                        // Sección de foto del ticket con OCR opcional
                        ticketSection
                            .padding(.top, 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
        }
        .sheet(isPresented: $showStorePicker)   { StorePickerSheet(selected: $supermercado) }
        .sheet(isPresented: $showPaymentPicker) { PaymentPickerSheet(selected: $metodoPago) }
        .sheet(isPresented: $showAgregarProducto) { AgregarProductoSheet(productos: $productos) }
        // Sheet de edición de producto existente (item: opcional que actúa como trigger)
        .sheet(item: $editarProducto) { prod in
            AgregarProductoSheet(productos: $productos, editando: prod)
        }
        // ConfirmationDialog para elegir origen de la foto (cámara o galería)
        // Equivalente Android: AlertDialog con opciones de Intent de cámara/galería
        .confirmationDialog("Adjuntar ticket", isPresented: $showTicketOptions) {
            Button("Cámara") { showCamera = true }
            Button("Galería") { showGallery = true }
            Button("Cancelar", role: .cancel) {}
        }
        // PhotosPicker nativo — abre la librería de fotos del sistema
        // Equivalente Android: ActivityResultContracts.PickVisualMedia()
        .photosPicker(isPresented: $showGallery, selection: $selectedPhoto, matching: .images)
        // Cuando el usuario selecciona una foto de la galería, cargar sus datos
        .onChange(of: selectedPhoto) { _, item in
            Task {
                // `loadTransferable(type: Data.self)` es el nuevo API de iOS 16+
                // para cargar el contenido de un PhotosPickerItem de forma asíncrona
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    ticketData = data
                }
            }
        }
        // Cuando llega una imagen (cámara o galería), ejecutar OCR si está habilitado
        .onChange(of: ticketData) { _, data in
            guard let data, ocrAutomatico else { return }
            Task { await escanearTicket(data) }
        }
        // CameraPickerView en pantalla completa (fullScreenCover) para la cámara
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView(imageData: $ticketData).ignoresSafeArea()
        }
    }

    // MARK: - Header de navegación

    /// Header de la sheet con título y botones de acción.
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
            // Botón de guardar — deshabilitado si no hay productos o hay ops en curso
            Button("Guardar") { Task { await guardar() } }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(canSave ? Color.saGreen : Color.saLabel4)
                .disabled(!canSave)
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
        .padding(.bottom, 16)
    }

    // MARK: - Total animado

    /// Muestra el total de la compra con animación numérica al cambiar.
    ///
    /// `.contentTransition(.numericText())` anima el cambio de número dígito a dígito.
    /// `.animation(.spring(duration: 0.3), value: total)` activa la animación cuando `total` cambia.
    /// Equivalente Android: `CountingTextView` de terceros o `ValueAnimator`.
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
                    .contentTransition(.numericText())  // Animación de cambio de número
                    .animation(.spring(duration: 0.3), value: total)
            }
            Text(store.currencyName)
                .font(.system(size: 13))
                .foregroundStyle(Color.saLabel3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    // MARK: - Sección de productos

    /// Lista de productos en borrador con botón de agregar y banner de resultado OCR.
    private var productosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PRODUCTOS")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.saLabel3)
                    .tracking(0.2)
                    .padding(.horizontal, 4)
                Spacer()
                // Botón para abrir el sheet de agregar producto manualmente
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
                    // Estado vacío dentro de la card
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
                    // Filas de productos con opción de editar (tap) y eliminar (X)
                    ForEach(Array(productos.enumerated()), id: \.element.id) { idx, prod in
                        productoRow(prod, isLast: idx == productos.count - 1)
                    }

                    Rectangle().fill(Color.saSep).frame(height: 0.5)

                    // Footer de la card con conteo y total
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

            // Indicador de carga del OCR
            if isScanning {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8)
                    Text("Escaneando ticket…")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.saLabel3)
                }
                .padding(.horizontal, 4)
            }

            // Banner de resultado del OCR — desaparece tras 4 segundos
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

    /// Fila de un producto en borrador con acciones de editar y eliminar.
    ///
    /// - Tap en el área principal: abre `AgregarProductoSheet` en modo edición.
    /// - Tap en el botón X: elimina el producto de la lista con animación.
    @ViewBuilder
    private func productoRow(_ prod: ProductoDraft, isLast: Bool) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                // Ícono de bolsa de compras
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

                // Precio convertido a la moneda del usuario
                Text(store.convert(prod.precio).formatted(.currency(code: store.currencyCode)))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.saLabel)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.saLabel4)
            }
            .contentShape(Rectangle())
            .onTapGesture { editarProducto = prod }  // Abrir editor

            // Botón de eliminar producto de la lista
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

    // MARK: - Sección de ticket

    /// Sección para adjuntar la foto del ticket (cámara o galería).
    ///
    /// Si hay una imagen, la muestra con opción de eliminarla.
    /// Si no, muestra el botón para seleccionar origen de la foto.
    private var ticketSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TICKET")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.saLabel3)
                .tracking(0.2)
                .padding(.horizontal, 4)

            SACard(padding: 0) {
                if let data = ticketData, let img = UIImage(data: data) {
                    // Vista previa del ticket adjunto
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
                        // Botón para eliminar el ticket
                        Button { ticketData = nil } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Color.saDanger)
                        }
                    }
                    .padding(16)
                } else {
                    // Estado sin ticket: botón para adjuntar
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
                            // Subtítulo cambia según si OCR está activo
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

    // MARK: - Helper de fila con botón

    /// Fila clickeable estilo iOS Settings para la selección de tienda/pago.
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

    // MARK: - OCR del ticket

    /// Ejecuta el OCR sobre la imagen del ticket y agrega los productos detectados.
    ///
    /// Llama a `TicketOCRService.shared.extraerProductos(de:)` que usa Vision framework.
    /// Filtra productos duplicados (mismo nombre ya existente en la lista).
    /// El banner de resultado desaparece automáticamente tras 4 segundos.
    ///
    /// Equivalente Android: `BarcodeScanner` de ML Kit o `TextRecognizer.process(image)`.
    private func escanearTicket(_ data: Data) async {
        isScanning = true
        ocrDetected = nil

        // TicketOCRService usa Vision OCR on-device (sin internet)
        let encontrados = await TicketOCRService.shared.extraerProductos(de: data)
        isScanning = false

        guard !encontrados.isEmpty else { return }

        // Filtrar duplicados: no agregar productos que ya están en la lista
        let existentes = Set(productos.map { $0.nombre.lowercased() })
        let nuevos = encontrados.filter { !existentes.contains($0.nombre.lowercased()) }
        guard !nuevos.isEmpty else { return }

        withAnimation(.spring(duration: 0.3)) {
            productos.append(contentsOf: nuevos)
        }
        ocrDetected = nuevos.count  // Mostrar banner con la cantidad detectada

        // Ocultar el banner de resultado tras 4 segundos
        try? await Task.sleep(for: .seconds(4))
        withAnimation { ocrDetected = nil }
    }

    // MARK: - Guardar compra

    /// Persiste la compra en SwiftData y sincroniza con Supabase en background.
    ///
    /// Estrategia offline-first:
    /// 1. Crear objetos `Compra` y `Producto` en SwiftData.
    /// 2. Subir ticket a Supabase Storage (si hay) — fallback a `imagenTicket` local.
    /// 3. `modelContext.save()` — persiste en SQLite local.
    /// 4. `dismiss()` — el usuario ve el resultado de inmediato (no espera el sync).
    /// 5. `Task { }` — sync con Supabase en background sin bloquear la UI.
    ///
    /// Equivalente Android: `viewModelScope.launch { room.insert(compra); syncToFirestore(compra) }`.
    private func guardar() async {
        isGuardando = true
        defer { isGuardando = false }

        // Crear la entidad `Compra` con los datos del formulario
        let compra = Compra(fecha: fecha, supermercado: supermercado, total: total, metodoPago: metodoPago)

        // Asignar el userId del usuario actual para RLS (Row Level Security) en Supabase
        let uid = SessionStore.shared.currentUserID
        if !uid.isEmpty { compra.userId = uid }

        // Intentar subir el ticket a Supabase Storage
        // Fallback: guardar como Data local si el upload falla (sin conexión)
        if let data = ticketData {
            if let url = try? await SupabaseService.shared.subirTicket(data, compraID: compra.id) {
                compra.ticketURL = url          // URL firmada de Storage (1h de validez)
            } else {
                compra.imagenTicket = data       // Fallback: guardado local en SwiftData
            }
        }

        // Insertar en SwiftData local
        modelContext.insert(compra)

        // Insertar cada producto en borrador como entidad SwiftData
        for draft in productos {
            let producto = Producto(codigo: draft.codigo, nombre: draft.nombre, descripcion: draft.descripcion, precio: draft.precio)
            producto.compra = compra
            modelContext.insert(producto)
        }

        // Guardar a disco antes del sync para no perder datos si hay error de red
        try? modelContext.save()

        // Capturar valores para el Task en background (evitar capture de self/context mutables)
        let compraID       = compra.id
        let compraFecha    = compra.fecha
        let compraSupermer = compra.supermercado
        let compraTotal    = compra.total
        let compraPago     = compra.metodoPago
        let compraTicket   = compra.ticketURL
        let productosSnapshot = compra.productos.map { p in
            (id: p.id, nombre: p.nombre, descripcion: p.descripcion,
             codigo: p.codigo, precio: p.precio)
        }

        // Sync con Supabase en background (no bloquea la UI)
        Task {
            // 1. Sincronizar la compra
            do {
                try await SupabaseService.shared.crearCompra(
                    id: compraID, fecha: compraFecha, supermercado: compraSupermer,
                    total: compraTotal, metodoPago: compraPago, ticketURL: compraTicket
                )
                compra.isSynced = true
                try? modelContext.save()   // Guardar isSynced=true inmediatamente
            } catch {
                return  // Sin sesión o error de red — SyncService reintentará al iniciar
            }

            // 2. Sincronizar cada producto de forma independiente
            // Un fallo en un producto no afecta el sync de los demás
            for pd in productosSnapshot {
                do {
                    try await SupabaseService.shared.crearProducto(
                        id: pd.id, compraID: compraID, nombre: pd.nombre,
                        descripcion: pd.descripcion, codigo: pd.codigo, precio: pd.precio
                    )
                    if let prod = compra.productos.first(where: { $0.id == pd.id }) {
                        prod.isSynced = true
                    }
                } catch {
                    // Producto queda isSynced=false — SyncService reintentará al próximo arranque
                }
            }
            try? modelContext.save()
        }

        dismiss()
    }
}

// MARK: - Sheet de agregar / editar producto en borrador

/// Sheet para agregar o editar un `ProductoDraft` en la lista de nueva compra.
///
/// Se usa tanto para agregar nuevos productos como para editar existentes
/// (controlado por el parámetro `editando: ProductoDraft?`).
///
/// Equivalente Android: un `BottomSheetDialogFragment` o `AlertDialog` con campos de texto.
struct AgregarProductoSheet: View {
    /// Lista de productos en borrador del padre — se modifica directamente via Binding.
    @Binding var productos: [ProductoDraft]

    /// Producto a editar (nil si se está agregando uno nuevo).
    var editando: ProductoDraft? = nil

    @Environment(\.dismiss) private var dismiss

    // MARK: - Estado del formulario

    @State private var nombre = ""
    @State private var descripcion = ""
    @State private var precioStr = ""

    /// Precio ingresado como Double (soporta tanto "." como "," como separador decimal).
    private var precio: Double {
        Double(precioStr.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    /// El botón de confirmar requiere nombre no vacío y precio mayor a 0.
    private var canConfirm: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty && precio > 0
    }

    /// `true` si se está editando un producto existente.
    private var isEditing: Bool { editando != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.saBg.ignoresSafeArea()

                VStack(spacing: 12) {
                    SAField(placeholder: "Nombre del producto", text: $nombre, icon: "tag")
                    SAField(placeholder: "Descripción (opcional)", text: $descripcion, icon: "text.alignleft")
                    // Campo de precio con teclado numérico decimal
                    SAField(placeholder: "Precio", text: $precioStr, icon: "dollarsign")
                        .keyboardType(.decimalPad)
                        .onChange(of: precioStr) { _, v in
                            // Filtrar caracteres no numéricos (excepto punto y coma como decimal)
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
                            // Editar producto existente actualizando los campos en el binding
                            productos[idx].nombre = nombreFinal
                            productos[idx].descripcion = descripcion
                            productos[idx].precio = precio
                        } else {
                            // Agregar nuevo producto a la lista
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
            // Pre-cargar los valores del producto a editar
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

// MARK: - Sheet selector de tienda

/// Sheet que muestra la lista de supermercados disponibles para seleccionar.
///
/// Usa `List` con `Button` (no `NavigationLink`) para dismissar el sheet al seleccionar.
/// Equivalente Android: `ChoiceDialog` de Material Design o `DropdownMenu` en Compose.
struct StorePickerSheet: View {
    /// Supermercado seleccionado actualmente — se actualiza directamente al tocar.
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
                        // Checkmark en el ítem actualmente seleccionado
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

// MARK: - Sheet selector de método de pago

/// Sheet que muestra los métodos de pago disponibles para seleccionar.
///
/// Equivalente Android: `DropdownMenu` en Compose o `Spinner` en View system.
struct PaymentPickerSheet: View {
    /// Método de pago seleccionado — se actualiza directamente al tocar.
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
                        // Checkmark en el método actualmente seleccionado
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
