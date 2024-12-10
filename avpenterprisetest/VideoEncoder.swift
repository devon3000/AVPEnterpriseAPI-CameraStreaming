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
    private var lastInputPTS = CMTime.zero
    private let frameDuration: CMTime
    
    static let videoOutputCallback: VTCompressionOutputCallback = { refcon, sourceFrameRefCon, status, infoFlags, sampleBuffer in
        guard status == noErr, let sampleBuffer = sampleBuffer else {
            print("Encoding failed with status: \(status)")
            return
        }

        // Retrieve the instance of VideoEncoder using the refcon pointer
        let videoEncoder = Unmanaged<VideoEncoder>.fromOpaque(refcon!).takeUnretainedValue()

        // Process the encoded frame
        videoEncoder.processEncodedFrame(sampleBuffer)
    }

    init(width: Int32, height: Int32, frameRate: Int = 30) {
        self.frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))

        var compressionSessionOrNil: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: width,
            height: height,
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: kCFAllocatorDefault,
            outputCallback: VideoEncoder.videoOutputCallback,
            refcon: Unmanaged.passUnretained(self).toOpaque(),
            compressionSessionOut: &compressionSessionOrNil
        )

        guard status == noErr, let session = compressionSessionOrNil else {
            print("Failed to create compression session: \(status)")
            return
        }

        self.compressionSession = session

        // Configure compression session
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Baseline_3_1)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: 2_000_000 as CFTypeRef) // 2 Mbps
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_DataRateLimits, value: [2_000_000, 1] as CFArray)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: frameRate as CFTypeRef) // Keyframe interval

        VTCompressionSessionPrepareToEncodeFrames(session)
    }

    func encode(pixelBuffer: CVPixelBuffer, presentationTimeStamp: CMTime) {
        guard let session = compressionSession else {
            print("Compression session is not initialized")
            return
        }

        // Calculate the frame duration
        var duration = frameDuration
        if lastInputPTS != CMTime.zero {
            duration = CMTimeSubtract(presentationTimeStamp, lastInputPTS)
        }
        lastInputPTS = presentationTimeStamp

        // Define frame properties
        let frameProperties: [NSString: Any] = [
            kVTEncodeFrameOptionKey_ForceKeyFrame: false
        ]

        // Encode the frame
        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: presentationTimeStamp,
            duration: duration,
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

    private func processEncodedFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true) else {
            print("No sample attachments found")
            return
        }

        let dic = Unmanaged<CFDictionary>.fromOpaque(CFArrayGetValueAtIndex(attachments, 0)).takeUnretainedValue()
        let isKeyframe = !CFDictionaryContainsKey(dic, Unmanaged.passUnretained(kCMSampleAttachmentKey_NotSync).toOpaque())
        print("Encoded frame is keyframe: \(isKeyframe)")

        if isKeyframe, let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) {
            extractSPSAndPPS(formatDescription)
        }

        NotificationCenter.default.post(name: .didEncodeFrame, object: sampleBuffer)
    }

    private func extractSPSAndPPS(_ formatDescription: CMFormatDescription) {
        var spsPointer: UnsafePointer<UInt8>?
        var spsLength: Int = 0
        var ppsPointer: UnsafePointer<UInt8>?
        var ppsLength: Int = 0

        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            formatDescription,
            parameterSetIndex: 0,
            parameterSetPointerOut: &spsPointer,
            parameterSetSizeOut: &spsLength,
            parameterSetCountOut: nil,
            nalUnitHeaderLengthOut: nil
        )
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            formatDescription,
            parameterSetIndex: 1,
            parameterSetPointerOut: &ppsPointer,
            parameterSetSizeOut: &ppsLength,
            parameterSetCountOut: nil,
            nalUnitHeaderLengthOut: nil
        )

        if let spsPointer = spsPointer, let ppsPointer = ppsPointer {
            let spsData = Data(bytes: spsPointer, count: spsLength)
            let ppsData = Data(bytes: ppsPointer, count: ppsLength)
            print("SPS: \(spsData as NSData), PPS: \(ppsData as NSData)")
        }
    }

    deinit {
        compressionSession.map { VTCompressionSessionInvalidate($0) }
    }
}
