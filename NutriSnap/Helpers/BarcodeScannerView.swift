import SwiftUI
import AVFoundation

/// Full-screen barcode scanner using AVFoundation.
/// Supports EAN-8, EAN-13, UPC-E (standard European barcodes).
struct BarcodeScannerView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> BarcodeScannerVC {
        let vc = BarcodeScannerVC()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: BarcodeScannerVC, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, BarcodeScannerVCDelegate {
        let parent: BarcodeScannerView
        private var hasScanned = false

        init(parent: BarcodeScannerView) { self.parent = parent }

        func didScanBarcode(_ code: String) {
            guard !hasScanned else { return }
            hasScanned = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            parent.scannedCode = code
            parent.dismiss()
        }

        func didTapClose() { parent.dismiss() }
    }
}

// MARK: - Delegate protocol

protocol BarcodeScannerVCDelegate: AnyObject {
    func didScanBarcode(_ code: String)
    func didTapClose()
}

// MARK: - View Controller

final class BarcodeScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: BarcodeScannerVCDelegate?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var torchOn = false

    private let scanWidth: CGFloat = 280
    private let scanHeight: CGFloat = 160

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
        setupOverlay()
        setupControls()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            session.stopRunning()
        }
        setTorch(on: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    // MARK: - Camera setup

    private func setupCamera() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            showNoCameraLabel()
            return
        }

        session.addInput(input)

        let metaOutput = AVCaptureMetadataOutput()
        guard session.canAddOutput(metaOutput) else { return }
        session.addOutput(metaOutput)

        metaOutput.setMetadataObjectsDelegate(self, queue: .main)
        metaOutput.metadataObjectTypes = [.ean8, .ean13, .upce]

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
    }

    private func showNoCameraLabel() {
        let label = UILabel()
        label.text = "Camera not available"
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: - Overlay

    private func setupOverlay() {
        guard previewLayer != nil else { return }

        let overlay = UIView(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.isUserInteractionEnabled = false
        view.addSubview(overlay)

        let scanX = (view.bounds.width - scanWidth) / 2
        let scanY = (view.bounds.height - scanHeight) / 2 - 50
        let scanRect = CGRect(x: scanX, y: scanY, width: scanWidth, height: scanHeight)

        let fullPath = UIBezierPath(rect: view.bounds)
        let holePath = UIBezierPath(roundedRect: scanRect, cornerRadius: 14)
        fullPath.append(holePath)
        fullPath.usesEvenOddFillRule = true

        let dimLayer = CAShapeLayer()
        dimLayer.path = fullPath.cgPath
        dimLayer.fillRule = .evenOdd
        dimLayer.fillColor = UIColor.black.withAlphaComponent(0.55).cgColor
        overlay.layer.addSublayer(dimLayer)

        let border = UIView(frame: scanRect)
        border.layer.cornerRadius = 14
        border.layer.borderColor = UIColor.systemGreen.cgColor
        border.layer.borderWidth = 2.5
        border.isUserInteractionEnabled = false
        view.addSubview(border)

        let scanLine = UIView()
        scanLine.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.6)
        scanLine.frame = CGRect(x: 16, y: scanHeight / 2 - 0.5, width: scanWidth - 32, height: 1)
        border.addSubview(scanLine)

        let hint = UILabel()
        hint.text = "Point at barcode"
        hint.textColor = .white
        hint.font = .systemFont(ofSize: 15, weight: .medium)
        hint.textAlignment = .center
        hint.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hint)
        NSLayoutConstraint.activate([
            hint.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hint.topAnchor.constraint(equalTo: border.bottomAnchor, constant: 24)
        ])
    }

    // MARK: - Controls

    private func setupControls() {
        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        close.tintColor = .white
        let closeConfig = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        close.setPreferredSymbolConfiguration(closeConfig, forImageIn: .normal)
        close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        close.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(close)

        let torch = UIButton(type: .system)
        torch.setImage(UIImage(systemName: "flashlight.off.fill"), for: .normal)
        torch.tintColor = .white
        let torchConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        torch.setPreferredSymbolConfiguration(torchConfig, forImageIn: .normal)
        torch.addTarget(self, action: #selector(torchTapped(_:)), for: .touchUpInside)
        torch.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(torch)

        NSLayoutConstraint.activate([
            close.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            close.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            torch.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            torch.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    @objc private func closeTapped() { delegate?.didTapClose() }

    @objc private func torchTapped(_ sender: UIButton) {
        torchOn.toggle()
        setTorch(on: torchOn)
        sender.setImage(
            UIImage(systemName: torchOn ? "flashlight.on.fill" : "flashlight.off.fill"),
            for: .normal
        )
    }

    private func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }

    // MARK: - Metadata delegate

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = object.stringValue else { return }
        session.stopRunning()
        delegate?.didScanBarcode(code)
    }
}
