import UIKit
import AVFoundation
import Vision
import PhotosUI

class QRScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate, PHPickerViewControllerDelegate {
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var onCode: ((String) -> Void)?
    let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let closeBtn = UIButton(type: .system)
        closeBtn.setTitle("close", for: .normal)
        closeBtn.setTitleColor(.white, for: .normal)
        closeBtn.frame = CGRect(x: 20, y: 60, width: 60, height: 30)
        closeBtn.addTarget(self, action: #selector(close), for: .touchUpInside)
        view.addSubview(closeBtn)

        let imgBtn = UIButton(type: .system)
        imgBtn.setTitle("scan from image", for: .normal)
        imgBtn.setTitleColor(.white, for: .normal)
        imgBtn.frame = CGRect(x: 20, y: view.bounds.height - 80, width: 160, height: 30)
        imgBtn.addTarget(self, action: #selector(pickImage), for: .touchUpInside)
        view.addSubview(imgBtn)

        statusLabel.textColor = .white
        statusLabel.frame = CGRect(x: 20, y: view.bounds.height - 40, width: view.bounds.width - 40, height: 20)
        view.addSubview(statusLabel)

        setupCamera()
    }

    func setupCamera() {
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { statusLabel.text = "no camera"; return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(preview, at: 0)
        captureSession = session
        previewLayer = preview
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject, let val = obj.stringValue {
            captureSession?.stopRunning()
            onCode?(val)
            dismiss(animated: true)
        }
    }

    @objc func pickImage() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let item = results.first?.itemProvider, item.canLoadObject(ofClass: UIImage.self) else { return }
        item.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
            guard let img = obj as? UIImage else { return }
            DispatchQueue.main.async { self?.decodeImage(img) }
        }
    }

    func decodeImage(_ image: UIImage) {
        guard let cg = image.cgImage else { return }
        let req = VNDetectBarcodesRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        try? handler.perform([req])
        if let r = (req.results as? [VNBarcodeObservation])?.first, let val = r.payloadStringValue {
            onCode?(val)
            dismiss(animated: true)
        } else {
            statusLabel.text = "no qr found"
        }
    }

    @objc func close() { captureSession?.stopRunning(); dismiss(animated: true) }
}
