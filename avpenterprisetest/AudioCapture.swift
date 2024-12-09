//
//  AudioCapture.swift
//  avpenterprisetest
//
//  Created by Devon Copley on 12/8/24.
//

import AVFoundation

protocol AudioCaptureDelegate: AnyObject {
    func audioCapture(_ audioCapture: AudioCapture, buffer: AVAudioBuffer, time: AVAudioTime)
}

final class AudioCapture {
    var isRunning = false
    weak var delegate: AudioCaptureDelegate?
    private let audioEngine = AVAudioEngine()

    func startRunning() {
        guard !isRunning else {
            return
        }
        let input = audioEngine.inputNode
        let mixer = audioEngine.mainMixerNode
        audioEngine.connect(input, to: mixer, format: input.inputFormat(forBus: 0))
        input.installTap(onBus: 0, bufferSize: 1024, format: input.inputFormat(forBus: 0)) { buffer, when in
            self.delegate?.audioCapture(self, buffer: buffer, time: when)
        }
        do {
            try audioEngine.start()
            isRunning = true
        } catch {
            print("Error starting audio engine: \(error.localizedDescription)")
        }
    }

    func stopRunning() {
        guard isRunning else {
            return
        }
        audioEngine.stop()
        isRunning = false
    }
}
