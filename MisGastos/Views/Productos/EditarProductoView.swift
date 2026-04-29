import SwiftUI
import SwiftData

struct EditarProductoView: View {
    @Bindable var producto: Producto
    let compra: Compra
    @Environment(\.dismiss) private var dismiss

    @State private var codigo: String
    @State private var nombre: String
    @State private var descripcion: String
    @State private var precioStr: String
    @State private var showScanner = false

    init(producto: Producto, compra: Compra) {
        self._producto = Bindable(producto)
        self.compra = compra
        self._codigo = State(initialValue: producto.codigo)
        self._nombre = State(initialValue: producto.nombre)
        self._descripcion = State(initialValue: producto.descripcion)
        let p = producto.precio
        let str = p.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(p))
            : String(format: "%.2f", p)
        self._precioStr = State(initialValue: str)
    }

    private var canSave: Bool {
        !nombre.isEmpty && (Double(precioStr.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
    }

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
            .navigationTitle("Editar producto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save")) { guardar() }
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerView { code in codigo = code }
            }
        }
    }

    private func guardar() {
        guard let nuevoPrecio = Double(precioStr.replacingOccurrences(of: ",", with: ".")) else { return }
        let delta = nuevoPrecio - producto.precio
        producto.codigo = codigo
        producto.nombre = nombre
        producto.descripcion = descripcion
        producto.precio = nuevoPrecio
        compra.total += delta
        dismiss()
    }
}
