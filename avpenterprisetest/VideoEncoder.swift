//
//  VideoEncoder.swift
//  avpenterprisetest
//
//  Created by Devon Copley on 12/4/24.
//

import VideoToolbox
import Foundation

extension NSNotification.Name {
    static let didEncodeFrame = NSNotification.Name("didEncodeFrame")
}

class VideoEncoder {
    private var compressionSession: VTCompressionSession?
    private let frameDuration: CMTime

    init(width: Int, height: Int, frameRate: Int = 30) {
        // Calculate frame duration based on frame rate
        self.frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        
        let status = VTCompressionSessionCreate(
            allocator: nil,
            width: Int32(width),
            height: Int32(height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: { _, _, status, infoFlags, sampleBuffer in
                guard status == noErr, let sampleBuffer = sampleBuffer else {
                    print("Encoding error or missing sample buffer")
                    return
                }
                // Handle the encoded frame
                VideoEncoder.handleEncodedFrame(sampleBuffer)
            },
            refcon: nil,
            compressionSessionOut: &compressionSession
        )

        guard status == noErr else {
            print("Failed to create compression session: \(status)")
            return
        }

        // Configure compression session
        VTSessionSetProperty(compressionSession!, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Baseline_3_1 as CFTypeRef)
        VTSessionSetProperty(compressionSession!, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(compressionSession!, key: kVTCompressionPropertyKey_AverageBitRate, value: 2_000_000 as CFTypeRef)
        VTSessionSetProperty(compressionSession!, key: kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, value: 2 as CFTypeRef) // Max 2-second interval for keyframes
    }

    func encode(pixelBuffer: CVPixelBuffer, presentationTimeStamp: CMTime) {
        guard let session = compressionSession else {
            print("Compression session is not initialized")
            return
        }

        var timingInfo = CMSampleTimingInfo(
            duration: frameDuration, // Set duration for each frame
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: .invalid // If not using B-frames
        )

        // Encode the frame
        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: presentationTimeStamp,
            duration: frameDuration,
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: nil
        )

        if status != noErr {
            print("Failed to encode frame: \(status)")
        } else {
            print("Encoded frame with PTS: \(presentationTimeStamp)")
        }
    }

    private static func handleEncodedFrame(_ sampleBuffer: CMSampleBuffer) {
        // Post a notification with the encoded sample buffer
        NotificationCenter.default.post(name: .didEncodeFrame, object: sampleBuffer)
    }

    deinit {
        VTCompressionSessionInvalidate(compressionSession!)
    }
}
