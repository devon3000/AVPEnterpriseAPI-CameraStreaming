//
//  YouTubeStreamManager.swift
//  avpenterprisetest
//
//  Created by Devon Copley on 12/4/24.
//
import HaishinKit
import Foundation
import AVFoundation
import VideoToolbox

// Extend Notification.Name to include a custom name for RTMP status notifications
extension Notification.Name {
    static let rtmpStatus = Notification.Name("rtmpStatus")
}


class YouTubeStreamManager {
    private let rtmpConnection = RTMPConnection()
    private var rtmpStream: RTMPStream!
    private let rtmpURL = "rtmp://a.rtmp.youtube.com/live2"
    private let streamKey = "syw0-13w1-j29p-xumw-43jv" // Replace with your actual stream key
    private var currentCameraPosition: AVCaptureDevice.Position = .front
    //private let audioCapture = AudioCapture()
    private var audioHandler: AudioHandler?
    private var frontCameraCapture: FrontCameraCapture?
    private let mixer = MediaMixer()

    init() {
        rtmpStream = RTMPStream(connection: rtmpConnection)
    }
    
    // MARK: - Setup Methods

    private func setupRTMPStream() async throws {
        rtmpStream = RTMPStream(connection: rtmpConnection)

        // Configure audio settings
        var audioSettings = AudioCodecSettings()
        audioSettings.bitRate = 64 * 1000
        audioSettings.downmix = true
        await rtmpStream.setAudioSettings(audioSettings)

        // Configure video settings
        var videoSettings = VideoCodecSettings(
            videoSize: .init(width: 854, height: 480),
            bitRate: 640 * 1000,
            profileLevel: kVTProfileLevel_H264_Baseline_3_1 as String,
            scalingMode: .trim,
            bitRateMode: .average,
            maxKeyFrameIntervalDuration: 2,
            isHardwareEncoderEnabled: true
        )
        await rtmpStream.setVideoSettings(videoSettings)

        // Initialize the AudioHandler
        let handler = AudioHandler(mixer: mixer)
        self.audioHandler = handler

        // Initialize the FrontCameraCapture
        let capture = FrontCameraCapture(width: 854, height: 480, frameRate: 30)
        self.frontCameraCapture = capture

        // Connect the MediaMixer to RTMPStream
        await mixer.addOutput(rtmpStream)

        print("[Info] Mixer output connected to RTMPStream.")
    }
    
    
    func attachPersonaVideo() async throws {
        do {
            // Optionally configure Video
            if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                try await mixer.attachVideo(camera)
                print("Camera attached successfully.")
            } else {
                print("Front camera not available.")
            }
        } catch {
            throw NSError(domain: "StreamConfigurationError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Error configuring stream: \(error)"])
        }
    }

    private func setupFrontCameraCapture() {
         let capture = FrontCameraCapture(width: 854, height: 480, frameRate: 30)
         self.frontCameraCapture = capture

         // Listen for encoded frames
         NotificationCenter.default.addObserver(
             self,
             selector: #selector(handleEncodedFrame(notification:)),
             name: .didEncodeFrame,
             object: nil
         )

         capture.start()
     }

    @objc private func handleEncodedFrame(notification: Notification) {
        // Directly cast the notification object as CMSampleBuffer
        let sampleBuffer = notification.object as! CMSampleBuffer

        Task {
            await mixer.append(sampleBuffer)
        }
    }

   
    // MARK: - Streaming Control

    func startStreaming() async {
        print("[Info] Starting video + audio stream...")
        do {
            // Step 1: Set up the RTMP stream (audio, video, mixer setup)
            try await setupRTMPStream()

            // Step 2: Connect to the RTMP server
            print("[Info] Connecting to RTMP server...")
            let connectResponse = try await rtmpConnection.connect(rtmpURL)
            print("[Info] RTMP connection response: \(connectResponse)")

            // Step 3: Publish the stream
            print("[Info] Publishing stream...")
            let publishResponse = try await rtmpStream.publish(streamKey)
            print("[Info] RTMP publish response: \(publishResponse)")

            // Step 4: Start media data flow
            startMediaFlow()
        } catch {
            print("[Error] Starting streaming failed: \(error.localizedDescription)")
            retryStreaming()
        }
    }

    private func startMediaFlow() {
        // Step 4a: Start audio processing
        audioHandler?.configureAudio()
        print("[Info] AudioHandler started.")

        // Step 4b: Start video capture
        frontCameraCapture?.start()
        print("[Info] FrontCameraCapture started.")
    }
    
    private func retryStreaming() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            Task {
                await self.startStreaming()
            }
        }
    }
    
    func stopStreaming() async {
        print("Stopping the stream...")
        do {
            try await rtmpStream.close()
            try await rtmpConnection.close()
            print("Stream stopped successfully.")
        } catch {
            print("Error stopping the stream: \(error)")
        }
    }

    // MARK: - RTMP Monitoring
    
    func startMonitoringRTMPConnection() {
        print("[Debug] Setting up RTMP status monitoring...")
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRTMPStatus(notification:)),
            name: .rtmpStatus,
            object: rtmpConnection
        )
    }

    
    
    @objc private func handleRTMPStatus(notification: Notification) {
        guard let data = notification.userInfo as? [String: Any],
              let status = data["code"] as? String else {
            print("[Warning] No RTMP status data available.")
            return
        }

        // Handle different RTMP connection states
        switch status {
        case RTMPConnection.Code.connectSuccess.rawValue:
            print("[Info] RTMP: Connection successful.")
        case RTMPConnection.Code.connectFailed.rawValue:
            print("[Error] RTMP: Connection failed.")
        default:
            print("[Info] RTMP: Status code \(status)")
        }
    }
}



