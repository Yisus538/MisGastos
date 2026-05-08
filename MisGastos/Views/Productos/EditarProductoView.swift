// =============================================================================
// EditarProductoView.swift — Formulario de edición de un producto existente
// =============================================================================
// Rol en la app:
//   Sheet que permite editar los campos de un `Producto` ya guardado en SwiftData:
//   código de barras, nombre, descripción y precio. Se presenta desde
//   `DetalleCompraView` al hacer long-press (context menu) en una fila de producto.
//
// Equivalente Android:
//   `EditProductDialogFragment` o `EditProductBottomSheet` que recibe el ID del
//   producto, pre-carga sus datos en `TextInputLayout`/`EditText` y al guardar
//   actualiza Room + Supabase via el ViewModel.
//
// `@Bindable` vs `@State` local:
//   A diferencia de `NuevoProductoView`, aquí usamos `@Bindable var producto: Producto`
//   (igual que `EditarCompraView`) para acceder a las propiedades del objeto SwiftData,
//   pero los campos del formulario se editan en `@State` locales (codigo, nombre, etc.)
//   para permitir cancelar sin efectos secundarios. Solo al guardar se copian al `@Bindable`.
//
// Ajuste del total de la compra:
//   Al cambiar el precio de un producto, el total de la compra debe actualizarse.
//   Se calcula el `delta = nuevoPrecio - productoAnteriorPrecio` y se suma a `compra.total`.
//   Equivalente Android: `compra.total += delta` en la Entity de Room, o una
//   query UPDATE en el DAO.
//
// Inicializador custom con `_precioStr`:
//   El precio se muestra sin decimales si es entero (ej: "1500" en lugar de "1500.00"),
//   o con 2 decimales si tiene centavos (ej: "1500.50"). Esta lógica requiere
//   un `init()` personalizado para inicializar el `@State` con el formato correcto.
// =============================================================================

import SwiftUI
import SwiftData

/// Formulario de edición de un producto existente en una compra.
///
/// Equivalente Android: `EditProductFragment` con `viewModel.updateProducto(id, datos)`.
struct EditarProductoView: View {

    // MARK: - Dato principal

    /// Entidad `Producto` de SwiftData — los cambios se aplican al confirmar.
    @Bindable var producto: Producto

    /// La compra a la que pertenece el producto — para actualizar su total.
    let compra: Compra

    /// Cierra el formulario al guardar o cancelar.
    @Environment(\.dismiss) private var dismiss

    // MARK: - Estado local del formulario (edición sin afectar el original hasta guardar)

    /// Copia local del código de barras para edición.
    @State private var codigo: String

    /// Copia local del nombre para edición.
    @State private var nombre: String

    /// Copia local de la descripción para edición.
    @State private var descripcion: String

    /// Copia local del precio como string editable.
    @State private var precioStr: String

    /// Controla si se presenta el escáner de código de barras.
    @State private var showScanner = false

    // MARK: - Inicializador

    /// Inicializa los `@State` locales con los valores actuales del producto.
    ///
    /// El precio se formatea sin decimales si es entero (ej: "1500") o con
    /// 2 decimales si tiene centavos (ej: "1500.50"), para mejor UX en el teclado numérico.
    ///
    /// El prefijo `_` (ej: `self._codigo`) accede al storage subyacente del property
    /// wrapper `@State`, necesario para inicialización en el `init`.
    init(producto: Producto, compra: Compra) {
        self._producto = Bindable(producto)
        self.compra = compra
        // Inicializar los @State con los valores actuales del producto
        self._codigo = State(initialValue: producto.codigo)
        self._nombre = State(initialValue: producto.nombre)
        self._descripcion = State(initialValue: producto.descripcion)
        // Formatear precio: sin decimales si es entero, con .2f si tiene centavos
        let p = producto.precio
        let str = p.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(p))
            : String(format: "%.2f", p)
        self._precioStr = State(initialValue: str)
    }

    // MARK: - Validación

    /// El formulario es válido si el nombre no está vacío y el precio es mayor a 0.
    private var canSave: Bool {
        !nombre.isEmpty && (Double(precioStr.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
    }

    // MARK: - Vista principal

    var body: some View {
        NavigationStack {
            // `Form` nativo de SwiftUI — equivalente a formulario con `TextInputLayout` en Android
            Form {
                Section(String(localized: "producto.section.datos")) {
                    // Campo de código de barras con botón de escáner
                    HStack {
                        TextField(String(localized: "producto.codigo"), text: $codigo)
                        // Botón del escáner AVFoundation — equivalente a CameraX + ML Kit en Android
                        Button(action: { showScanner = true }) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.saGreen)
                        }
                        .buttonStyle(.plain)
                    }

                    TextField(String(localized: "producto.nombre"), text: $nombre)
                    TextField(String(localized: "producto.descripcion"), text: $descripcion)

                    // Campo de precio con teclado numérico
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
                // Botón Cancelar — cierra sin guardar (los @State locales se descartan)
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                // Botón Guardar — deshabilitado si no hay nombre o el precio es inválido
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

    // MARK: - Guardar cambios

    /// Aplica los cambios al producto y ajusta el total de la compra.
    ///
    /// Flujo:
    /// 1. Parsear el nuevo precio desde el texto del campo.
    /// 2. Calcular el `delta` entre el precio nuevo y el anterior.
    ///    `delta > 0` → el producto subió de precio → el total de la compra sube.
    ///    `delta < 0` → el producto bajó de precio → el total de la compra baja.
    /// 3. Actualizar las propiedades del `@Bindable var producto`.
    ///    SwiftData detecta los cambios en `@Model` properties y los persiste automáticamente
    ///    sin necesidad de llamar `modelContext.save()` explícitamente.
    /// 4. Dismiss inmediato (la UI se actualiza en tiempo real via SwiftData).
    /// 5. `Task { }` sincroniza con Supabase en background.
    ///
    /// Equivalente Android: `viewModel.updateProducto(delta)` en una coroutina que
    /// hace `dao.updateProducto(entity)` y luego `supabaseService.actualizarProducto(dto)`.
    private func guardar() {
        guard let nuevoPrecio = Double(precioStr.replacingOccurrences(of: ",", with: ".")) else { return }

        // Calcular la diferencia de precio para ajustar el total de la compra
        let delta = nuevoPrecio - producto.precio

        // Actualizar el @Bindable (se persiste en SwiftData automáticamente)
        producto.codigo = codigo
        producto.nombre = nombre
        producto.descripcion = descripcion
        producto.precio = nuevoPrecio

        // Ajustar el total de la compra sumando el delta del precio
        compra.total += delta

        // Capturar IDs antes del Task para evitar retener objetos SwiftData en la closure
        let pid = producto.id
        let cid = compra.id
        let pNombre = nombre
        let pDesc = descripcion
        let pCodigo = codigo

        // Sincronizar actualización con Supabase en background
        Task {
            try? await SupabaseService.shared.actualizarProducto(
                id: pid, compraID: cid,
                nombre: pNombre, descripcion: pDesc,
                codigo: pCodigo, precio: nuevoPrecio
            )
        }

        dismiss()
    }
}
