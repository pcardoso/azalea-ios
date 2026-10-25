import SwiftUI

struct SignInView: View {
    @Environment(SessionStore.self) private var session
    @Environment(DiaryStore.self) private var diary
    @Environment(ExerciseRunStore.self) private var exerciseRuns
    @Environment(\.dismiss) private var dismiss
    @State private var code: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focused: Bool
    private let linkedCode: String?

    /// `linkedCode` comes from a prescription link: it's filled in and submitted right away.
    init(linkedCode: String? = nil) {
        self.linkedCode = linkedCode
        _code = State(initialValue: linkedCode ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Prescription code", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .textContentType(.oneTimeCode)
                        .font(.title3.monospaced())
                        .focused($focused)
                        .submitLabel(.go)
                        .onSubmit(signIn)
                } footer: {
                    Text("You'll find the code on the prescription your therapist sent you.")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Sign in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button("Sign in", action: signIn)
                            .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .onAppear {
                focused = true
                if linkedCode != nil { signIn() }
            }
            .interactiveDismissDisabled(isLoading)
        }
    }

    private func signIn() {
        guard !code.isEmpty, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        Task {
            defer { isLoading = false }
            do {
                try await session.signIn(code: code)
                await diary.syncPending(token: session.submissionToken)
                await exerciseRuns.syncPending(token: session.submissionToken)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct AccountView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingSignOut = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Name", value: session.name ?? "")
                    LabeledContent("Prescription code") {
                        Text(session.code ?? "").monospaced()
                    }
                }
                Section {
                    Button("Sign out", role: .destructive) {
                        confirmingSignOut = true
                    }
                } footer: {
                    Text("Your diary stays on this device when you sign out.")
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Sign out?", isPresented: $confirmingSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) {
                    session.signOut()
                    dismiss()
                }
            }
        }
    }
}
