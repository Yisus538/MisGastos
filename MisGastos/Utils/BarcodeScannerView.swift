// =============================================================================
// BarcodeScannerView.swift — Escáner de códigos de barras con AVFoundation
// =============================================================================
// Rol en la app:
//   Presenta una pantalla de cámara en tiempo real para escanear el código de
//   barras de un producto. Al detectar un código, vibra el dispositivo y devuelve
//   el valor vía el closure `onScan`. Se usa en `NuevoProductoView` y
//   `EditarProductoView` para auto-completar el campo de código del producto.
//
// Equivalente Android:
//   `CameraX` con `ImageAnalysis` + `BarcodeScanner` de ML Kit, o la librería
//   `ZXing` (Zebra Crossing). En Android sería:
//   ```kotlin
//   val options = BarcodeScannerOptions.Builder()
//       .setBarcodeFormats(Barcode.FORMAT_ALL_FORMATS)
//       .build()
//   val scanner = BarcodeScanning.getClient(options)
//   scanner.process(inputImage)
//       .addOnSuccessListener { barcodes -> onScan(barcodes.first()?.rawValue) }
//   ```
//
// Framework: AVFoundation
//   `AVCaptureSession` es el núcleo de la cámara en iOS. Requiere:
//   - `AVCaptureDevice`: la cámara física.
//   - `AVCaptureDeviceInput`: puente entre la cámara y la sesión.
//   - `AVCaptureMetadataOutput`: detecta y decodifica códigos de barras/QR.
//   - `AVCaptureVideoPreviewLayer`: capa CALayer que muestra el feed de la cámara.
//
// Permiso de cámara:
//   En iOS, acceder a la cámara requiere la clave `NSCameraUsageDescription` en
//   `Info.plist`. La primera vez que se usa, iOS muestra el diálogo de permiso.
//   Si el usuario deniega, `AVCaptureDevice.authorizationStatus` devuelve `.denied`.
//   Equivalente Android: `Manifest.permission.CAMERA` + `ActivityCompat.requestPermissions`.
//
// Arquitectura de esta vista:
//   1. `BarcodeScannerView` (SwiftUI): maneja permisos, estados de error y el overlay UI.
//   2. `CameraPreviewController` (UIViewControllerRepresentable): puente SwiftUI → UIKit.
//   3. `_ScannerVC` (UIViewController + AVFoundation): la lógica real de la cámara.
// =============================================================================

import SwiftUI
import AVFoundation
import AudioToolbox

// MARK: - Vista pública SwiftUI

/// Vista SwiftUI que presenta la pantalla de escáner de códigos de barras.
///
/// Maneja los tres estados posibles de la cámara:
/// 1. **Permiso denegado**: muestra instrucciones para habilitarlo en Configuración.
/// 2. **Cámara no disponible**: ocurre en el simulador de Xcode (sin hardware de cámara).
/// 3. **Escáner activo**: muestra el preview de la cámara con el overlay de interfaz.
///
/// Equivalente Android: `Activity` con `CameraX` o un `Fragment` con el preview de cámara.
struct BarcodeScannerView: View {
    /// Closure llamado cuando se detecta un código de barras con su valor decodificado.
    let onScan: (String) -> Void

    /// Dismisses la vista al cancelar o al escanear exitosamente.
    @Environment(\.dismiss) private var dismiss

    /// `true` si el usuario denegó el permiso de cámara.
    @State private var permisoDenegado = false

    /// `true` si la cámara no está disponible (ej.: simulador de Xcode).
    @State private var camaraNoDisponible = false

    var body: some View {
        ZStack {
            // Fondo negro para consistencia visual antes de que cargue la cámara
            Color.black.ignoresSafeArea()

            if permisoDenegado {
                // Estado: el usuario negó el permiso de cámara
                permisoView
            } else if camaraNoDisponible {
                // Estado: no hay hardware de cámara (simulador)
                noDisponibleView
            } else {
                // Estado: cámara disponible y con permiso — mostrar el scanner
                CameraPreviewController(
                    onScan: { code in onScan(code); dismiss() },  // Al escanear, notificar y cerrar
                    onSetupFailed: { camaraNoDisponible = true }   // Si AVFoundation falla, mostrar error
                )
                .ignoresSafeArea()
                // Overlay con el marco de encuadre y los controles de UI
                scannerOverlay
            }
        }
        .onAppear { checkPermission() }  // Verificar permiso de cámara al presentar la vista
    }

    // MARK: - Overlay con recorte de área de escaneo

    /// Overlay que dibuja la UI sobre el preview de cámara: área de escaneo y controles.
    ///
    /// Usa `GeometryReader` para calcular las dimensiones del recorte proporcionales
    /// a la pantalla. El recorte se dibuja con `Path` usando `eoFill: true` (even-odd rule),
    /// que invierte el área de relleno dentro del rectángulo redondeado (crea un "agujero").
    ///
    /// Equivalente Android: un `SurfaceView` o `TextureView` con un `FrameLayout` overlay
    /// dibujado con `canvas.clipRect` y `PorterDuff.Mode.CLEAR`.
    private var scannerOverlay: some View {
        ZStack {
            GeometryReader { geo in
                // Calcular las dimensiones del rectángulo de encuadre
                let boxW = min(geo.size.width - 60, 300.0)   // Ancho: máximo 300pt, con márgenes
                let boxH: CGFloat = 150                         // Alto fijo para códigos de barras horizontales
                let boxX = (geo.size.width - boxW) / 2         // Centrado horizontal
                let boxY = (geo.size.height - boxH) / 2 - 20   // Centrado vertical, ligeramente hacia arriba

                // Fondo semi-transparente con "agujero" en el área de escaneo
                // La `even-odd rule` invierte el fill dentro del rectángulo redondeado,
                // creando el efecto de visor con fondo oscurecido alrededor
                Path { path in
                    path.addRect(geo.frame(in: .local))     // Rectángulo completo de pantalla
                    path.addRoundedRect(                    // Rectángulo redondeado del área de escaneo
                        in: CGRect(x: boxX, y: boxY, width: boxW, height: boxH),
                        cornerSize: CGSize(width: 10, height: 10)
                    )
                }
                .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
                .ignoresSafeArea()

                // Borde blanco del área de escaneo
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                    .frame(width: boxW, height: boxH)
                    .position(x: geo.size.width / 2, y: boxY + boxH / 2)

                // Esquinas verdes (brackets) en las cuatro esquinas del marco
                // Dan feedback visual sobre dónde alinear el código de barras
                let bw: CGFloat = 22    // Longitud de cada bracket en puntos
                let corners: [(CGFloat, CGFloat)] = [
                    (boxX, boxY),                           // Superior izquierda
                    (boxX + boxW - bw, boxY),               // Superior derecha
                    (boxX, boxY + boxH - bw),               // Inferior izquierda
                    (boxX + boxW - bw, boxY + boxH - bw)    // Inferior derecha
                ]
                ForEach(Array(corners.enumerated()), id: \.offset) { _, corner in
                    Path { p in
                        p.move(to: CGPoint(x: corner.0 + bw, y: corner.1))
                        p.addLine(to: CGPoint(x: corner.0, y: corner.1))
                        p.addLine(to: CGPoint(x: corner.0, y: corner.1 + bw))
                    }
                    .stroke(Color.saGreen, lineWidth: 3)
                }
            }

            // Controles de UI: botón de cierre y texto de instrucción
            VStack {
                HStack {
                    Spacer()
                    // Botón X para cerrar el scanner sin escanear
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())  // Material translúcido sobre la cámara
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)  // Espacio para la safe area superior

                Spacer()

                // Instrucción en la parte inferior
                VStack(spacing: 8) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Apuntá la cámara al código de barras")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 60)
            }
        }
    }

    // MARK: - Estado: permiso denegado

    /// Vista que se muestra cuando el usuario denegó el permiso de cámara.
    ///
    /// iOS no permite mostrar el diálogo de permiso más de una vez. Si fue denegado,
    /// la única solución es redirigir al usuario a Configuración → App → Cámara.
    /// Equivalente Android: `ActivityCompat.shouldShowRequestPermissionRationale()` + Intent a Settings.
    private var permisoView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.slash.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.saLabel3)
            Text("Sin acceso a la cámara")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            Text("Habilitá el permiso en Configuración → Súper Ahorro → Cámara")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            // Abre la pantalla de configuración de la app en iOS Settings
            Button("Abrir Configuración") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.saGreen)
            Button("Cancelar") { dismiss() }
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Estado: cámara no disponible (simulador)

    /// Vista que se muestra cuando `AVCaptureDevice` no puede inicializarse.
    ///
    /// Ocurre principalmente en el simulador de Xcode que no tiene hardware de cámara.
    /// En un dispositivo físico, este estado solo ocurriría si la cámara tiene un fallo
    /// de hardware, lo cual es extremadamente raro.
    private var noDisponibleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.slash")
                .font(.system(size: 48))
                .foregroundStyle(Color.saLabel3)
            Text("Cámara no disponible")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
            Text("Esta función requiere un dispositivo físico.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
            Button("Cancelar") { dismiss() }
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 8)
        }
    }

    // MARK: - Verificación de permisos

    /// Verifica el estado del permiso de cámara y solicita acceso si es necesario.
    ///
    /// Los tres estados de `AVCaptureDevice.authorizationStatus`:
    /// - `.authorized`: ya tiene permiso, no hacer nada.
    /// - `.notDetermined`: primera vez — mostrar el diálogo del sistema (iOS pregunta).
    /// - `.denied` / `.restricted`: sin permiso — mostrar la vista de configuración.
    ///
    /// Equivalente Android: `ContextCompat.checkSelfPermission(CAMERA)` +
    /// `ActivityResultContracts.RequestPermission()`.
    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // Ya tiene permiso — el scanner comenzará automáticamente
            break
        case .notDetermined:
            // Primera vez: solicitar permiso al usuario
            // El closure se ejecuta en un thread secundario, por eso se usa DispatchQueue.main
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if !granted { DispatchQueue.main.async { permisoDenegado = true } }
            }
        default:
            // .denied o .restricted: sin permiso
            permisoDenegado = true
        }
    }
}

// MARK: - Puente UIViewControllerRepresentable

/// Puente entre SwiftUI y el `_ScannerVC` de UIKit/AVFoundation.
///
/// `UIViewControllerRepresentable` permite usar ViewControllers de UIKit dentro de
/// vistas SwiftUI. Es necesario aquí porque `AVCaptureVideoPreviewLayer` es una capa
/// de CoreAnimation que solo puede ser administrada por un UIViewController.
///
/// Equivalente Android: `AndroidView { context -> SurfaceView }` en Compose para
/// integrar Views del sistema de Vista antiguo (View system) en Compose.
private struct CameraPreviewController: UIViewControllerRepresentable {
    /// Closure llamado cuando se detecta y decodifica un código de barras.
    let onScan: (String) -> Void

    /// Closure llamado si `AVCaptureSession` no pudo inicializarse.
    let onSetupFailed: () -> Void

    /// Crea el `_ScannerVC` e inyecta los closures de callback.
    func makeUIViewController(context: Context) -> _ScannerVC {
        let vc = _ScannerVC()
        vc.onScan = onScan
        vc.onSetupFailed = onSetupFailed
        return vc
    }

    /// No requiere actualización cuando cambian las props — la sesión de AVFoundation
    /// se gestiona internamente en el ViewController.
    func updateUIViewController(_ uiViewController: _ScannerVC, context: Context) {}
}

// MARK: - UIViewController con AVFoundation

/// ViewController que gestiona la sesión de cámara y la detección de códigos.
///
/// Hereda de `UIViewController` para controlar el ciclo de vida de la cámara.
/// Implementa `AVCaptureMetadataOutputObjectsDelegate` para recibir callbacks
/// cuando AVFoundation detecta un código de barras en el frame de video.
///
/// `_ScannerVC` (prefijo `_` indica clase de implementación interna, no API pública)
///
/// Equivalente Android: un `Fragment` con `ProcessCameraProvider.bindToLifecycle()`
/// de CameraX y un `ImageAnalysis` con `BarcodeScannerOptions` de ML Kit.
final class _ScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    // MARK: - Callbacks

    /// Llamado con el valor del código detectado (número EAN, URL, texto, etc.)
    var onScan: ((String) -> Void)?

    /// Llamado si la sesión de AVFoundation no pudo iniciarse.
    var onSetupFailed: (() -> Void)?

    // MARK: - Propiedades de AVFoundation

    /// La sesión de captura — coordina inputs (cámara) y outputs (metadata).
    /// Equivalente Android: `ProcessCameraProvider` de CameraX.
    private let session = AVCaptureSession()

    /// Capa que renderiza el video de la cámara en tiempo real.
    /// Es una `CALayer` que debe insertarse en el `view.layer` del ViewController.
    /// Equivalente Android: `PreviewView` de CameraX.
    private var previewLayer: AVCaptureVideoPreviewLayer?

    /// Flag para evitar procesar múltiples códigos seguidos (anti-duplicado).
    /// Sin esto, un mismo código podría devolverse decenas de veces por segundo.
    private var didScan = false

    // MARK: - Ciclo de vida

    /// Configura la sesión de AVFoundation cuando la vista carga por primera vez.
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupSession()
    }

    /// Actualiza el frame del `previewLayer` cuando la vista cambia de tamaño
    /// (rotación del dispositivo, cambios de safe area, etc.)
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    /// Detiene la sesión de cámara cuando el ViewController desaparece.
    ///
    /// `session.stopRunning()` se ejecuta en un thread secundario (`userInitiated`)
    /// porque es una operación de I/O y bloquearía el hilo principal si se hiciera
    /// en el Main Thread. Equivalente Android: `ProcessCameraProvider.unbindAll()`.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DispatchQueue.global(qos: .userInitiated).async { self.session.stopRunning() }
    }

    // MARK: - Configuración de la sesión AVFoundation

    /// Configura el pipeline de captura: input de cámara + output de metadata + preview.
    ///
    /// El pipeline de AVFoundation sigue siempre este orden:
    /// 1. `AVCaptureDevice` → la cámara física.
    /// 2. `AVCaptureDeviceInput` → adapta la cámara para la sesión.
    /// 3. `AVCaptureSession.addInput()` → conecta la entrada.
    /// 4. `AVCaptureMetadataOutput` → detecta códigos de barras y QR.
    /// 5. `AVCaptureSession.addOutput()` → conecta la salida.
    /// 6. `AVCaptureVideoPreviewLayer` → muestra el video en la pantalla.
    /// 7. `session.startRunning()` → inicia el flujo de video.
    private func setupSession() {
        // Obtener la cámara trasera por defecto
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            // Fallo — ocurre en el simulador o si la cámara está en uso por otra app
            DispatchQueue.main.async { self.onSetupFailed?() }
            return
        }

        // `beginConfiguration` / `commitConfiguration` agrupa los cambios en la sesión
        // para evitar estados intermedios inconsistentes (patrón de transacción)
        session.beginConfiguration()
        if session.canAddInput(input) { session.addInput(input) }

        // Configurar la salida de metadata para detectar códigos de barras
        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) { session.addOutput(output) }

        // El delegate recibe los callbacks en el hilo principal para actualizar la UI
        output.setMetadataObjectsDelegate(self, queue: .main)

        // Tipos de código soportados: EAN-8/13 (supermercados), UPC-E, Code128/39
        // (industrial), QR Code, PDF417 y Aztec (documentos y tickets)
        output.metadataObjectTypes = [.ean8, .ean13, .upce, .code128, .code39, .qr, .pdf417, .aztec]

        session.commitConfiguration()

        // Crear y agregar la capa de preview al view
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill   // Llena el frame sin distorsión (puede recortar)
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)  // Insertar por debajo de las subvistas de SwiftUI
        previewLayer = layer

        // Iniciar la captura de video en un thread secundario
        // `startRunning()` es bloqueante y NUNCA debe llamarse en el Main Thread
        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

    /// Llamado por AVFoundation cuando detecta un código de barras en un frame de video.
    ///
    /// `didScan` previene que el mismo código se devuelva múltiples veces por segundo.
    /// `AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)` activa el motor háptico
    /// para dar feedback físico al usuario — equivalente Android: `Vibrator.vibrate()`.
    ///
    /// - Parameter objects: Array de objetos detectados en el frame (normalmente uno solo).
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput objects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        // Solo procesar el primer código detectado (anti-duplicado)
        guard !didScan,
              let obj = objects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        didScan = true
        // Vibración táctil de confirmación — feedback físico que el código fue escaneado
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        onScan?(value)
    }
}
