import Foundation
import Observation

/// The signed-in client. A "session" is just a prescription code that resolved successfully,
/// plus the submission token the backend hands back for posting diary entries.
@Observable
final class SessionStore {
    private(set) var code: String?
    private(set) var name: String?
    private(set) var submissionToken: String?
    private(set) var prescription: Prescription?

    var isSignedIn: Bool { code != nil }

    private let defaults: UserDefaults
    private let api: APIClient

    private enum Keys {
        static let code = "session.code"
        static let name = "session.name"
        static let token = "session.submissionToken"
    }

    init(defaults: UserDefaults = .standard, api: APIClient = .shared) {
        self.defaults = defaults
        self.api = api
        code = defaults.string(forKey: Keys.code)
        name = defaults.string(forKey: Keys.name)
        submissionToken = defaults.string(forKey: Keys.token)
    }

    /// Validates the code against the API and stores the session on success.
    func signIn(code rawCode: String) async throws {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let prescription = try await api.prescription(code: code)
        self.code = code
        name = prescription.client.displayName
        submissionToken = prescription.clientSubmissionToken
        self.prescription = prescription
        defaults.set(code, forKey: Keys.code)
        defaults.set(name, forKey: Keys.name)
        defaults.set(submissionToken, forKey: Keys.token)
    }

    /// Reloads the prescription for the current session (pull to refresh, app launch).
    func refreshPrescription() async throws {
        guard let code else { return }
        let prescription = try await api.prescription(code: code)
        self.prescription = prescription
        name = prescription.client.displayName
        if let token = prescription.clientSubmissionToken {
            submissionToken = token
            defaults.set(token, forKey: Keys.token)
        }
        defaults.set(name, forKey: Keys.name)
    }

    func signOut() {
        code = nil
        name = nil
        submissionToken = nil
        prescription = nil
        for key in [Keys.code, Keys.name, Keys.token] {
            defaults.removeObject(forKey: key)
        }
    }
}
