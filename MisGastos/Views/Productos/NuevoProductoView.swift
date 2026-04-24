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

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "producto.section.datos")) {
                    TextField(String(localized: "producto.codigo"), text: $codigo)
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
        dismiss()
    }
}

struct ProductoRowView: View {
    let producto: Producto
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(producto.nombre).font(.subheadline)
                if !producto.codigo.isEmpty {
                    Text(producto.codigo).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(producto.precio, format: .currency(code: "ARS"))
                .font(.subheadline).foregroundStyle(Color.saGreen)
        }
    }
}
