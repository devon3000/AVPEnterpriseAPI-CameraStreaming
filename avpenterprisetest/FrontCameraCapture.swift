//
//  FrontCameraCapture.swift
//  avpenterprisetest
//
//  Created by Devon Copley on 12/9/24.
//

// Capturing frames from the forward-facing camera.
// Encoding frames using VideoEncoder.
// Notifying listeners when encoded frames are available.

import AVFoundation
import Foundation

class FrontCameraCapture: NSObject {
    private let videoEncoder: VideoEncoder
    private let captureSession: AVCaptureSession
    private let videoOutput: AVCaptureVideoDataOutput

    init(width: Int, height: Int, frameRate: Int) {
        // Initialize the video encoder with specified parameters
        self.videoEncoder = VideoEncoder(width: width, height: height, frameRate: frameRate)
        self.captureSession = AVCaptureSession()
        self.videoOutput = AVCaptureVideoDataOutput()
        super.init()

        configureCaptureSession()
    }

    private func configureCaptureSession() {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("Failed to access the forward-facing camera")
            return
        }

        do {
            // Lock the camera for configuration
            try camera.lockForConfiguration()

            // Select the best available format
            if let format = camera.formats.first(where: { format in
                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                return dimensions.width >= 640 && dimensions.height >= 480
            }) {
                camera.activeFormat = format
                camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30) // 30 FPS
                camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
                print("Selected camera format: \(format)")
            } else {
                print("No compatible format found")
            }

            camera.unlockForConfiguration()
        } catch {
            print("Failed to configure the camera: \(error)")
            return
        }

        // Configure the session
        captureSession.beginConfiguration()

        // Add the camera input to the session
        guard let videoInput = try? AVCaptureDeviceInput(device: camera),
              captureSession.canAddInput(videoInput) else {
            print("Cannot add camera input to the session")
            captureSession.commitConfiguration() // Commit configuration before returning
            return
        }
        captureSession.addInput(videoInput)

        // Configure video output
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video.capture.queue"))
        guard captureSession.canAddOutput(videoOutput) else {
            print("Cannot add video output to the session")
            captureSession.commitConfiguration() // Commit configuration before returning
            return
        }
        captureSession.addOutput(videoOutput)

        captureSession.commitConfiguration() // Commit configuration before starting the session
    }

    func start() {
        captureSession.startRunning()
        print("Capture session started")
    }

    func stop() {
        captureSession.stopRunning()
        print("Capture session stopped")
    }
}

extension FrontCameraCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get pixel buffer from sample buffer")
            return
        }

        // Get the presentation timestamp
        let presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        // Encode the frame
        videoEncoder.encode(pixelBuffer: pixelBuffer, presentationTimeStamp: presentationTimeStamp)
    }
}
