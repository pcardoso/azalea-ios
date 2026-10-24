import SwiftUI

/// Guided hold/rest session: a circle grows while holding and shrinks while resting.
struct ExerciseSessionView: View {
    @Environment(\.dismiss) private var dismiss
    let steps: [ExerciseStep]

    @State private var index = 0
    @State private var elapsedBeforePause: TimeInterval = 0
    @State private var stepStartedAt = Date.now
    @State private var paused = false
    @State private var finished = false
    @State private var confirmingExit = false
    @State private var tones = TonePlayer()

    private var step: ExerciseStep? { steps.indices.contains(index) ? steps[index] : nil }

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
                Button("End session", role: .destructive) { dismiss() }
            }
        }
        .onAppear {
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
        let elapsed = paused ? elapsedBeforePause : elapsedBeforePause + now.timeIntervalSince(stepStartedAt)
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
        elapsedBeforePause = 0
        stepStartedAt = .now
        if newIndex >= steps.count {
            finished = true
            tones.play(.newRepetition)
        } else {
            index = max(0, newIndex)
            // A hold starts a new repetition; switching to rest gets the short beep.
            tones.play(steps[index].action == .hold ? .newRepetition : .transition)
        }
    }
}

#Preview {
    ExerciseSessionView(steps: [
        ExerciseStep(action: .hold, duration: 3, exerciseIndex: 0, exerciseCount: 1, repetition: 0, repetitionCount: 2, set: 0, setCount: 1),
        ExerciseStep(action: .rest, duration: 3, exerciseIndex: 0, exerciseCount: 1, repetition: 0, repetitionCount: 2, set: 0, setCount: 1),
    ])
}
