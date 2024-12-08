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

class YouTubeStreamManager {
    private let rtmpConnection = RTMPConnection()
    private let rtmpStream: RTMPStream
    private var videoEncoder: VideoEncoder? // Declare the encoder instance

    private let rtmpURL = "rtmp://a.rtmp.youtube.com/live2" // hard-coded stream key for now
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
    
}

