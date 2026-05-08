// =============================================================================
// ActivitySheet.swift — Hoja de compartir nativa de iOS (Share Sheet)
// =============================================================================
// Rol en la app:
//   Presenta el `UIActivityViewController` de iOS, que es la hoja de compartir
//   del sistema. Permite al usuario enviar archivos (PDF, CSV) por WhatsApp,
//   email, AirDrop, guardar en Files, etc. Se usa en `HistorialView` cuando el
//   usuario exporta sus gastos.
//
// Equivalente Android:
//   `Intent.ACTION_SEND` con `startActivity(Intent.createChooser(intent, "Compartir"))`.
//   En Android se crea un Intent con el MIME type del archivo y Android muestra
//   el selector de apps automáticamente.
//   En Compose la forma moderna es `rememberLauncherForActivityResult` con
//   `ActivityResultContracts.StartActivityForResult()`.
//
// UIViewControllerRepresentable:
//   `UIActivityViewController` es un ViewController de UIKit que no tiene
//   equivalente nativo en SwiftUI (salvo `ShareLink` para tipos básicos).
//   Para archivos arbitrarios (URL de PDF, CSV) se usa este wrapper.
//   Nota: SwiftUI tiene `ShareLink` desde iOS 16, pero solo para tipos que
//   conforman `Transferable`. Para URLs de archivos locales es más seguro
//   usar este wrapper directo con `UIActivityViewController`.
//
// Fix de iPad:
//   En iPad, `UIActivityViewController` se presenta como un popover, y iOS
//   requiere que se especifique el `sourceView` y `sourceRect` del popover
//   para saber dónde anclar la flecha. Sin esto, la app crashea en iPad.
//   La solución es anclar el popover al centro de la pantalla sin flecha.
// =============================================================================

import SwiftUI
import UIKit

/// Wrapper de `UIActivityViewController` para compartir archivos desde SwiftUI.
///
/// `UIViewControllerRepresentable` es el mecanismo para integrar ViewControllers
/// de UIKit dentro de vistas SwiftUI. Aquí se usa para presentar la Share Sheet
/// del sistema operativo.
///
/// Equivalente Android: `Intent.ACTION_SEND` con `Intent.createChooser()`.
struct ActivitySheet: UIViewControllerRepresentable {

    /// Array de ítems a compartir — puede contener URLs, strings, imágenes, etc.
    /// `UIActivityViewController` detecta automáticamente el tipo y ofrece las
    /// apps compatibles (si es un PDF → Preview, Files, email; si es texto → WhatsApp, etc.)
    let items: [Any]

    /// Crea e inicializa el `UIActivityViewController` con los ítems a compartir.
    ///
    /// `applicationActivities: nil` indica que no se agregan actividades personalizadas
    /// — solo se muestran las actividades del sistema y las apps instaladas.
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)

        // Fix crítico para iPad: sin esto, la app crashea al intentar presentar el popover
        // porque UIKit no sabe dónde anclar la flecha del popover.
        // En iPhone no es necesario (la hoja aparece desde abajo, no como popover).
        if let popover = vc.popoverPresentationController {
            // Anclar al rootViewController de la ventana principal
            popover.sourceView = UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                .first?.rootViewController?.view
            // Posicionar en el centro de la pantalla (popover sin flecha)
            popover.sourceRect = CGRect(
                x: UIScreen.main.bounds.midX,
                y: UIScreen.main.bounds.midY,
                width: 0, height: 0
            )
            // Sin flecha — el popover flota en el centro como un sheet en iPad
            popover.permittedArrowDirections = []
        }
        return vc
    }

    /// No requiere actualización cuando cambian las props.
    /// `UIActivityViewController` se configura una vez al crearse.
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
