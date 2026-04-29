import SwiftUI
import AVFoundation
import AudioToolbox

// MARK: - Public SwiftUI View

struct BarcodeScannerView: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var permisoDenegado = false
    @State private var camaraNoDisponible = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if permisoDenegado {
                permisoView
            } else if camaraNoDisponible {
                noDisponibleView
            } else {
                CameraPreviewController(
                    onScan: { code in onScan(code); dismiss() },
                    onSetupFailed: { camaraNoDisponible = true }
                )
                .ignoresSafeArea()
                scannerOverlay
            }
        }
        .onAppear { checkPermission() }
    }

    // MARK: - Overlay with cutout

    private var scannerOverlay: some View {
        ZStack {
            GeometryReader { geo in
                let boxW = min(geo.size.width - 60, 300.0)
                let boxH: CGFloat = 150
                let boxX = (geo.size.width - boxW) / 2
                let boxY = (geo.size.height - boxH) / 2 - 20

                // Dimmed background with hole
                Path { path in
                    path.addRect(geo.frame(in: .local))
                    path.addRoundedRect(
                        in: CGRect(x: boxX, y: boxY, width: boxW, height: boxH),
                        cornerSize: CGSize(width: 10, height: 10)
                    )
                }
                .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
                .ignoresSafeArea()

                // Viewfinder border
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                    .frame(width: boxW, height: boxH)
                    .position(x: geo.size.width / 2, y: boxY + boxH / 2)

                // Corner brackets
                let bw: CGFloat = 22
                let corners: [(CGFloat, CGFloat)] = [
                    (boxX, boxY), (boxX + boxW - bw, boxY),
                    (boxX, boxY + boxH - bw), (boxX + boxW - bw, boxY + boxH - bw)
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

            // Controls
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)

                Spacer()

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

    // MARK: - Permission denied

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

    // MARK: - Camera unavailable (simulator)

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

    // MARK: - Permission

    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if !granted { DispatchQueue.main.async { permisoDenegado = true } }
            }
        default:
            permisoDenegado = true
        }
    }
}

// MARK: - UIViewControllerRepresentable bridge

private struct CameraPreviewController: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onSetupFailed: () -> Void

    func makeUIViewController(context: Context) -> _ScannerVC {
        let vc = _ScannerVC()
        vc.onScan = onScan
        vc.onSetupFailed = onSetupFailed
        return vc
    }

    func updateUIViewController(_ uiViewController: _ScannerVC, context: Context) {}
}

// MARK: - AVFoundation scanner controller

final class _ScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    var onSetupFailed: (() -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didScan = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DispatchQueue.global(qos: .userInitiated).async { self.session.stopRunning() }
    }

    private func setupSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            DispatchQueue.main.async { self.onSetupFailed?() }
            return
        }

        session.beginConfiguration()
        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) { session.addOutput(output) }
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.ean8, .ean13, .upce, .code128, .code39, .qr, .pdf417, .aztec]

        session.commitConfiguration()

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer

        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput objects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didScan,
              let obj = objects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        didScan = true
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        onScan?(value)
    }
}
