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
    private let mixer = MediaMixer()

    init() {
        rtmpStream = RTMPStream(connection: rtmpConnection)
    }
    
    // MARK: - Setup Methods

    private func setupRTMPStream() async throws {
        rtmpStream = RTMPStream(connection: rtmpConnection)

        // Create and configure AudioCodecSettings
        var audioSettings = AudioCodecSettings()
        audioSettings.bitRate = 64 * 1000  // Set bitrate to 64 kbps
        audioSettings.downmix = true       // Enable downmixing for multi-channel input
        audioSettings.channelMap = nil     // Optional: Specify channel mapping if needed

        // Apply the audio settings to the stream
        await rtmpStream.setAudioSettings(audioSettings)

        // Create and configure VideoCodecSettings
        var videoSettings = VideoCodecSettings(
            videoSize: .init(width: 854, height: 480),  // Set video resolution
            bitRate: 640 * 1000,  // Set bitrate to 640 kbps
            profileLevel: kVTProfileLevel_H264_Baseline_3_1 as String,  // Set H.264 profile level
            scalingMode: .trim,  // Set scaling mode
            bitRateMode: .average,  // Set bitrate mode
            maxKeyFrameIntervalDuration: 2,  // Set keyframe interval duration
            allowFrameReordering: nil,  // Optional: Allow frame reordering
            isHardwareEncoderEnabled: true  // Enable hardware encoding
        )

        // Apply the video settings to the stream
        await rtmpStream.setVideoSettings(videoSettings)
        
        // Initialize the AudioHandler asynchronously
        let handler = AudioHandler(mixer: mixer)
        handler.configureAudio() // This is synchronous within the AudioHandler
        self.audioHandler = handler

        // Connect MediaMixer output to RTMPStream
        await mixer.addOutput(rtmpStream)
        print("Mixer output successfully connected to RTMPStream.")
        
        try await configureStream()

        // Add event listener for RTMP connection status
        //rtmpConnection.addEventListener(.rtmpStatus, selector: #selector(handleRTMPEvent), observer: self)
    }
    
    
    func configureStream() async throws {
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


   
    // MARK: - Streaming Control

    func startStreaming() async {
        print("[Info] Starting video + audio stream...")
        
        do {
            print ("Calling setupRTMPStream")
            try await setupRTMPStream()
            print("setupRTMPStream returned successfully")
        } catch {
            print("Error setupRTMPStream: \(error)")
        }
        
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



