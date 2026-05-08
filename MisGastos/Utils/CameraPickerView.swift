// =============================================================================
// CameraPickerView.swift — Puente entre SwiftUI y UIImagePickerController
// =============================================================================
// Rol en la app:
//   Presenta la cámara del dispositivo para que el usuario fotografíe el ticket
//   de la compra. La imagen se comprime a JPEG 80% y se devuelve como `Data`
//   a través del binding `imageData`.
//
// Equivalente Android:
//   `Camera Intent` con `Intent(MediaStore.ACTION_IMAGE_CAPTURE)` lanzado
//   desde `startActivityForResult()`, o la API moderna con `registerForActivityResult
//   (ActivityResultContracts.TakePicture())`. Para control completo de la cámara
//   se usaría `CameraX`.
//
// UIViewControllerRepresentable:
//   Es el mecanismo de iOS para integrar ViewControllers de UIKit (el framework
//   de UI legacy) dentro de vistas SwiftUI. Requiere implementar:
//   - `makeUIViewController`: crea e inicializa el ViewController.
//   - `updateUIViewController`: actualiza cuando cambian las props (opcional).
//   - `makeCoordinator`: crea el Coordinator que actúa como delegate.
//
//   Equivalente Android: no hay un equivalente directo. En Android todos los
//   componentes de UI ya son modernos (Compose o View), y la integración de
//   Views antiguas en Compose se hace con `AndroidView { }`.
//
// Coordinator pattern:
//   El `Coordinator` es una clase intermedia que implementa los protocolos
//   delegate de UIKit. Es necesario porque los delegates de UIKit usan el
//   patrón callback (herencia de Objective-C) que no es compatible con SwiftUI.
// =============================================================================

import SwiftUI
import UIKit

/// Vista SwiftUI que presenta la cámara nativa del dispositivo usando UIImagePickerController.
///
/// `UIViewControllerRepresentable` es el puente entre SwiftUI y UIKit,
/// necesario para usar controladores de UIKit que no tienen equivalente SwiftUI nativo.
/// Equivalente Android: `AndroidView` en Compose para integrar Views antiguas.
struct CameraPickerView: UIViewControllerRepresentable {

    // MARK: - Propiedades

    /// Binding donde se almacenará la imagen capturada como Data JPEG.
    /// `@Binding` crea una referencia bidireccional — equivalente Android:
    /// `MutableStateFlow` compartido entre el composable y su padre.
    @Binding var imageData: Data?

    /// Dismisses la sheet cuando el usuario toma la foto o cancela.
    @Environment(\.dismiss) private var dismiss

    // MARK: - UIViewControllerRepresentable

    /// Crea e inicializa el `UIImagePickerController` con la cámara trasera.
    ///
    /// `sourceType = .camera` abre directamente la cámara (no la galería).
    /// El delegate es el `Coordinator` que maneja los callbacks de resultado.
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera     // Cámara del dispositivo (no galería)
        picker.delegate = context.coordinator
        return picker
    }

    /// Actualización del ViewController cuando cambian las props — no necesario aquí.
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    /// Crea el Coordinator que actúa como delegate de UIKit.
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: - Coordinator (delegado)

    /// Clase intermediaria que implementa los protocolos delegate de UIImagePickerController.
    ///
    /// El patrón Coordinator es necesario porque SwiftUI no puede adoptar directamente
    /// los protocolos de UIKit basados en `@objc`/Objective-C.
    /// Equivalente Android: el callback de `registerForActivityResult`.
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPickerView

        init(_ parent: CameraPickerView) { self.parent = parent }

        /// Se llama cuando el usuario toma una foto y la confirma.
        ///
        /// Comprime la imagen a JPEG 80% para reducir el tamaño antes de
        /// subir a Supabase Storage o guardar localmente.
        /// `info[.originalImage]` es la foto sin procesar desde el sensor.
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                // Comprimir a JPEG 80% — equilibrio entre calidad y tamaño de archivo
                parent.imageData = image.jpegData(compressionQuality: 0.8)
            }
            parent.dismiss()
        }

        /// Se llama cuando el usuario cancela sin tomar foto.
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
