//
//  AudioHandler.swift
//  avpenterprisetest
//
//  Created by Devon Copley on 12/9/24.
//

import HaishinKit
import AVFoundation

class AudioHandler {
    private let mixer: MediaMixer
    private let audioEngine = AVAudioEngine()
    private let format: AVAudioFormat

    init(mixer: MediaMixer) {
        self.mixer = mixer
        self.format = audioEngine.inputNode.inputFormat(forBus: 0)
    }

    func configureAudio() {
        let inputNode = audioEngine.inputNode

        // Install a tap to capture audio data
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] (buffer, time) in
            guard let self = self else { return }
            self.processAudioBuffer(buffer, at: time)
        }

        // Start the audio engine
        do {
            try audioEngine.start()
            print("Audio engine started successfully.")
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        guard let audioBuffer = CMSampleBuffer.create(from: buffer, format: format, at: time) else {
            print("Failed to create CMSampleBuffer")
            return
        }
        // Append the buffer asynchronously
        print("Appending audio buffer at time: \(time)")
        Task {
            await mixer.append(audioBuffer)
        }
    }
}

extension CMSampleBuffer {
    static func create(from audioBuffer: AVAudioPCMBuffer, format: AVAudioFormat, at time: AVAudioTime) -> CMSampleBuffer? {
        var sampleBuffer: CMSampleBuffer?

        // Convert AVAudioPCMBuffer to AudioBufferList
        let audioBufferList = audioBuffer.audioBufferList
        
        // Define the timing information for the sample buffer
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: CMTimeScale(format.sampleRate)),
            presentationTimeStamp: time.toCMTime(),
            decodeTimeStamp: .invalid
        )

        // Create the format description
        let formatDescription = try? CMAudioFormatDescription(audioStreamBasicDescription: format.streamDescription.pointee)
        guard let description = formatDescription else { return nil }

        // Create the CMSampleBuffer
        CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: nil,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: description,
            sampleCount: CMItemCount(audioBuffer.frameLength),
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing, // `timing` must be mutable
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )

        return sampleBuffer
    }
}

extension AVAudioTime {
    func toCMTime() -> CMTime {
        let sampleTime = self.sampleTime
        let sampleRate = self.sampleRate
        return CMTimeMake(value: Int64(sampleTime), timescale: Int32(sampleRate))
    }
}
