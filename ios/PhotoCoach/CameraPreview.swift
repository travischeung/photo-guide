import AVFoundation
import SwiftUI

/// Native preview layer in a UIView, so analyzed frames never re-render SwiftUI (TRD §2).
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let onTapToFocus: (CGPoint) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        // Letterboxed 4:3 like Apple's Camera, so the preview shows exactly what the photo will contain.
        view.previewLayer.videoGravity = .resizeAspect
        view.onTapToFocus = onTapToFocus
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        view.onTapToFocus = onTapToFocus
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        var onTapToFocus: ((CGPoint) -> Void)?
        private let focusSquare = UIView(frame: CGRect(x: 0, y: 0, width: 72, height: 72))

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .black
            focusSquare.layer.borderColor = UIColor.systemYellow.cgColor
            focusSquare.layer.borderWidth = 1.5
            focusSquare.alpha = 0
            focusSquare.isUserInteractionEnabled = false
            addSubview(focusSquare)
            addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            let point = gesture.location(in: self)
            let videoRect = previewLayer.layerRectConverted(fromMetadataOutputRect: CGRect(x: 0, y: 0, width: 1, height: 1))
            guard videoRect.contains(point) else { return }
            onTapToFocus?(previewLayer.captureDevicePointConverted(fromLayerPoint: point))

            focusSquare.center = point
            focusSquare.alpha = 1
            focusSquare.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
            UIView.animate(withDuration: 0.2) { self.focusSquare.transform = .identity }
            UIView.animate(withDuration: 0.3, delay: 1.0) { self.focusSquare.alpha = 0 }
        }
    }
}
