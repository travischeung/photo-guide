import SwiftUI

struct ContentView: View {
    @State private var model = CameraModel()

    var body: some View {
        ZStack {
            // Camera stays mounted under review so returning to shooting is instant.
            CameraView(model: model)
            if let photo = model.photo {
                ReviewView(model: model, image: photo.image)
            }
        }
        .task { await model.run() }
    }
}

struct CameraView: View {
    let model: CameraModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(session: model.service.session) { point in
                Task { await model.service.focus(at: point) }
            }
            .ignoresSafeArea()

            // Immediate shutter acknowledgment, independent of capture latency (TRD §9).
            Color.black.opacity(model.isCapturing ? 0.5 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeOut(duration: 0.15), value: model.isCapturing)

            statusMessage

            VStack {
                #if DEBUG
                Text("\(model.frameStats.delivered) fps · \(model.frameStats.dropped) dropped")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(.black.opacity(0.5), in: .capsule)
                #endif
                Spacer()
                if model.captureFailed {
                    banner("Couldn't take the photo. Try again.")
                }
                if model.savedConfirmation {
                    banner("Saved to Photos")
                        .task {
                            try? await Task.sleep(for: .seconds(1.5))
                            model.clearConfirmation()
                        }
                }
                shutterButton
            }
            .padding(.bottom, 24)
        }
    }

    private var shutterButton: some View {
        Button {
            Task { await model.capture() }
        } label: {
            Circle()
                .fill(.white)
                .frame(width: 64, height: 64)
                .padding(5)
                .overlay(Circle().stroke(.white, lineWidth: 4))
        }
        .disabled(model.status != .running || model.isCapturing)
        .opacity(model.status == .running ? 1 : 0.4)
        .accessibilityLabel("Take photo")
    }

    @ViewBuilder private var statusMessage: some View {
        switch model.status {
        case .unauthorized:
            VStack(spacing: 12) {
                Text("Camera access is off")
                    .font(.headline)
                Text("Photo Coach needs the camera to take and coach your photos.")
                    .multilineTextAlignment(.center)
                Button("Open Settings") { openSettings() }
                    .buttonStyle(.borderedProminent)
            }
            .foregroundStyle(.white)
            .padding(32)
        case .failed:
            Text("The camera isn't available right now.")
                .foregroundStyle(.white)
        case .interrupted:
            Text("Camera paused")
                .foregroundStyle(.white)
        case .running, nil:
            EmptyView()
        }
    }

    private func banner(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.black.opacity(0.6), in: .capsule)
            .padding(.bottom, 12)
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }
}

struct ReviewView: View {
    let model: CameraModel
    let image: UIImage
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .accessibilityLabel("Captured photo")
            VStack {
                Spacer()
                switch model.saveState {
                case .failed:
                    Text("Couldn't save. Your photo is still here — try again.")
                        .foregroundStyle(.white)
                case .denied:
                    VStack(spacing: 8) {
                        Text("Photo Coach can't add to your library.")
                            .foregroundStyle(.white)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                case .idle, .saving:
                    EmptyView()
                }
                HStack {
                    Button("Retake", role: .destructive) { model.discard() }
                    Spacer()
                    Button(model.saveState == .failed ? "Retry" : "Save") {
                        Task { await model.save() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.saveState == .saving)
                }
                .font(.headline)
                .padding(24)
            }
        }
    }
}
