import Photos
import UIKit

@MainActor @Observable
final class CameraModel {
    struct CapturedPhoto {
        let data: Data
        let image: UIImage
    }
    enum SaveState { case idle, saving, failed, denied }

    let service = CameraService()
    private(set) var status: CameraService.Status?
    private(set) var frameStats = (delivered: 0, dropped: 0)
    private(set) var isCapturing = false
    private(set) var captureFailed = false
    private(set) var savedConfirmation = false
    /// Held until saved or discarded, so a failed save never loses the photo (PRD F10).
    private(set) var photo: CapturedPhoto?
    private(set) var saveState = SaveState.idle

    func run() async {
        await service.start()
        for await event in service.events {
            switch event {
            case .status(let status): self.status = status
            case .frameStats(let delivered, let dropped): frameStats = (delivered, dropped)
            }
        }
    }

    func capture() async {
        guard !isCapturing, photo == nil else { return }
        let tap = ContinuousClock.now
        Metrics.signposter.emitEvent("ShutterTap")
        isCapturing = true
        captureFailed = false
        defer { isCapturing = false }
        do {
            let data = try await service.capturePhoto(tappedAt: tap)
            guard let image = await UIImage(data: data)?.byPreparingForDisplay() else {
                throw CameraService.CameraError.noPhotoData
            }
            photo = CapturedPhoto(data: data, image: image)
        } catch {
            Metrics.log.error("capture failed: \(error)")
            captureFailed = true
        }
    }

    func save() async {
        guard let data = photo?.data, saveState != .saving else { return }
        saveState = .saving
        guard await PHPhotoLibrary.requestAuthorization(for: .addOnly) == .authorized else {
            saveState = .denied
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            }
            photo = nil
            saveState = .idle
            savedConfirmation = true
        } catch {
            Metrics.log.error("save failed: \(error)")
            saveState = .failed
        }
    }

    func discard() {
        photo = nil
        saveState = .idle
    }

    func clearConfirmation() {
        savedConfirmation = false
    }
}
