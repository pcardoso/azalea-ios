import AVFoundation

/// Synthesised beeps for the guided exercise session. Mixes with other audio (music, podcasts)
/// and plays even with the silent switch on, like a workout timer.
final class TonePlayer {
    enum Tone {
        /// Short beep when switching between hold and rest.
        case transition
        /// Three louder beeps when a new repetition starts.
        case newRepetition
        /// Countdown tick for the last 3 seconds of a long step.
        case tick
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private lazy var buffers: [Tone: AVAudioPCMBuffer] = [
        .transition: makeBuffer([(880, 0.15)], volume: 0.5),
        .newRepetition: makeBuffer([(1_046, 0.18), (0, 0.1), (1_046, 0.18), (0, 0.1), (1_046, 0.18)], volume: 0.9),
        .tick: makeBuffer([(660, 0.08)], volume: 0.35),
    ]

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func start() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)
        try? engine.start()
    }

    func stop() {
        player.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func play(_ tone: Tone) {
        guard engine.isRunning, let buffer = buffers[tone] else { return }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }
    }

    /// Builds a buffer from (frequency, seconds) segments; frequency 0 is silence.
    private func makeBuffer(_ segments: [(Double, Double)], volume: Float) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let totalFrames = AVAudioFrameCount(segments.reduce(0) { $0 + $1.1 } * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames)!
        buffer.frameLength = totalFrames
        let samples = buffer.floatChannelData![0]
        var offset = 0
        for (frequency, seconds) in segments {
            let frames = Int(seconds * sampleRate)
            let fade = min(Int(0.01 * sampleRate), frames / 2)
            for i in 0..<frames {
                // Short fade in/out avoids clicks at the edges of each beep.
                let envelope = Float(min(1, Double(min(i, frames - 1 - i)) / Double(max(fade, 1))))
                let value = frequency == 0 ? 0 : sin(2 * .pi * frequency * Double(i) / sampleRate)
                samples[offset + i] = Float(value) * volume * envelope
            }
            offset += frames
        }
        return buffer
    }
}
