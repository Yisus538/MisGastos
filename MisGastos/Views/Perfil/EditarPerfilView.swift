// =============================================================================
// EditarPerfilView.swift — Formulario de edición de perfil del usuario
// =============================================================================
// Rol en la app:
//   Sheet que permite al usuario cambiar su nombre y foto de perfil.
//   El email está deshabilitado (su cambio requiere confirmación via email en
//   Supabase Auth, funcionalidad no implementada en este TP).
//   Se presenta desde `PerfilView` al tocar "Editar perfil".
//
// Equivalente Android:
//   `EditProfileActivity` o `EditProfileBottomSheet` que usa `PhotosPickerItem`
//   → `ActivityResultContracts.PickVisualMedia()` en Android (API 33+) o
//   `Intent(Intent.ACTION_PICK)` en versiones anteriores para seleccionar foto.
//   La compresión de imagen equivale a `Bitmap.compress(JPEG, quality, stream)`.
//
// Flujo de avatar:
//   1. Al abrir la sheet, carga el nombre actual y descarga el avatar si no está en caché.
//   2. El usuario puede tocar el avatar → `PhotosPicker` presenta el selector nativo.
//   3. Al seleccionar una foto, `cargarFoto()` la comprime a 300×300 JPEG (75% calidad).
//   4. Al guardar: actualiza `UserScopedStorage` localmente → sube el avatar a Supabase
//      Storage → guarda nombre y URL en la tabla `perfiles` de Supabase.
//
// Compresión con UIGraphicsImageRenderer:
//   `UIGraphicsImageRenderer` es la API moderna de UIKit para renderizar imágenes.
//   Equivalente Android: `Bitmap.createScaledBitmap()` + `compress(JPEG, quality, stream)`.
//   La imagen se escala a máximo 300×300 puntos preservando aspecto, lo que reduce
//   significativamente el tamaño de subida sin pérdida visible de calidad.
// =============================================================================

import SwiftUI
import PhotosUI  // PhotosPicker — selector nativo del sistema para fotos/videos

/// Sheet de edición de nombre y foto de perfil del usuario.
///
/// Equivalente Android: `EditProfileFragment` con `ActivityResultContracts.PickVisualMedia`.
struct EditarPerfilView: View {

    // MARK: - Entorno

    /// Permite cerrar la sheet programáticamente.
    @Environment(\.dismiss) private var dismiss

    // MARK: - Estado del formulario

    /// Store de preferencias de usuario — observado con `@State` para que SwiftUI
    /// detecte cambios y actualice la UI cuando se modifica el avatar o el nombre.
    @State private var store = UserScopedStorage.shared

    /// Copia local editable del nombre del usuario.
    @State private var nombreEdit       = ""

    /// Copia local editable del email (solo lectura en la UI).
    @State private var emailEdit        = ""

    /// Item seleccionado en `PhotosPicker`. Al cambiar, dispara `cargarFoto()`.
    ///
    /// Equivalente Android: `ActivityResultLauncher<PickVisualMediaRequest>` con
    /// `ActivityResultContracts.PickVisualMedia()`.
    @State private var photoItem:       PhotosPickerItem?

    /// `true` mientras se está guardando en Supabase.
    @State private var isSaving         = false

    /// `true` mientras se cargan los datos del perfil desde Supabase.
    @State private var isLoading        = false

    /// `true` mientras se está cargando/comprimiendo la foto seleccionada.
    @State private var isLoadingPhoto   = false

    /// `true` si el usuario cambió la foto en esta sesión de edición.
    @State private var didChangePhoto   = false

    /// Datos locales del avatar (JPEG comprimido). Se muestra en el círculo de avatar.
    @State private var avatarDataLocal: Data = Data()

    // MARK: - Iniciales para el avatar fallback

    /// Iniciales del nombre en edición para mostrar cuando no hay imagen.
    private var initials: String {
        let parts = nombreEdit.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return nombreEdit.prefix(2).uppercased().isEmpty ? "SA" : nombreEdit.prefix(2).uppercased()
    }

    // MARK: - Vista principal

    var body: some View {
        ZStack {
            Color.saBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // Botón de retroceso (dismiss de la sheet)
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.saLabel)
                            .frame(width: 36, height: 36)
                            .background(Color.saBg)
                            .clipShape(Circle())
                    }
                    .padding(.top, 56)
                    .padding(.bottom, 20)

                    Text("Editar perfil")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color.saLabel)
                        .tracking(-1)
                        .padding(.bottom, 28)

                    // MARK: Selector de foto de perfil (PhotosPicker)
                    // `PhotosPicker(selection:matching:)` presenta el selector nativo del sistema.
                    // Equivalente Android: `pickMedia.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))`.
                    // Al seleccionar una imagen, `photoItem` cambia y `.onChange(of: photoItem)` llama `cargarFoto()`.
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            avatarCircle      // Vista del avatar actual (imagen o iniciales)
                                .frame(width: 96, height: 96)

                            // Badge verde de cámara superpuesto en la esquina inferior derecha
                            Circle()
                                .fill(Color.saGreen)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.white)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                                .offset(x: 4, y: 4)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)

                    Text("Tocá para cambiar la foto")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.saLabel3)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 28)

                    // MARK: Campos de texto
                    VStack(spacing: 12) {
                        // Nombre editable
                        SAField(placeholder: "Nombre completo", text: $nombreEdit, icon: "person")

                        // Email: visible pero deshabilitado (cambio requiere verificación)
                        SAField(placeholder: "Correo electrónico", text: $emailEdit, icon: "envelope")
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .disabled(true)      // No editable en este TP
                            .opacity(0.55)       // Visual feedback de campo deshabilitado
                    }

                    // Botón de guardar — deshabilitado si el nombre está vacío o hay un proceso en curso
                    SAButton(title: "Guardar cambios", isLoading: isSaving || isLoadingPhoto) {
                        guardar()
                    }
                    .disabled(nombreEdit.isEmpty || isSaving || isLoadingPhoto)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .task {
            // Al aparecer la sheet, cargar datos locales del store
            nombreEdit      = store.nombre
            emailEdit       = store.email
            avatarDataLocal = store.avatarData

            // Intentar obtener el nombre actualizado desde Supabase (puede diferir del local)
            isLoading = true
            if let perfil = try? await SupabaseService.shared.fetchPerfil(), !perfil.nombre.isEmpty {
                nombreEdit = perfil.nombre  // Nombre remoto tiene prioridad
            }
            isLoading = false

            // Si no hay avatar en caché, intentar descargarlo de Supabase Storage
            if avatarDataLocal.isEmpty {
                if let data = await SupabaseService.shared.fetchAvatarData() {
                    avatarDataLocal = data
                    store.set(data, for: "avatarData")  // Guardar en caché local
                }
            }
        }
        // Observar cambio en la selección de foto del PhotosPicker
        .onChange(of: photoItem) { _, item in
            Task { await cargarFoto(item) }
        }
    }

    // MARK: - Vista del avatar

    /// Círculo de avatar: imagen real o iniciales con gradiente amarillo como fallback.
    @ViewBuilder
    private var avatarCircle: some View {
        if !avatarDataLocal.isEmpty, let uiImg = UIImage(data: avatarDataLocal) {
            // Imagen real: escalar y recortar en círculo
            Image(uiImage: uiImg)
                .resizable()
                .scaledToFill()
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        } else {
            // Fallback: círculo con gradiente amarillo e iniciales del nombre
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "#FEF3C7"), Color(hex: "#FBBF24")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                Text(initials)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Color(hex: "#92400E"))
            }
        }
    }

    // MARK: - Cargar foto seleccionada

    /// Carga, comprime y almacena localmente la foto seleccionada en el `PhotosPicker`.
    ///
    /// Flujo:
    /// 1. `item.loadTransferable(type: Data.self)` — carga los datos de la imagen
    ///    desde el `PhotosPickerItem`. Es asíncrono porque puede requerir descargar
    ///    de iCloud si la foto está en la nube. Equivalente Android: `uri.readBytes()`.
    /// 2. `UIImage(data:)` — convierte los bytes en una imagen UIKit.
    /// 3. `comprimirAvatar(_:)` — redimensiona y comprime a JPEG 75%.
    /// 4. `defer { isLoadingPhoto = false }` — garantiza que el flag se resetea
    ///    incluso si se produce un error. Equivalente Kotlin: `try/finally`.
    ///
    /// - Parameter item: El `PhotosPickerItem` seleccionado por el usuario (puede ser `nil`).
    private func cargarFoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }   // Se ejecuta siempre al salir, incluso con error
        guard let data = try? await item.loadTransferable(type: Data.self),
              let original = UIImage(data: data),
              let compressed = comprimirAvatar(original) else { return }
        avatarDataLocal = compressed    // Actualizar el estado local
        didChangePhoto = true           // Marcar que cambió para subir a Supabase al guardar
    }

    // MARK: - Guardar cambios

    /// Guarda el nombre localmente en `UserScopedStorage` y sincroniza con Supabase.
    ///
    /// Orden de operaciones offline-first:
    /// 1. Actualizar el nombre en `UserScopedStorage` inmediatamente (cache local).
    /// 2. Si hubo cambio de foto, subirla a Supabase Storage (`subirAvatar()`).
    /// 3. Guardar nombre y URL del avatar en la tabla `perfiles` de Supabase.
    /// 4. Dismiss de la sheet.
    ///
    /// El `Task { }` en background evita bloquear la UI mientras se hace la subida.
    /// Equivalente Android: `viewModel.saveProfile(nombre, avatarBitmap)` que llama
    /// a un `Repository` con `CoroutineScope` para el trabajo en background.
    private func guardar() {
        let nombreFinal = nombreEdit.trimmingCharacters(in: .whitespaces)
        guard !nombreFinal.isEmpty, !isSaving else { return }

        // Actualizar nombre en cache local inmediatamente (sin esperar Supabase)
        store.set(nombreFinal, for: "usuarioNombre")
        if !avatarDataLocal.isEmpty {
            store.set(avatarDataLocal, for: "avatarData")
        }

        isSaving = true
        // Capturar snapshots para usar en el Task sin riesgo de mutation race condition
        let snapData       = avatarDataLocal
        let snapDidChange  = didChangePhoto
        Task {
            var avatarURL: String? = nil
            // Solo subir la imagen si el usuario la cambió en esta sesión
            if snapDidChange && !snapData.isEmpty {
                avatarURL = try? await SupabaseService.shared.subirAvatar(snapData)
            }
            // Guardar nombre (y URL del avatar si cambió) en Supabase tabla `perfiles`
            try? await SupabaseService.shared.guardarPerfil(nombre: nombreFinal, avatarURL: avatarURL)
            isSaving = false
            dismiss()
        }
    }

    // MARK: - Comprimir avatar

    /// Redimensiona y comprime una imagen a máximo 300×300 puntos en formato JPEG 75%.
    ///
    /// Algoritmo:
    /// 1. Calcular el factor de escala para que ninguna dimensión supere 300pt.
    ///    `min(..., 1)` evita ampliar imágenes pequeñas (nunca escalar hacia arriba).
    /// 2. `UIGraphicsImageRenderer` renderiza la imagen escalada en un contexto de imagen.
    ///    Equivalente Android: `Bitmap.createScaledBitmap(original, newW, newH, true)`.
    /// 3. `.jpegData(compressionQuality: 0.75)` comprime con calidad del 75%.
    ///    Equivalente Android: `bitmap.compress(Bitmap.CompressFormat.JPEG, 75, stream)`.
    ///
    /// - Parameter image: Imagen original capturada del selector de fotos.
    /// - Returns: Datos JPEG comprimidos, o `nil` si la conversión falla.
    private func comprimirAvatar(_ image: UIImage) -> Data? {
        let maxDim: CGFloat = 300
        // Calcular factor de escala: 1.0 si la imagen ya es pequeña, menor si es grande
        let scale = min(maxDim / image.size.width, maxDim / image.size.height, 1)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        // Renderizar en el nuevo tamaño usando UIGraphicsImageRenderer (API moderna de UIKit)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: 0.75)   // 75% calidad JPEG
    }
}
