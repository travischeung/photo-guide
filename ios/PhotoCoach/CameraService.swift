import AVFoundation

/// Owns the capture session. Every session call runs on one serial queue (TRD §3),
/// which is this actor's executor.
actor CameraService {
    enum Status: Sendable { case unauthorized, failed, running, interrupted }
    enum Event: Sendable {
        case status(Status)
        case frameStats(delivered: Int, dropped: Int)
    }
    enum CameraError: Error { case noCamera, unsupportedConfiguration, noPhotoData }

    nonisolated let events: AsyncStream<Event>
    private nonisolated let emit: AsyncStream<Event>.Continuation
    // Only read on the main thread to attach the preview layer; all configuration stays on `queue`.
    nonisolated(unsafe) let session = AVCaptureSession()

    private nonisolated let queue = DispatchSerialQueue(label: "com.travischeung.photocoach.session")
    nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }

    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let frameCounter: FrameCounter
    private var device: AVCaptureDevice?

    init() {
        let (stream, continuation) = AsyncStream.makeStream(of: Event.self)
        events = stream
        emit = continuation
        frameCounter = FrameCounter { continuation.yield(.frameStats(delivered: $0, dropped: $1)) }
    }

    func start() async {
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            emit.yield(.status(.unauthorized))
            return
        }
        if device == nil {
            do {
                try configure()
            } catch {
                Metrics.log.error("camera configuration failed: \(error)")
                emit.yield(.status(.failed))
                return
            }
        }
        if !session.isRunning { session.startRunning() }
    }

    private func configure() throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.noCamera
        }
        let input = try AVCaptureDeviceInput(device: device)

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        guard session.canAddInput(input) else { throw CameraError.unsupportedConfiguration }
        session.addInput(input)
        guard session.canAddOutput(photoOutput) else { throw CameraError.unsupportedConfiguration }
        session.addOutput(photoOutput)
        // Coaching-off baseline keeps the analysis output attached so Phase 2 compares like for like (TRD §9).
        guard session.canAddOutput(videoOutput) else { throw CameraError.unsupportedConfiguration }
        session.addOutput(videoOutput)

        // Zero shutter lag is on by default when supported (iOS 17+); responsive capture builds on it.
        if photoOutput.isResponsiveCaptureSupported { photoOutput.isResponsiveCaptureEnabled = true }
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(frameCounter, queue: DispatchQueue(label: "com.travischeung.photocoach.frames"))
        // shortcut: UI is portrait-only (PRD §4), so photos are fixed to portrait; use AVCaptureDevice.RotationCoordinator if landscape is added.
        if let connection = photoOutput.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }

        self.device = device
        observe(device: device)
    }

    private func observe(device: AVCaptureDevice) {
        let center = NotificationCenter.default
        let emit = emit
        _ = center.addObserver(forName: AVCaptureSession.didStartRunningNotification, object: session, queue: nil) { _ in
            emit.yield(.status(.running))
        }
        _ = center.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: nil) { _ in
            emit.yield(.status(.interrupted))
        }
        _ = center.addObserver(forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: nil) { _ in
            emit.yield(.status(.running))
        }
        _ = center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil) { [weak self] note in
            let error = note.userInfo?[AVCaptureSessionErrorKey] as? AVError
            Task { await self?.recover(from: error) }
        }
        _ = center.addObserver(forName: AVCaptureDevice.subjectAreaDidChangeNotification, object: device, queue: nil) { [weak self] _ in
            Task { await self?.resetFocus() }
        }
    }

    private func recover(from error: AVError?) {
        Metrics.log.error("capture session runtime error: \(String(describing: error))")
        if error?.code == .mediaServicesWereReset {
            session.startRunning()
        } else {
            emit.yield(.status(.failed))
        }
    }

    // MARK: Focus and exposure

    /// Tap-to-focus/expose at a device point (0...1). Holds until the subject area changes.
    func focus(at point: CGPoint) {
        configureFocus(at: point, focus: .autoFocus, exposure: .autoExpose, monitorSubjectArea: true)
    }

    /// Explicit reset (TRD §4): after the scene changes, return to continuous center focus/exposure.
    private func resetFocus() {
        configureFocus(at: CGPoint(x: 0.5, y: 0.5), focus: .continuousAutoFocus, exposure: .continuousAutoExposure, monitorSubjectArea: false)
    }

    private func configureFocus(at point: CGPoint, focus: AVCaptureDevice.FocusMode, exposure: AVCaptureDevice.ExposureMode, monitorSubjectArea: Bool) {
        guard let device else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(focus) {
                device.focusPointOfInterest = point
                device.focusMode = focus
            }
            if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(exposure) {
                device.exposurePointOfInterest = point
                device.exposureMode = exposure
            }
            device.isSubjectAreaChangeMonitoringEnabled = monitorSubjectArea
        } catch {
            Metrics.log.error("focus configuration failed: \(error)")
        }
    }

    // MARK: Capture

    func capturePhoto(tappedAt tap: ContinuousClock.Instant) async throws -> Data {
        let settings = photoOutput.availablePhotoCodecTypes.contains(.hevc)
            ? AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            : AVCapturePhotoSettings()
        return try await withCheckedThrowingContinuation { continuation in
            // The photo output keeps the delegate alive until the capture finishes.
            photoOutput.capturePhoto(with: settings, delegate: PhotoDelegate(tap: tap, continuation: continuation))
        }
    }
}

private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let tap: ContinuousClock.Instant
    private let continuation: CheckedContinuation<Data, Error>

    init(tap: ContinuousClock.Instant, continuation: CheckedContinuation<Data, Error>) {
        self.tap = tap
        self.continuation = continuation
    }

    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        Metrics.signposter.emitEvent("WillCapture")
        Metrics.log.notice("shutter: tap → capture start \(self.tap.duration(to: .now).ms) ms")
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let dimensions = photo.resolvedSettings.photoDimensions
        Metrics.log.notice("shutter: tap → photo ready \(self.tap.duration(to: .now).ms) ms (\(dimensions.width)x\(dimensions.height))")
        if let data = photo.fileDataRepresentation() {
            continuation.resume(returning: data)
        } else {
            continuation.resume(throwing: error ?? CameraService.CameraError.noPhotoData)
        }
    }
}

/// Counts delivered and dropped analysis frames once per second. State is touched only on the frames queue.
private final class FrameCounter: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let report: @Sendable (Int, Int) -> Void
    private var delivered = 0
    private var dropped = 0
    private var windowStart = ContinuousClock.now
    private var sawFirstFrame = false

    init(report: @escaping @Sendable (Int, Int) -> Void) {
        self.report = report
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if !sawFirstFrame {
            sawFirstFrame = true
            Metrics.signposter.emitEvent("FirstFrame")
            Metrics.log.notice("startup: launch → first frame \(Metrics.launch.duration(to: .now).ms) ms")
        }
        delivered += 1
        flushIfDue()
    }

    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        dropped += 1
        flushIfDue()
    }

    private func flushIfDue() {
        guard windowStart.duration(to: .now) >= .seconds(1) else { return }
        report(delivered, dropped)
        if dropped > 0 { Metrics.log.notice("frames: \(self.delivered) delivered, \(self.dropped) dropped in last second") }
        delivered = 0
        dropped = 0
        windowStart = .now
    }
}
