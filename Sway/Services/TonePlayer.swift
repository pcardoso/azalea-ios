import AVFoundation

/// Synthesised beeps for the guided exercise session. Mixes with other audio (music, podcasts)
/// and plays even with the silent switch on, like a workout timer.
final class TonePlayer {
    enum Tone {
        /// Short C major chord when switching between hold and rest.
        case transition
        /// Rising I–IV–V progression (C, F, G) when a new repetition starts.
        case newRepetition
        /// Countdown tick for the last 3 seconds of a long step.
        case tick
        /// "Ta-da": quick rising arpeggio into a held C major chord when the session is done.
        case celebration
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    // Note frequencies (Hz) in the 5th/6th octave.
    private static let c5 = 523.25, e5 = 659.25, f5 = 698.46, g5 = 783.99
    private static let a5 = 880.0, b5 = 987.77, c6 = 1_046.5, d6 = 1_174.66

    private lazy var buffers: [Tone: AVAudioPCMBuffer] = [
        .transition: makeBuffer([([Self.c5, Self.e5, Self.g5], 0.25)], volume: 0.45),
        .newRepetition: makeBuffer([
            ([Self.c5, Self.e5, Self.g5], 0.18),
            ([Self.f5, Self.a5, Self.c6], 0.18),
            ([Self.g5, Self.b5, Self.d6], 0.4),
        ], volume: 0.8),
        .tick: makeBuffer([([660], 0.08)], volume: 0.35),
        .celebration: makeBuffer([
            ([Self.c5], 0.09),
            ([Self.e5], 0.09),
            ([Self.g5], 0.09),
            ([Self.c5, Self.e5, Self.g5, Self.c6, Self.c6 * 1.25], 1.1),
        ], volume: 0.8),
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

    /// Builds a buffer from (chord frequencies, seconds) segments played back to back.
    private func makeBuffer(_ segments: [([Double], Double)], volume: Float) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let totalFrames = AVAudioFrameCount(segments.reduce(0) { $0 + $1.1 } * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames)!
        buffer.frameLength = totalFrames
        let samples = buffer.floatChannelData![0]
        var offset = 0
        for (chord, seconds) in segments {
            let frames = Int(seconds * sampleRate)
            let attack = min(Int(0.01 * sampleRate), frames / 2)
            for i in 0..<frames {
                let t = Double(i) / sampleRate
                // Quick attack, then a bell-like decay to silence at the end of the segment.
                let rise = min(1, Double(i) / Double(max(attack, 1)))
                let decay = exp(-4 * t / seconds) * Double(frames - i) / Double(frames)
                let value = chord.reduce(0) { $0 + sin(2 * .pi * $1 * t) } / Double(max(chord.count, 1))
                samples[offset + i] = Float(value * rise * decay) * volume
            }
            offset += frames
        }
        return buffer
    }
}
