import Foundation

/// Talks to the public Sway API (`/pub/...`). No user auth: prescriptions are fetched by code,
/// and diary entries are posted with the client submission token returned with the prescription.
struct APIClient: Sendable {
    static let shared = APIClient()

    enum APIError: LocalizedError {
        case http(Int)
        case missingToken

        var errorDescription: String? {
            switch self {
            case .http(404): String(localized: "We couldn't find a prescription with that code.")
            case let .http(status): String(localized: "The server returned an error (\(status)).")
            case .missingToken: String(localized: "Sign in again to sync your diary.")
            }
        }
    }

    let baseURL: URL

    init(baseURL: URL = APIClient.configuredBaseURL) {
        self.baseURL = baseURL
    }

    /// Set per build configuration through the `API_BASE_URL` build setting (see Config/Info.plist).
    static var configuredBaseURL: URL {
        let value = Bundle.main.object(forInfoDictionaryKey: "SwayAPIBaseURL") as? String
        return value.flatMap(URL.init(string:)) ?? URL(string: "https://api.gowithsway.com")!
    }

    func prescription(code: String) async throws -> Prescription {
        let url = baseURL.appending(path: "pub/prescriptions").appending(path: code)
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response)
        return try JSONDecoder().decode(Prescription.self, from: data)
    }

    func fileURL(for document: Prescription.Document) -> URL {
        baseURL.appending(path: "pub/prescriptions/files").appending(path: document.fileId)
    }

    func submit(_ entry: DiaryEntry, token: String) async throws {
        var request = URLRequest(url: baseURL.appending(path: "pub/bladder-bowel-diary"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: Self.payload(for: entry))
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response)
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else { throw APIError.http(http.statusCode) }
    }

    /// Same wire format the Expo app sent, so the backend and web dashboard keep working.
    static func payload(for entry: DiaryEntry) -> [String: Any] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let entryType: String
        var data: [String: Any] = ["notes": entry.notes]
        switch entry.details {
        case .wakeUp:
            entryType = "wake"
        case let .sleep(quality):
            entryType = "sleep"
            if let quality { data["quality"] = quality }
        case let .drink(type, volume):
            entryType = "drink"
            data["drinkType"] = type.rawValue
            data["volume"] = volume
        case let .urination(volume, urgency, leaked):
            entryType = "urinate"
            data["volume"] = volume
            data["urgency"] = urgency.rawValue
            data["leaked"] = leaked
        case let .bowel(movement):
            entryType = "defecate"
            data["urgency"] = movement.urgency.rawValue
            data["accident"] = movement.accident
            data["accidentAmount"] = movement.accidentAmount
            data["timeTaken"] = movement.minutesTaken
            data["stoolType"] = movement.stoolType
            data["effortRequired"] = movement.effort.rawValue
            data["feltEmpty"] = movement.feltEmpty
        }
        return [
            "entryType": entryType,
            "entryDatetime": formatter.string(from: entry.date),
            "data": data,
        ]
    }
}
