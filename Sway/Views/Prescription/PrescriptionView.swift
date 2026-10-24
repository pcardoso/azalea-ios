import SafariServices
import SwiftUI

struct PrescriptionView: View {
    @Environment(SessionStore.self) private var session
    @State private var showingSignIn = false
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            Group {
                if let prescription = session.prescription {
                    PrescriptionDetailView(prescription: prescription)
                } else if session.isSignedIn {
                    if let loadError {
                        ContentUnavailableView {
                            Label("Couldn't load your exercises", systemImage: "wifi.exclamationmark")
                        } description: {
                            Text(loadError)
                        } actions: {
                            Button("Try again") { Task { await load() } }
                        }
                    } else {
                        ProgressView()
                    }
                } else {
                    ContentUnavailableView {
                        Label("No prescription", systemImage: "figure.mind.and.body")
                    } description: {
                        Text("Enter the code from your therapist to see your exercises.")
                    } actions: {
                        Button("Enter code") { showingSignIn = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .navigationTitle("Exercises")
                }
            }
            .task(id: session.code) {
                if session.prescription == nil { await load() }
            }
            .sheet(isPresented: $showingSignIn) {
                SignInView()
            }
        }
    }

    private func load() async {
        loadError = nil
        do {
            try await session.refreshPrescription()
        } catch {
            loadError = error.localizedDescription
        }
    }
}

struct PrescriptionDetailView: View {
    @Environment(SessionStore.self) private var session
    let prescription: Prescription
    @State private var runningSession = false
    @State private var openDocument: Prescription.Document?

    private var exercises: [Prescription.Exercise] { prescription.exercises.sorted { $0.index < $1.index } }
    private var lifestyle: [Prescription.LifestyleTip] { prescription.lifestyle.sorted { $0.index < $1.index } }
    private var documents: [Prescription.Document] { prescription.documents.sorted { $0.index < $1.index } }

    var body: some View {
        List {
            if let notes = prescription.prescription.notes, !notes.isEmpty {
                Section("From your therapist") {
                    Text(notes)
                }
            }

            if !exercises.isEmpty {
                Section {
                    ForEach(Array(exercises.enumerated()), id: \.element.id) { offset, exercise in
                        ExerciseRow(number: offset + 1, exercise: exercise)
                    }
                    Button {
                        runningSession = true
                    } label: {
                        Label("Start session", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .padding(.top, 8)
                } header: {
                    Text("Exercises")
                } footer: {
                    Text("About \(sessionMinutes) min")
                }
            }

            if !lifestyle.isEmpty {
                Section("Lifestyle") {
                    ForEach(lifestyle) { tip in
                        Label(tip.instructions, systemImage: "leaf")
                    }
                }
            }

            if !documents.isEmpty {
                Section("Documents") {
                    ForEach(documents) { document in
                        Button {
                            openDocument = document
                        } label: {
                            Label(document.title, systemImage: "doc.text")
                        }
                    }
                }
            }
        }
        .navigationTitle("Exercises")
        .refreshable {
            try? await session.refreshPrescription()
        }
        .fullScreenCover(isPresented: $runningSession) {
            ExerciseSessionView(steps: prescription.exerciseSequence)
        }
        .sheet(item: $openDocument) { document in
            SafariView(url: APIClient.shared.fileURL(for: document))
                .ignoresSafeArea()
        }
    }

    private var sessionMinutes: Int {
        let seconds = prescription.exerciseSequence.reduce(0) { $0 + $1.duration }
        return max(1, Int((Double(seconds) / 60).rounded()))
    }
}

private struct ExerciseRow: View {
    let number: Int
    let exercise: Prescription.Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exercise.instructions.isEmpty ? String(localized: "Exercise \(number)") : exercise.instructions)
            Text("\(exercise.repetitions) reps × \(exercise.sets) sets · hold \(exercise.hold)s, rest \(exercise.rest)s")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
