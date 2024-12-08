import SwiftUI
import RealityKit
import ARKit

struct ContentView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var isStreaming = false
    private let streamManager = YouTubeStreamManager()
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace

    @State private var arkitSession = ARKitSession()
    @State private var cameraAccessStatus: String = "Checking camera access..."
    @State private var frameCount = 0
    @State private var pixelBuffer: CVPixelBuffer?
    @State private var isCameraRunning = false

    let placeholderImage = Image(systemName: "camera")

    var body: some View {
        VStack(spacing: 20) {
            // Status Indicator
            Text(cameraAccessStatus)
                .font(.headline)
                .foregroundColor(cameraAccessStatus == "Frames are displaying!" ? .green : .red)

            // Frame count
            Text("Frames processed: \(frameCount)")
                .font(.subheadline)
                .foregroundColor(.gray)

            // Display the camera frame
            let displayedImage = pixelBuffer?.image ?? placeholderImage
            displayedImage
                .resizable()
                .scaledToFit()
                .frame(height: 300)
                .cornerRadius(10)
                .padding()

            // Buttons
            HStack {
                Button("Test Camera") {
                    testCamera()
                }
                .padding()
                .background(isCameraRunning ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(isCameraRunning)

                Button(appModel.immersiveSpaceState == .open ? "Hide Immersive Space" : "Show Immersive Space") {
                    toggleImmersiveSpace()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            // Streaming Button
            Button(isStreaming ? "Stop Streaming" : "Start Streaming") {
                Task {
                    if isStreaming {
                        do {
                            try await streamManager.stopStreaming()
                        } catch {
                            print("Failed to stop streaming: \(error.localizedDescription)")
                        }
                    } else {
                        do {
                            try await streamManager.startStreaming()
                        } catch {
                            print("Failed to start streaming: \(error.localizedDescription)")
                        }
                    }
                    isStreaming.toggle()
                }
            }
                        .padding()
                        .background(isStreaming ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
        }
        .padding()
        .onAppear {
            checkCameraAccess()
        }
    }


    private func sendFrameToStream(pixelBuffer: CVPixelBuffer) {
        if isStreaming {
            streamManager.sendFrame(pixelBuffer: pixelBuffer)
        }
    }

    private func checkCameraAccess() {
        if CameraFrameProvider.isSupported {
            cameraAccessStatus = "Camera access is supported!"
        } else {
            cameraAccessStatus = "Camera access is not supported."
        }
    }

    private func testCamera() {
        guard cameraAccessStatus == "Camera access is supported!" else {
            print("Cannot start camera: access not supported.")
            return
        }

        cameraAccessStatus = "Starting camera..."
        isCameraRunning = true

        Task {
            await configureCameraAndStartFrames()
        }
    }

    private func toggleImmersiveSpace() {
        Task { @MainActor in
            switch appModel.immersiveSpaceState {
            case .open:
                print("Dismissing immersive space...")
                appModel.immersiveSpaceState = .inTransition
                await dismissImmersiveSpace()
                appModel.immersiveSpaceState = .closed

            case .closed:
                print("Opening immersive space...")
                appModel.immersiveSpaceState = .inTransition
                let result = await openImmersiveSpace(id: appModel.immersiveSpaceID)
                switch result {
                case .opened:
                    appModel.immersiveSpaceState = .open
                case .userCancelled, .error:
                    appModel.immersiveSpaceState = .closed
                @unknown default:
                    appModel.immersiveSpaceState = .closed
                }

            case .inTransition:
                print("Action ignored during transition.")
            }
        }
    }

    private func configureCameraAndStartFrames() async {
        let cameraFrameProvider = CameraFrameProvider()

        do {
            print("Starting ARKit session...")
            try await arkitSession.run([cameraFrameProvider])

            let formats = CameraVideoFormat.supportedVideoFormats(for: .main, cameraPositions: [.left])
            guard let highResolutionFormat = formats.max(by: { $0.frameSize.height < $1.frameSize.height }),
                  let cameraFrameUpdates = cameraFrameProvider.cameraFrameUpdates(for: highResolutionFormat) else {
                print("Failed to initialize cameraFrameUpdates.")
                cameraAccessStatus = "Failed to start camera."
                isCameraRunning = false
                return
            }

            print("ARKit session started successfully.")
            cameraAccessStatus = "Frames are displaying!"

            for await frame in cameraFrameUpdates {
                if let sample = frame.sample(for: .left) {
                    DispatchQueue.main.async {
                        pixelBuffer = sample.pixelBuffer
                        frameCount += 1
                        //print("Frame \(frameCount) received.")
                        sendFrameToStream(pixelBuffer: sample.pixelBuffer) // Stream the frame
                    }
                }
            }
        } catch {
            print("Failed to start ARKit session: \(error.localizedDescription)")
            cameraAccessStatus = "Failed to start ARKit: \(error.localizedDescription)"
            isCameraRunning = false
        }
    }
}

extension CVPixelBuffer {
    var image: Image? {
        let ciImage = CIImage(cvPixelBuffer: self)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        let uiImage = UIImage(cgImage: cgImage)
        return Image(uiImage: uiImage)
    }
}
