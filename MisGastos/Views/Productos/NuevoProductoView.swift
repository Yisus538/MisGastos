// =============================================================================
// NuevoProductoView.swift — Formulario para agregar un producto a una compra
// =============================================================================
// Rol en la app:
//   Sheet que permite al usuario agregar un nuevo producto a una compra ya
//   creada (desde `DetalleCompraView`). Usa el formulario estándar de iOS (`Form`)
//   con campos para código de barras, nombre, descripción y precio.
//   Al guardar: inserta el `Producto` en SwiftData, lo agrega a la relación de la
//   compra, actualiza el total, y sincroniza con Supabase en background.
//
// Equivalente Android:
//   Un `DialogFragment` o `BottomSheetDialogFragment` con un `TextInputLayout`
//   por campo. Al guardar, llama a `viewModel.addProducto(compraId, datos)` que
//   inserta en Room y luego en Firestore/Supabase en background.
//
// `Form` vs diseño custom:
//   Esta view usa el `Form` nativo de SwiftUI (que genera un `InsetGroupedListStyle`
//   en iOS 16+) porque es un formulario auxiliar de bajo uso. Las views principales
//   de la app (HomeView, HistorialView, etc.) usan diseño completamente custom con
//   `VStack` + `SACard`. `Form` equivale a `RecyclerView` con `EditText` en Android.
//
// `String(localized:)` — Localización:
//   Los títulos de campos usan `String(localized: "clave")` para soporte multi-idioma
//   con `Localizable.xcstrings` (formato moderno de Xcode 15+). Equivalente Android:
//   `getString(R.string.clave)` o el uso directo de `@StringRes` en Compose.
//
// `ProductoRowView`:
//   Componente de fila reutilizable para mostrar un producto en `DetalleCompraView`.
//   Definido en este mismo archivo porque está íntimamente relacionado con `Producto`.
// =============================================================================

import SwiftUI
import SwiftData

/// Formulario para agregar un nuevo producto a una compra existente.
///
/// Equivalente Android: `AddProductDialogFragment` con `ViewModel.addProducto()`.
struct NuevoProductoView: View {

    // MARK: - Entorno y datos

    /// Contexto de SwiftData — para insertar el nuevo `Producto`.
    @Environment(\.modelContext) private var modelContext

    /// Cierra el formulario al guardar o cancelar.
    @Environment(\.dismiss) private var dismiss

    /// La compra a la que se agregará el producto (relación uno-a-muchos).
    let compra: Compra

    // MARK: - Estado del formulario

    /// Código de barras del producto (se puede escanear o ingresar manualmente).
    @State private var codigo = ""

    /// Nombre del producto — campo obligatorio para poder guardar.
    @State private var nombre = ""

    /// Descripción o categoría del producto (opcional).
    @State private var descripcion = ""

    /// Precio del producto como texto editable (se parsea a `Double` al guardar).
    @State private var precioStr = ""

    /// Controla si se presenta el escáner de código de barras.
    @State private var showScanner = false

    /// Preferencias de moneda para mostrar precios en la fila de producto.
    @State private var store = UserScopedStorage.shared

    // MARK: - Vista principal

    var body: some View {
        NavigationStack {
            // `Form` genera un listado agrupado estilo iOS Settings/Formulario.
            // Equivalente Android: `RecyclerView` con `TextInputLayout` o `TextInput` en Compose.
            Form {
                Section(String(localized: "producto.section.datos")) {
                    // Campo de código de barras con botón de escáner
                    HStack {
                        TextField(String(localized: "producto.codigo"), text: $codigo)
                        // Botón que presenta `BarcodeScannerView` — usa AVFoundation para la cámara.
                        // Equivalente Android: botón que lanza `CameraX` con `BarcodeScanning` de ML Kit.
                        Button(action: { showScanner = true }) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.saGreen)
                        }
                        .buttonStyle(.plain)
                    }

                    // Campo de nombre — obligatorio para habilitar el botón "Guardar"
                    TextField(String(localized: "producto.nombre"), text: $nombre)

                    // Campo de descripción — opcional
                    TextField(String(localized: "producto.descripcion"), text: $descripcion)

                    // Campo de precio con teclado numérico
                    HStack {
                        Text(String(localized: "producto.precio"))
                        TextField("0.00", text: $precioStr)
                            .keyboardType(.decimalPad)            // Teclado sin letras
                            .multilineTextAlignment(.trailing)    // Alineado a la derecha
                    }
                }
            }
            .navigationTitle(String(localized: "producto.nuevo.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Botón Cancelar — cierra sin guardar
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                // Botón Guardar — deshabilitado si faltan datos obligatorios
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save")) { guardar() }
                        .disabled(nombre.isEmpty || precioStr.isEmpty)
                }
            }
            // Presentar el escáner de código de barras
            .sheet(isPresented: $showScanner) {
                // Al escanear, el código queda en `codigo` y se cierra el escáner
                BarcodeScannerView { code in codigo = code }
            }
        }
    }

    // MARK: - Guardar producto

    /// Crea y persiste el nuevo producto en SwiftData y lo sincroniza con Supabase.
    ///
    /// Flujo offline-first:
    /// 1. Parsear el precio (reemplazando coma por punto para soporte de locales).
    /// 2. Crear instancia `Producto` y llamar `modelContext.insert()`.
    ///    Esto agrega el objeto al contexto en memoria.
    /// 3. Agregar el producto a la relación `compra.productos` — SwiftData maneja
    ///    automáticamente la relación inversa `producto.compra`.
    /// 4. Actualizar `compra.total` con el precio del nuevo producto.
    /// 5. `modelContext.save()` — persiste todos los cambios en el SQLite local.
    /// 6. Dismiss inmediato (sin esperar a Supabase).
    /// 7. `Task { }` sincroniza en background con Supabase.
    ///    Si falla, el producto queda en SwiftData con `isSynced = false`.
    ///
    /// Equivalente Android: `viewModel.addProducto()` que inserta en Room
    /// y luego llama a `repository.crearProductoRemoto()` en una coroutina.
    private func guardar() {
        // Parsear precio — acepta tanto "1234.56" como "1234,56"
        guard let precio = Double(precioStr.replacingOccurrences(of: ",", with: ".")) else { return }

        let producto = Producto(
            codigo: codigo,
            nombre: nombre,
            descripcion: descripcion,
            precio: precio
        )

        // Insertar en el contexto de SwiftData (equivalente a Room DAO insert)
        modelContext.insert(producto)

        // Agregar a la relación de la compra y actualizar el total
        compra.productos.append(producto)
        compra.total += precio

        // Persistir en SQLite local
        try? modelContext.save()

        // Capturar IDs antes del Task para evitar retener referencias a objetos SwiftData
        let pid = producto.id
        let cid = compra.id
        let pNombre = nombre
        let pDesc = descripcion
        let pCodigo = codigo

        // Sincronizar con Supabase en background (sin bloquear la UI)
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

// MARK: - Fila de producto reutilizable

/// Fila de producto para usar en `DetalleCompraView` u otras listas.
///
/// Muestra el nombre, código de barras (si tiene) y precio formateado
/// en la moneda del usuario.
///
/// Equivalente Android: un `ViewHolder` en un `RecyclerView.Adapter`
/// con `productName`, `productCode` y `productPrice` como `TextView`.
struct ProductoRowView: View {
    /// El producto a mostrar.
    let producto: Producto

    /// Preferencias de moneda para el formateo del precio.
    @State private var store = UserScopedStorage.shared

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(producto.nombre).font(.subheadline)
                // El código solo se muestra si no está vacío (es opcional)
                if !producto.codigo.isEmpty {
                    Text(producto.codigo).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            // Precio convertido a la moneda del usuario y formateado
            Text(store.convert(producto.precio), format: .currency(code: store.currencyCode))
                .font(.subheadline).foregroundStyle(Color.saGreen)
        }
    }
}
