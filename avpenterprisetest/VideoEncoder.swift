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
    let kVTCompressionPropertyKey_EmitSPSAndPPS = "EmitSPSAndPPS" as CFString

    init(width: Int, height: Int, frameRate: Int = 30) {
        // Calculate frame duration based on frame rate
        self.frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))

        let encoderPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let status = VTCompressionSessionCreate(
            allocator: nil,
            width: Int32(width),
            height: Int32(height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: VideoEncoder.videoOutputCallback,
            refcon: encoderPointer,
            compressionSessionOut: &compressionSession
        )
        guard status == noErr else {
            print("Failed to create compression session: \(status)")
            return
        }

        // Configure compression session
        VTSessionSetProperty(compressionSession!, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Baseline_3_1 as CFTypeRef) // Baseline profile
        VTSessionSetProperty(compressionSession!, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue) // Real-time encoding
        VTSessionSetProperty(compressionSession!, key: kVTCompressionPropertyKey_AverageBitRate, value: 2_000_000 as CFTypeRef) // 2 Mbps average bitrate
        VTSessionSetProperty(compressionSession!, key: kVTCompressionPropertyKey_DataRateLimits, value: [2_000_000, 1] as CFArray) // Max bitrate limit
        VTSessionSetProperty(compressionSession!, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse) // Disable B-frames
        VTSessionSetProperty(compressionSession!, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: 30 as CFTypeRef) // Force keyframe every 30 frames
        VTSessionSetProperty(compressionSession!, key: kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, value: 2 as CFTypeRef) // Force keyframe every 2 seconds
        VTSessionSetProperty(compressionSession!, key: kVTCompressionPropertyKey_EmitSPSAndPPS, value: kCFBooleanTrue) // Emit SPS/PPS with keyframes
    }

   
    func encode(pixelBuffer: CVPixelBuffer, presentationTimeStamp: CMTime) {
        guard let session = compressionSession else {
            print("Compression session is not initialized")
            return
        }

        // force keyframes (DEBUG)
        let frameProperties: [NSString: Any] = [
            kVTEncodeFrameOptionKey_ForceKeyFrame: true
        ]
        

        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: presentationTimeStamp,
            duration: frameDuration,
            frameProperties: frameProperties as CFDictionary,
            sourceFrameRefcon: nil,
            infoFlagsOut: nil
        )

        if status != noErr {
            print("Failed to encode frame: \(status)")
        } else {
            print("Encoded frame with PTS: \(presentationTimeStamp)")
        }
    }

    static let videoOutputCallback: VTCompressionOutputCallback = { refcon, sourceFrameRefCon, status, infoFlags, sampleBuffer in
        guard status == noErr, let sampleBuffer = sampleBuffer else {
            print("Encoding error or missing sample buffer")
            return
        }

        // Retain the sampleBuffer before posting it
        CMSampleBufferGetDataBuffer(sampleBuffer)
        
        // Log frame details
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        print("Callback of video frame with PTS: \(pts)")

        // Check if frame is a keyframe
        if let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false),
           let rawAttachments = CFArrayGetValueAtIndex(attachmentsArray, 0) {
            let attachments = Unmanaged<CFDictionary>.fromOpaque(rawAttachments).takeUnretainedValue()

            // Debug: Log all key-value pairs in attachments dictionary
            CFDictionaryApplyFunction(attachments, { key, value, _ in
                guard let key = key, let value = value else { return }
                
                // Convert the key to CFString
                let keyString = Unmanaged<CFString>.fromOpaque(key).takeUnretainedValue() as String
                
                // Convert the value to CFType
                let cfValue = Unmanaged<CFTypeRef>.fromOpaque(value).takeUnretainedValue()
                
                // Determine the type of the value
                if CFGetTypeID(cfValue) == CFBooleanGetTypeID() {
                    let boolValue = cfValue as! CFBoolean
                    print("Attachment Key: \(keyString), Value: \(boolValue == kCFBooleanTrue ? "true" : "false")")
                } else if CFGetTypeID(cfValue) == CFNumberGetTypeID() {
                    let numberValue = cfValue as! CFNumber
                    print("Attachment Key: \(keyString), Value: \(numberValue)")
                } else if CFGetTypeID(cfValue) == CFStringGetTypeID() {
                    let stringValue = cfValue as! CFString
                    print("Attachment Key: \(keyString), Value: \(stringValue)")
                } else {
                    print("Attachment Key: \(keyString), Value: Unknown type")
                }
            }, nil)

            // Check for keyframe (kCMSampleAttachmentKey_NotSync)
            let notSyncValuePointer = CFDictionaryGetValue(attachments, Unmanaged.passUnretained(kCMSampleAttachmentKey_NotSync).toOpaque())

            if let notSyncValuePointer = notSyncValuePointer {
                let notSyncValue = Unmanaged<CFBoolean>.fromOpaque(notSyncValuePointer).takeUnretainedValue()
                if CFEqual(notSyncValue, kCFBooleanFalse) {
                    print("Keyframe detected")
                } else {
                    print("Non-keyframe detected")
                }
            } else {
                print("Keyframe determination failed (notSyncValuePointer is nil)")
            }
        } else {
            print("Failed to determine if the frame is a keyframe")
        }


        // SPS/PPS emission debugging
        if let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) {
            var sps: UnsafePointer<UInt8>?
            var spsLength: Int = 0
            var pps: UnsafePointer<UInt8>?
            var ppsLength: Int = 0

            let status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                formatDesc,
                parameterSetIndex: 0,
                parameterSetPointerOut: &sps,
                parameterSetSizeOut: &spsLength,
                parameterSetCountOut: nil,
                nalUnitHeaderLengthOut: nil
            )

            if status == noErr {
                print("SPS emitted with size: \(spsLength)")
            } else {
                print("Failed to get SPS: \(status)")
            }

            CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                formatDesc,
                parameterSetIndex: 1,
                parameterSetPointerOut: &pps,
                parameterSetSizeOut: &ppsLength,
                parameterSetCountOut: nil,
                nalUnitHeaderLengthOut: nil
            )

            if status == noErr {
                print("PPS emitted with size: \(ppsLength)")
            } else {
                print("Failed to get PPS: \(status)")
            }
        }

        // Post a notification with the sample buffer
        NotificationCenter.default.post(name: .didEncodeFrame, object: sampleBuffer)
    }

    deinit {
        VTCompressionSessionInvalidate(compressionSession!)
    }
}
