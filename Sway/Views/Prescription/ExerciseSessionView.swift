import SwiftUI

/// Guided hold/rest session: a circle grows while holding and shrinks while resting.
struct ExerciseSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(ExerciseRunStore.self) private var exerciseRuns
    let steps: [ExerciseStep]
    var prescriptionId: Int?

    @State private var index = 0
    @State private var elapsedBeforePause: TimeInterval = 0
    @State private var stepStartedAt = Date.now
    @State private var paused = false
    @State private var finished = false
    @State private var confirmingExit = false
    @State private var tones = TonePlayer()
    @State private var startedAt = Date.now
    @State private var recorded = false
    @State private var pausedForDialog = false
    /// Ring rotation and spin banked from previous steps, so reversing direction doesn't jump.
    @State private var ringBaseAngle: Double = 0
    @State private var ringStartVelocity: Double = Self.ringSpeed

    /// Degrees per second for the wavy rings; they turn one way while holding, the other while resting.
    private static let ringSpeed: Double = 12
    /// Seconds for the spin to ease toward its new direction, like a flywheel reversing.
    private static let ringInertia: Double = 0.8

    private var step: ExerciseStep? { steps.indices.contains(index) ? steps[index] : nil }

    private func stepElapsed(at now: Date) -> TimeInterval {
        paused ? elapsedBeforePause : elapsedBeforePause + now.timeIntervalSince(stepStartedAt)
    }

    /// Velocity decays exponentially toward the step's target spin; the angle is its integral.
    private func ringMotion(for step: ExerciseStep, at now: Date) -> (angle: Double, velocity: Double) {
        let target = (step.action == .hold ? 1 : -1) * Self.ringSpeed
        let t = stepElapsed(at: now)
        let tau = Self.ringInertia
        let decay = exp(-t / tau)
        let angle = ringBaseAngle + target * t + (ringStartVelocity - target) * tau * (1 - decay)
        return (angle, target + (ringStartVelocity - target) * decay)
    }

    var body: some View {
        NavigationStack {
            Group {
                if finished || steps.isEmpty {
                    finishedView
                } else if let step {
                    TimelineView(.periodic(from: .now, by: 0.1)) { context in
                        running(step, now: context.date)
                    }
                }
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if finished { dismiss() } else { confirmingExit = true }
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(Text("Close"))
                }
            }
            .confirmationDialog("End session?", isPresented: $confirmingExit, titleVisibility: .visible) {
                Button("Terminate", role: .destructive) { terminate() }
            } message: {
                Text("Your progress so far will be shared with your therapist.")
            }
            .onChange(of: confirmingExit) { _, showing in
                // Hold the timer while deciding; resume if the patient cancels.
                if showing, !paused, !finished {
                    togglePause()
                    pausedForDialog = true
                } else if !showing, pausedForDialog {
                    pausedForDialog = false
                    if paused { togglePause() }
                }
            }
        }
        .onAppear {
            startedAt = .now
            UIApplication.shared.isIdleTimerDisabled = true
            tones.start()
            tones.play(.newRepetition)
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            tones.stop()
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: index)
        .sensoryFeedback(.success, trigger: finished)
    }

    private func running(_ step: ExerciseStep, now: Date) -> some View {
        let elapsed = stepElapsed(at: now)
        let remaining = max(0, Double(step.duration) - elapsed)
        let secondsLeft = Int(remaining.rounded(.up))
        let isHold = step.action == .hold
        // Long steps get an emphasised 3-2-1 so attention doesn't drift before the switch.
        let countingDown = step.duration > 5 && (1...3).contains(secondsLeft)

        return VStack(spacing: 32) {
            ProgressView(value: Double(index), total: Double(steps.count))

            VStack(spacing: 4) {
                Text(isHold ? "Squeeze and hold" : "Relax")
                    .font(.largeTitle.bold())
                Text("Exercise \(step.exerciseIndex + 1) of \(step.exerciseCount) · Rep \(step.repetition + 1) of \(step.repetitionCount) · Set \(step.set + 1) of \(step.setCount)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            let fill = (isHold ? Color.pink : Color.mint).gradient
            let fillAnimation = Animation.easeInOut(duration: Double(max(step.duration, 1)) * 0.8)

            ZStack {
                Circle()
                    .fill(fill)
                    .scaleEffect(isHold ? 1 : 0.45)
                    .animation(fillAnimation, value: index)
                Text(secondsLeft, format: .number)
                    .font(.system(size: 72, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .foregroundStyle(.white)
                    .scaleEffect(countingDown ? 1.5 : 1)
                    .animation(.spring(duration: 0.3), value: secondsLeft)
            }
            .frame(width: 260, height: 260)
            .background {
                // Fixed-size rings just outside the full circle, counter-rotating; they never scale.
                // The wave turns inside the path so the gradient stays upright like the circle's.
                // Neighbouring rings overlap slightly.
                TimelineView(.animation(paused: paused)) { context in
                    let angle = ringMotion(for: step, at: context.date).angle
                    let rings = [
                        (shape: WavyRing(rotation: .degrees(angle)), width: 4.0, size: 300.0),
                        (shape: WavyRing(rotation: .degrees(-angle), waves: 18), width: 6.0, size: 332.0),
                    ]
                    ZStack {
                        ForEach(rings.indices, id: \.self) { i in
                            let ring = rings[i]
                            ring.shape
                                .stroke(fill, style: StrokeStyle(lineWidth: ring.width, lineCap: .round))
                                .frame(width: ring.size, height: ring.size)
                        }
                    }
                    .animation(fillAnimation, value: index)
                }
                .accessibilityHidden(true)
            }

            Text(isHold ? "Relax in \(secondsLeft)…" : "Squeeze in \(secondsLeft)…")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
                .opacity(countingDown ? 1 : 0)
                .offset(y: 20)

            Spacer()

            HStack(spacing: 40) {
                Button {
                    advance(to: index - 1)
                } label: {
                    Image(systemName: "backward.fill")
                }
                .disabled(index == 0)
                .accessibilityLabel(Text("Previous"))

                Button {
                    togglePause()
                } label: {
                    Image(systemName: paused ? "play.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 64))
                }
                .accessibilityLabel(paused ? Text("Resume") : Text("Pause"))

                Button {
                    advance(to: index + 1)
                } label: {
                    Image(systemName: "forward.fill")
                }
                .accessibilityLabel(Text("Next"))
            }
            .font(.title)

            Button("Terminate", role: .destructive) {
                confirmingExit = true
            }
            .buttonStyle(.bordered)
        }
        .onChange(of: remaining <= 0) { _, done in
            if done, !paused { advance(to: index + 1) }
        }
        .onChange(of: secondsLeft) { _, seconds in
            if countingDown, !paused, seconds > 0 { tones.play(.tick) }
        }
    }

    private var finishedView: some View {
        ContentUnavailableView {
            Label("Well done!", systemImage: "checkmark.seal.fill")
                .foregroundStyle(.green)
        } description: {
            Text("You finished today's exercises.")
        } actions: {
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .overlay {
            if !steps.isEmpty {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
    }

    private func terminate() {
        record(terminatedEarly: true)
        dismiss()
    }

    /// Saves the run once, locally first, then sends it like a diary entry.
    private func record(terminatedEarly: Bool) {
        guard !recorded, !steps.isEmpty else { return }
        recorded = true
        let run = ExerciseRun(
            prescriptionId: prescriptionId,
            startedAt: startedAt,
            endedAt: .now,
            completedSteps: terminatedEarly ? index : steps.count,
            totalSteps: steps.count,
            terminatedEarly: terminatedEarly
        )
        let token = session.submissionToken
        Task { await exerciseRuns.add(run, token: token) }
    }

    private func togglePause() {
        if paused {
            stepStartedAt = .now
        } else {
            elapsedBeforePause += Date.now.timeIntervalSince(stepStartedAt)
        }
        paused.toggle()
    }

    private func advance(to newIndex: Int) {
        if let step {
            let motion = ringMotion(for: step, at: .now)
            ringBaseAngle = motion.angle
            ringStartVelocity = motion.velocity
        }
        elapsedBeforePause = 0
        stepStartedAt = .now
        if newIndex >= steps.count {
            finished = true
            tones.play(.celebration)
            record(terminatedEarly: false)
        } else {
            index = max(0, newIndex)
            // A hold starts a new repetition; switching to rest gets the short beep.
            tones.play(steps[index].action == .hold ? .newRepetition : .transition)
        }
    }
}

/// A circle whose edge undulates in a sine wave.
nonisolated private struct WavyRing: Shape {
    var rotation: Angle = .zero
    var waves = 14
    var amplitude: CGFloat = 4

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - amplitude
        let segments = 360
        var path = Path()
        for i in 0...segments {
            let theta = Double(i) / Double(segments) * 2 * .pi
            let r = radius + amplitude * sin(Double(waves) * (theta - rotation.radians))
            let point = CGPoint(x: center.x + r * cos(theta), y: center.y + r * sin(theta))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    ExerciseSessionView(steps: [
        ExerciseStep(action: .hold, duration: 3, exerciseIndex: 0, exerciseCount: 1, repetition: 0, repetitionCount: 2, set: 0, setCount: 1),
        ExerciseStep(action: .rest, duration: 3, exerciseIndex: 0, exerciseCount: 1, repetition: 0, repetitionCount: 2, set: 0, setCount: 1),
    ])
    .environment(SessionStore())
    .environment(ExerciseRunStore())
}
