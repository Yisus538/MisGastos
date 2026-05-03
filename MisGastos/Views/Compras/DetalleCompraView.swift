import SwiftUI
import PhotosUI
import SwiftData

struct DetalleCompraView: View {
    @Bindable var compra: Compra
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showNuevoProducto = false
    @State private var showDeleteAlert = false
    @State private var showEditar = false
    @State private var productoSeleccionado: Producto?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showTicketOptions = false
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var store = UserScopedStorage.shared

    private var storeInfo: SAStoreInfo { saStoreInfo(for: compra.supermercado) }

    private var statusBarHeight: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.top }
            .first ?? 44
    }

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    storeHeader
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
        .sheet(item: $productoSeleccionado) { EditarProductoView(producto: $0, compra: compra) }
        .alert("Eliminar compra", isPresented: $showDeleteAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                let compraID = compra.id
                modelContext.delete(compra)
                Task { try? await SupabaseService.shared.borrarCompra(id: compraID) }
                dismiss()
            }
        } message: {
            Text("¿Estás seguro? Esta acción no se puede deshacer.")
        }
        .confirmationDialog("Adjuntar ticket", isPresented: $showTicketOptions) {
            Button("Cámara") { showCamera = true }
            Button("Galería") { showGallery = true }
            Button("Cancelar", role: .cancel) {}
        }
        .photosPicker(isPresented: $showGallery, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, item in
            Task { compra.imagenTicket = try? await item?.loadTransferable(type: Data.self) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView(imageData: $compra.imagenTicket)
                .ignoresSafeArea()
        }
    }

    // MARK: - Store Color Gradient Header
    private var storeHeader: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                stops: [
                    .init(color: storeInfo.color.opacity(0.93), location: 0),
                    .init(color: storeInfo.color, location: 1),
                ],
                startPoint: UnitPoint(x: 0.2, y: 0),
                endPoint: UnitPoint(x: 0.8, y: 1)
            )

            // Decorative blob
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 220, height: 220)
                .offset(x: 120, y: -80)

            VStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: statusBarHeight)

                HStack {
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
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 28,
                bottomTrailingRadius: 28, topTrailingRadius: 0
            )
        )
    }

    // MARK: - Content
    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            // Ticket section — siempre visible para permitir adjuntar/cambiar foto
            sectionLabel("TICKET")
            SACard(padding: 0) {
                if let urlStr = compra.ticketURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFit()
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .padding(16)
                        default:
                            ProgressView().padding(20)
                        }
                    }
                } else if let data = compra.imagenTicket, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable().scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(16)
                }
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

            // Products
            sectionLabel("PRODUCTOS (\(compra.productos.count))")

            SACard(padding: 0) {
                ForEach(Array(compra.productos.enumerated()), id: \.element.id) { idx, producto in
                    Button(action: { productoSeleccionado = producto }) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(producto.nombre)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Color.saLabel)
                                    .tracking(-0.2)
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
                .overlay(alignment: .top) {
                    if !compra.productos.isEmpty {
                        Rectangle().fill(Color.saSep).frame(height: 0.5)
                    }
                }
            }
            .padding(.bottom, 20)

            // Actions
            HStack(spacing: 10) {
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

    private func eliminarProducto(_ producto: Producto) {
        let productoID = producto.id
        compra.total = max(0, compra.total - producto.precio)
        compra.productos.removeAll { $0.id == producto.id }
        modelContext.delete(producto)
        Task { try? await SupabaseService.shared.borrarProducto(id: productoID) }
    }

    private func resumen() -> String {
        "Compra en \(compra.supermercado)\nFecha: \(compra.fecha.formatted())\nTotal: \(store.convert(compra.total).formatted(.currency(code: store.currencyCode)))\nMétodo: \(compra.metodoPago)\nProductos: \(compra.productos.count)"
    }
}
