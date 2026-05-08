// =============================================================================
// DetalleCompraView.swift — Pantalla de detalle de una compra
// =============================================================================
// Rol en la app:
//   Muestra el detalle completo de una compra: header con el color del supermercado,
//   foto del ticket, lista de productos con opciones de editar/eliminar, y botones
//   de compartir y eliminar la compra completa.
//   Se navega aquí desde `HomeView` y `HistorialView` tocando una compra.
//
// Equivalente Android:
//   `DetailActivity` o `DetailFragment` que recibe un `compraId` como argumento
//   y carga el detalle via ViewModel desde Room.
//   En Compose: `@Composable fun CompraDetailScreen(compraId: UUID)`.
//
// @Bindable:
//   `@Bindable var compra: Compra` permite leer y escribir propiedades de la
//   entidad SwiftData directamente. SwiftData notifica los cambios a SwiftUI
//   automáticamente (a diferencia de `let` que sería solo lectura).
//   Equivalente Android: `viewModel.compra.collect { }` con `MutableStateFlow`.
//
// ShareLink:
//   `ShareLink(item: String)` es el componente nativo de SwiftUI (iOS 16+) para
//   compartir texto, URLs e imágenes. Abre la Share Sheet del sistema.
//   Equivalente Android: `Intent.ACTION_SEND` con `Intent.createChooser()`.
//
// AsyncImage:
//   `AsyncImage(url: URL)` carga y muestra imágenes desde URLs de forma asíncrona
//   y con caché automático. Equivalente Android: `Coil` o `Glide` en Compose.
//   Aquí se usa para mostrar el ticket desde Supabase Storage.
//   Si la URL firmada expiró (1h de validez), cae back a la imagen local.
//
// Context Menu:
//   `.contextMenu { }` presenta un menú contextual al hacer long press sobre un ítem.
//   Equivalente Android: `onLongClick` con un `PopupMenu` o `ContextMenu`.
// =============================================================================

import SwiftUI
import PhotosUI
import SwiftData

/// Vista de detalle de una compra con ticket, productos y acciones.
///
/// Equivalente Android: `CompraDetailFragment` con `RecyclerView` de productos.
struct DetalleCompraView: View {

    // MARK: - Dato principal

    /// Entidad `Compra` de SwiftData — `@Bindable` permite modificarla directamente.
    ///
    /// `@Bindable` (Swift 5.9+) reemplaza el patrón `@Binding` para entidades `@Observable`.
    /// Permite crear bindings (`$compra.campo`) para pasarlos a subvistas que editan el dato.
    @Bindable var compra: Compra

    // MARK: - Dependencias

    /// Contexto de SwiftData para eliminar la compra o sus productos.
    @Environment(\.modelContext) private var modelContext

    /// Dismisses la vista al eliminar la compra o al tocar el botón de volver.
    @Environment(\.dismiss) private var dismiss

    // MARK: - Estado de presentación de sheets

    /// Presenta `NuevoProductoView` para agregar un producto a esta compra.
    @State private var showNuevoProducto = false

    /// Presenta la alerta de confirmación de eliminación de la compra.
    @State private var showDeleteAlert = false

    /// Presenta `EditarCompraView` para editar los datos de la compra.
    @State private var showEditar = false

    /// Producto seleccionado para editar (al tocar una fila o el context menu).
    @State private var productoSeleccionado: Producto?

    // MARK: - Ticket

    /// Ítem de `PhotosPicker` seleccionado al cambiar el ticket desde la galería.
    @State private var selectedPhoto: PhotosPickerItem?

    /// Muestra el `confirmationDialog` de origen de foto.
    @State private var showTicketOptions = false

    /// Presenta `CameraPickerView` para tomar foto del ticket.
    @State private var showCamera = false

    /// Presenta el `PhotosPicker` nativo para la galería.
    @State private var showGallery = false

    // MARK: - Preferencias

    /// Preferencias de moneda y conversión del usuario.
    @State private var store = UserScopedStorage.shared

    // MARK: - Helpers

    /// Color e iniciales del supermercado de la compra (para el header).
    private var storeInfo: SAStoreInfo { saStoreInfo(for: compra.supermercado) }

    /// Altura de la status bar para el padding del header custom.
    private var statusBarHeight: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.top }
            .first ?? 44
    }

    // MARK: - Vista principal

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header con color del supermercado y datos principales
                    storeHeader

                    // Contenido: ticket, productos y acciones
                    content
                        .padding(.top, 20)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 140)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showNuevoProducto) { NuevoProductoView(compra: compra) }
        .sheet(isPresented: $showEditar) { EditarCompraView(compra: compra) }
        // Sheet de edición de producto — `item:` se presenta cuando `productoSeleccionado` no es nil
        .sheet(item: $productoSeleccionado) { EditarProductoView(producto: $0, compra: compra) }
        // Alerta de confirmación de eliminación de la compra completa
        .alert("Eliminar compra", isPresented: $showDeleteAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                let compraID = compra.id
                modelContext.delete(compra)   // Eliminar de SwiftData local (cascade a productos)
                // Eliminar en Supabase en background
                Task { try? await SupabaseService.shared.borrarCompra(id: compraID) }
                dismiss()
            }
        } message: {
            Text("¿Estás seguro? Esta acción no se puede deshacer.")
        }
        // Dialog de origen de foto del ticket
        .confirmationDialog("Adjuntar ticket", isPresented: $showTicketOptions) {
            Button("Cámara") { showCamera = true }
            Button("Galería") { showGallery = true }
            Button("Cancelar", role: .cancel) {}
        }
        .photosPicker(isPresented: $showGallery, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, item in
            Task { compra.imagenTicket = try? await item?.loadTransferable(type: Data.self) }
        }
        // CameraPickerView — escribe directamente en `compra.imagenTicket` via @Bindable
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView(imageData: $compra.imagenTicket)
                .ignoresSafeArea()
        }
    }

    // MARK: - Header con color del supermercado

    /// Header con gradiente del color de la cadena y datos de la compra.
    ///
    /// Usa el color de `saStoreInfo(for:)` para el gradiente — cada supermercado
    /// tiene su color de marca (rojo Coto, azul Carrefour, verde Jumbo, etc.).
    private var storeHeader: some View {
        ZStack(alignment: .topLeading) {
            // Gradiente con el color de la cadena
            LinearGradient(
                stops: [
                    .init(color: storeInfo.color.opacity(0.93), location: 0),
                    .init(color: storeInfo.color, location: 1),
                ],
                startPoint: UnitPoint(x: 0.2, y: 0),
                endPoint: UnitPoint(x: 0.8, y: 1)
            )

            // Círculo decorativo semitransparente
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 220, height: 220)
                .offset(x: 120, y: -80)

            VStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: statusBarHeight)

                HStack {
                    // Botón de volver
                    Button(action: { dismiss() }) {
                        Circle()
                            .fill(Color.white.opacity(0.22))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                            )
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        // Botón de editar la compra
                        Button(action: { showEditar = true }) {
                            Circle()
                                .fill(Color.white.opacity(0.22))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "pencil")
                                        .font(.system(size: 15))
                                        .foregroundStyle(.white)
                                )
                        }
                        // ShareLink — abre la Share Sheet del sistema con el resumen de la compra
                        // Equivalente Android: Intent.ACTION_SEND
                        ShareLink(
                            item: resumen(),
                            subject: Text("Mi compra"),
                            message: Text("Desde Súper Ahorro")
                        ) {
                            Circle()
                                .fill(Color.white.opacity(0.22))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 15))
                                        .foregroundStyle(.white)
                                )
                        }
                    }
                }

                // Datos de la compra en el header
                VStack(alignment: .leading, spacing: 0) {
                    SAStoreAvatar(name: compra.supermercado, size: 56)
                        .padding(.top, 20)

                    Text(compra.supermercado)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                        .tracking(-0.8)
                        .padding(.top, 12)

                    Text(compra.fecha.formatted(date: .long, time: .omitted))
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.top, 2)

                    // Total convertido a la moneda del usuario
                    Text(store.convert(compra.total).formatted(.currency(code: store.currencyCode)))
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white)
                        .tracking(-1.3)
                        .padding(.top, 18)

                    HStack(spacing: 14) {
                        Text("\(compra.productos.count) productos")
                        Text("·")
                        Text(compra.metodoPago)
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .padding(.horizontal, 20)
        }
        // Esquinas inferiores redondeadas
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 28,
                bottomTrailingRadius: 28, topTrailingRadius: 0
            )
        )
    }

    // MARK: - Contenido principal

    /// Sección de ticket, lista de productos y botones de acción.
    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            // Sección del ticket
            sectionLabel("TICKET")
            SACard(padding: 0) {
                // Mostrar ticket desde Supabase Storage (URL firmada) o imagen local
                if let urlStr = compra.ticketURL, let url = URL(string: urlStr) {
                    // AsyncImage carga la imagen desde la URL de Supabase Storage
                    // Equivalente Android: Coil con `AsyncImage` en Compose
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFit()
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .padding(16)
                        case .failure:
                            // URL firmada vencida (1h de validez) → fallback a imagen local
                            if let data = compra.imagenTicket, let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable().scaledToFit()
                                    .frame(maxHeight: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .padding(16)
                            } else {
                                Label("Imagen no disponible", systemImage: "photo.slash")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.saLabel3)
                                    .padding(20)
                            }
                        default:
                            ProgressView().padding(20)
                        }
                    }
                } else if let data = compra.imagenTicket, let img = UIImage(data: data) {
                    // Ticket guardado localmente (fallback cuando Storage falla)
                    Image(uiImage: img)
                        .resizable().scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(16)
                }
                // Botón para adjuntar o cambiar la foto del ticket
                Button { showTicketOptions = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .foregroundStyle(Color.saGreen)
                        Text((compra.imagenTicket == nil && compra.ticketURL == nil) ? "Adjuntar ticket" : "Cambiar foto")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.saGreen)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 20)

            // Sección de productos
            sectionLabel("PRODUCTOS (\(compra.productos.count))")

            SACard(padding: 0) {
                ForEach(Array(compra.productos.enumerated()), id: \.element.id) { idx, producto in
                    // Tap en una fila: abrir editor del producto
                    Button(action: { productoSeleccionado = producto }) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(producto.nombre)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Color.saLabel)
                                    .tracking(-0.2)
                                // Código de barras del producto (si existe)
                                if !producto.codigo.isEmpty {
                                    Text(producto.codigo)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.saLabel3)
                                }
                            }
                            Spacer()
                            Text(store.convert(producto.precio).formatted(.currency(code: store.currencyCode)))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.saLabel)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.saLabel4)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .overlay(alignment: .bottom) {
                            if idx < compra.productos.count - 1 {
                                Rectangle().fill(Color.saSep).frame(height: 0.5).padding(.leading, 16)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    // Long press: menú contextual con Editar y Eliminar
                    // Equivalente Android: onLongClick con PopupMenu
                    .contextMenu {
                        Button { productoSeleccionado = producto } label: {
                            Label("Editar", systemImage: "pencil")
                        }
                        Divider()
                        Button(role: .destructive) { eliminarProducto(producto) } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                    }
                }

                // Botón de agregar producto
                Button(action: { showNuevoProducto = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill").foregroundStyle(Color.saGreen)
                        Text("Agregar producto")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.saGreen)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                // Separador superior solo si hay productos
                .overlay(alignment: .top) {
                    if !compra.productos.isEmpty {
                        Rectangle().fill(Color.saSep).frame(height: 0.5)
                    }
                }
            }
            .padding(.bottom, 20)

            // Botones de acción: Compartir y Eliminar
            HStack(spacing: 10) {
                // ShareLink — comparte el resumen de la compra como texto
                // Equivalente Android: Intent.ACTION_SEND con tipo text/plain
                ShareLink(
                    item: resumen(),
                    subject: Text("Mi compra"),
                    message: Text("Desde Súper Ahorro")
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Compartir")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.saLabel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color.saCard, in: RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
                }

                // Botón de eliminar compra completa
                Button(action: { showDeleteAlert = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                        Text("Eliminar")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.saDanger)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color.saDanger.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helper de label de sección

    /// Etiqueta de sección estilo iOS Settings (texto en mayúsculas, gris, tracking).
    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.saLabel3)
            .tracking(0.2)
            .padding(.horizontal, 4)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Eliminar producto

    /// Elimina un producto de la compra, ajusta el total y sincroniza con Supabase.
    ///
    /// Orden de operaciones:
    /// 1. Restar el precio del producto al total de la compra.
    /// 2. Remover de la relación SwiftData.
    /// 3. Eliminar la entidad del contexto (cascade de SwiftData).
    /// 4. Sincronizar con Supabase en background.
    ///
    /// Equivalente Android: `viewModel.deleteProducto(id)` que actualiza Room y
    /// luego llama `repository.deleteRemote(id)` en una coroutina.
    private func eliminarProducto(_ producto: Producto) {
        let productoID = producto.id
        compra.total = max(0, compra.total - producto.precio)   // Ajustar total
        compra.productos.removeAll { $0.id == producto.id }     // Remover de la relación
        modelContext.delete(producto)                            // Eliminar de SwiftData
        // Eliminar en Supabase en background
        Task { try? await SupabaseService.shared.borrarProducto(id: productoID) }
    }

    // MARK: - Resumen para compartir

    /// Genera el texto de resumen de la compra para compartir por ShareLink.
    ///
    /// Equivalente Android: el string que se pasa a `Intent.EXTRA_TEXT` del Intent de compartir.
    private func resumen() -> String {
        "Compra en \(compra.supermercado)\nFecha: \(compra.fecha.formatted())\nTotal: \(store.convert(compra.total).formatted(.currency(code: store.currencyCode)))\nMétodo: \(compra.metodoPago)\nProductos: \(compra.productos.count)"
    }
}
