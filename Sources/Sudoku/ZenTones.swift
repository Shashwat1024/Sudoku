import AVFoundation
import Foundation

/// Soft synthesized bell tones for Zen mode (no audio files needed).
/// Each digit maps to a note of a pentatonic scale, so any sequence sounds pleasant.
@MainActor
final class ZenTones {
    static let shared = ZenTones()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var format: AVAudioFormat?
    private var started = false

    private static let sampleRate = 44100.0
    // C major pentatonic across two octaves, C4 up to G5.
    private static let scale: [Double] = [
        261.63, 293.66, 329.63, 392.00, 440.00, 523.25, 587.33, 659.25, 783.99,
    ]

    private func startIfNeeded() -> Bool {
        if started { return true }
        // Ambient: mixes with the user's music and respects the silent switch.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1) else {
            return false
        }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: fmt)
        do { try engine.start() } catch { return false }
        format = fmt
        started = true
        return true
    }

    func play(digit: Int) {
        guard (1...9).contains(digit), startIfNeeded(), let fmt = format else { return }
        let freq = Self.scale[digit - 1]
        let frames = AVAudioFrameCount(Self.sampleRate * 1.2)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0]
        else { return }
        buffer.frameLength = frames
        for i in 0..<Int(frames) {
            let t = Double(i) / Self.sampleRate
            // Quick attack, long exponential decay: a soft bell.
            let envelope = exp(-3.2 * t) * min(1, t / 0.005)
            let wave = sin(2 * .pi * freq * t) + 0.3 * sin(4 * .pi * freq * t)
            channel[i] = Float(0.18 * envelope * wave)
        }
        player.scheduleBuffer(buffer, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }
}
