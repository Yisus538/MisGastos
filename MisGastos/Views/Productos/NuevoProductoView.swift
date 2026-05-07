import SwiftUI
import SwiftData

struct NuevoProductoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let compra: Compra

    @State private var codigo = ""
    @State private var nombre = ""
    @State private var descripcion = ""
    @State private var precioStr = ""
    @State private var showScanner = false
    @State private var store = UserScopedStorage.shared

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "producto.section.datos")) {
                    HStack {
                        TextField(String(localized: "producto.codigo"), text: $codigo)
                        Button(action: { showScanner = true }) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.saGreen)
                        }
                        .buttonStyle(.plain)
                    }
                    TextField(String(localized: "producto.nombre"), text: $nombre)
                    TextField(String(localized: "producto.descripcion"), text: $descripcion)
                    HStack {
                        Text(String(localized: "producto.precio"))
                        TextField("0.00", text: $precioStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle(String(localized: "producto.nuevo.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save")) { guardar() }
                        .disabled(nombre.isEmpty || precioStr.isEmpty)
                }
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerView { code in codigo = code }
            }
        }
    }

    private func guardar() {
        guard let precio = Double(precioStr.replacingOccurrences(of: ",", with: ".")) else { return }
        let producto = Producto(
            codigo: codigo,
            nombre: nombre,
            descripcion: descripcion,
            precio: precio
        )
        modelContext.insert(producto)
        compra.productos.append(producto)
        compra.total += precio
        try? modelContext.save()

        let pid = producto.id
        let cid = compra.id
        let pNombre = nombre
        let pDesc = descripcion
        let pCodigo = codigo
        Task {
            try? await SupabaseService.shared.crearProducto(
                id: pid, compraID: cid,
                nombre: pNombre, descripcion: pDesc,
                codigo: pCodigo, precio: precio
            )
        }

        dismiss()
    }
}

struct ProductoRowView: View {
    let producto: Producto
    @State private var store = UserScopedStorage.shared
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(producto.nombre).font(.subheadline)
                if !producto.codigo.isEmpty {
                    Text(producto.codigo).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(store.convert(producto.precio), format: .currency(code: store.currencyCode))
                .font(.subheadline).foregroundStyle(Color.saGreen)
        }
    }
}
