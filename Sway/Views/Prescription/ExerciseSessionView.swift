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
    /// Ring rotation banked from previous steps, so reversing direction doesn't jump.
    @State private var ringBaseAngle: Double = 0

    /// Degrees per second for the wavy ring; it turns one way while holding, the other while resting.
    private static let ringSpeed: Double = 12

    private var step: ExerciseStep? { steps.indices.contains(index) ? steps[index] : nil }

    private func stepElapsed(at now: Date) -> TimeInterval {
        paused ? elapsedBeforePause : elapsedBeforePause + now.timeIntervalSince(stepStartedAt)
    }

    private func ringAngle(for step: ExerciseStep, at now: Date) -> Double {
        let direction: Double = step.action == .hold ? 1 : -1
        return ringBaseAngle + direction * Self.ringSpeed * stepElapsed(at: now)
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

            ZStack {
                Circle()
                    .fill((isHold ? Color.pink : Color.mint).gradient)
                    .scaleEffect(isHold ? 1 : 0.45)
                    .animation(.easeInOut(duration: Double(max(step.duration, 1)) * 0.8), value: index)
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
                // Fixed-size ring just outside the full circle; only rotates, never scales.
                TimelineView(.animation(paused: paused)) { context in
                    WavyRing()
                        .stroke((isHold ? Color.pink : Color.mint).opacity(0.6), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 300, height: 300)
                        .rotationEffect(.degrees(ringAngle(for: step, at: context.date)))
                }
                .accessibilityHidden(true)
            }

            Text(isHold ? "Relax in \(secondsLeft)…" : "Squeeze in \(secondsLeft)…")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
                .opacity(countingDown ? 1 : 0)

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
        if let step { ringBaseAngle = ringAngle(for: step, at: .now) }
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
    var waves = 14
    var amplitude: CGFloat = 4

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - amplitude
        let segments = 360
        var path = Path()
        for i in 0...segments {
            let theta = Double(i) / Double(segments) * 2 * .pi
            let r = radius + amplitude * sin(Double(waves) * theta)
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
