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

extension YouTubeStreamManager: AudioCaptureDelegate {
    func audioCapture(_ audioCapture: AudioCapture, buffer: AVAudioBuffer, time: AVAudioTime) {
        rtmpStream.append(buffer, when: time)
    }
}

class YouTubeStreamManager {
    private let rtmpConnection = RTMPConnection()
    private var rtmpStream: RTMPStream!
    private let rtmpURL = "rtmp://a.rtmp.youtube.com/live2"
    private let streamKey = "syw0-13w1-j29p-xumw-43jv" // Replace with your actual stream key
    private var currentCameraPosition: AVCaptureDevice.Position = .front
    private let audioCapture = AudioCapture()

    init() {
        
        setupRTMPStream()
        startMonitoringRTMPConnection()
    }

    
    // MARK: - Setup Methods

    private func setupRTMPStream() {
        rtmpStream = RTMPStream(connection: rtmpConnection)

        // Configure audio settings
        rtmpStream.audioSettings.bitRate = 32_000 // 32 kbps

        // Configure video settings using VideoCodecSettings
        rtmpStream.videoSettings = VideoCodecSettings(
            videoSize: .init(width: 1280, height: 720),
            bitRate: 2_000_000, // 2 Mbps
            profileLevel: kVTProfileLevel_H264_Baseline_AutoLevel as String
        )
        
        attachVideo()
        
        // Set up audio capture using AVAudioEngine (attachAudio is not included in visionOS build of Haishinkit)
        audioCapture.delegate = self
        audioCapture.startRunning()
        
        // Add event listener for RTMP connection status
        rtmpConnection.addEventListener(.rtmpStatus, selector: #selector(handleRTMPEvent), observer: self)
    }


    private func attachVideo() {
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition) else {
            print("No video device found.")
            return
        }

        do {
            try videoDevice.lockForConfiguration()
            videoDevice.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30) // 30 FPS
            videoDevice.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30) // 30 FPS
            videoDevice.unlockForConfiguration()
        } catch {
            print("Error configuring video device: \(error.localizedDescription)")
            return
        }

        rtmpStream.attachCamera(videoDevice) { _, error  in
            if let error {
                print(error)
            }
        }
        print("Video device attached: \(currentCameraPosition == .front ? "Front" : "Back").")
    }

    // MARK: - Streaming Control

    func startStreaming() {
        print("[Info] Starting video + audio stream...")

        Task {
            do {
                // Connect to RTMP server
                let connectResponse = try await rtmpConnection.connect(rtmpURL)
                print("[Info] RTMP connection response: \(connectResponse)")

                // Publish the stream
                let publishResponse = try await rtmpStream.publish(streamKey)
                print("[Info] RTMP publish response: \(publishResponse)")

                print("[Info] Streaming started successfully.")
            } catch {
                print("[Error] Starting streaming failed: \(error.localizedDescription)")
            }
        }
    }

    func stopStreaming() {
        print("Stopping the stream...")
        rtmpStream.close()
        rtmpConnection.close()
        print("Stream stopped successfully.")
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

    @objc private func handleRTMPEvent(notification: Notification) {
        let event = Event.from(notification) // `Event.from` is not optional
        print("RTMP Event: \(event)")

        if let data = event.data as? [String: Any], let code = data["code"] as? String {
            switch code {
            case RTMPConnection.Code.connectSuccess.rawValue:
                print("RTMP: Connection successful.")
            case RTMPConnection.Code.connectFailed.rawValue:
                print("RTMP: Connection failed.")
            case RTMPStream.Code.publishStart.rawValue:
                print("RTMP: Stream publishing started.")
            case RTMPStream.Code.unpublishSuccess.rawValue:
                print("RTMP: Stream unpublished successfully.")
            default:
                print("RTMP: Unknown status code \(code)")
            }
        }
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

    /*
    func configureMixer() async throws {
        // Configure video device
        if let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
            do {
                try videoDevice.lockForConfiguration()
                // Set frame rate to 30 fps
                videoDevice.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
                videoDevice.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
                videoDevice.unlockForConfiguration()
            } catch {
                print("Error configuring video device: \(error.localizedDescription)")
                throw error
            }
            
            // Attach the configured video device to the mixer
            try await mixer.attachVideo(videoDevice)
            print("Video device attached to mixer.")
        } else {
            throw NSError(domain: "configureMixer", code: -1, userInfo: [NSLocalizedDescriptionKey: "No supported video device found."])
        }
        
        // Configure audio device
        
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            try await mixer.attachAudio(audioDevice)
            print("Audio device attached to mixer.")
        } else {
            print("No audio device found.")
        }
    }
 
 init() {
     rtmpStream = RTMPStream(connection: rtmpConnection)
 }
 
    private func configureStream() async {
        
        // Create a VideoCodecSettings instance
        let videoSettings = VideoCodecSettings(
            videoSize: .init(width: 1280, height: 720), // Set desired resolution
            bitRate: 2_000_000, // Bitrate in bps
            profileLevel: kVTProfileLevel_H264_Baseline_3_1 as String, // H.264 profile level
            scalingMode: .trim, // Scaling mode
            bitRateMode: .average, // Bitrate mode
            maxKeyFrameIntervalDuration: 2, // Keyframe interval in seconds
            allowFrameReordering: nil, // Frame reordering (optional)
            isHardwareEncoderEnabled: true // Use hardware encoder
        )

        // Apply video settings to the RTMP stream
        await rtmpStream.setVideoSettings(videoSettings)

        // Optional: Audio settings can be configured separately if needed
        let audioSettings = AudioCodecSettings(
            bitRate: 32_000 // Audio bitrate in bps
        )

    }
    
    func startStreaming() async {
        print("Starting RTMP streaming to \(rtmpURL)...")
        
        do {
            await configureStream()

            // Initialize the video encoder
            videoEncoder = VideoEncoder(width: 1280, height: 720)
            setupAudioSession()
            
            // Add observer for encoded frames
            NotificationCenter.default.addObserver(self, selector: #selector(handleEncodedFrame(notification:)), name: .didEncodeFrame, object: nil)
                    
            // Attempt connection and publishing
            let response1 = try await rtmpConnection.connect(rtmpURL)
            print("RTMP connection response: \(response1)")
            let response2 = try await rtmpStream.publish("syw0-13w1-j29p-xumw-43jv") // Replace with your stream key
            print("RTMP publish response: \(response2)")

            print("RTMP connection established successfully.")
        } catch RTMPConnection.Error.requestFailed(let response) {
            print("RTMP connection request failed with response: \(response)")
        } catch RTMPStream.Error.requestFailed(let response) {
            print("RTMP stream request failed with response: \(response)")
        } catch {
            print("Failed to establish RTMP connection: \(error.localizedDescription)")
        }
    }

    func stopStreaming() async throws {
        print("Stopping RTMP streaming...")

        do {
            // Attempt to close the stream
            let streamCloseResult = try await rtmpStream.close()
            print("RTMP stream close result: \(streamCloseResult)")

            // Attempt to close the connection
            let connectionCloseResult = try await rtmpConnection.close()
            print("RTMP connection close result: \(connectionCloseResult)")

            print("RTMP streaming stopped successfully.")
        } catch {
            print("Failed to stop RTMP streaming: \(error.localizedDescription)")
            throw error
        }
    }
    
    func sendFrame(pixelBuffer: CVPixelBuffer) {
        guard let encoder = videoEncoder else {
            print("Video encoder is not initialized.")
            return
        }

        let timestamp = CMTime(value: Int64(CACurrentMediaTime() * 1_000_000), timescale: 1_000_000)
        encoder.encode(pixelBuffer: pixelBuffer, presentationTimeStamp: timestamp)
    }

    private func setupAudioSession() {
     do {
     try AVAudioSession.sharedInstance().setCategory(.playAndRecord,
     mode: .default,
     options: [.defaultToSpeaker, .allowBluetooth])
     try AVAudioSession.sharedInstance().setActive(true)
     } catch {
     print(error)
     }
     }


    @objc private func handleEncodedFrame(notification: Notification) {
        let sampleBuffer = notification.object as! CMSampleBuffer

        // Append the sample buffer to the RTMP stream
        Task {
            await rtmpStream.publishVideoData(sampleBuffer)
            print("Appended encoded frame to RTMP stream.")
        }
    }
    */
    


