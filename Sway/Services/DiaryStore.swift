import Foundation
import Observation

/// Local diary, persisted as JSON in Application Support. Entries are saved first and synced
/// afterwards, so nothing is lost when offline or signed out.
@Observable
final class DiaryStore {
    private(set) var entries: [DiaryEntry] = []
    private(set) var isSyncing = false

    var pendingCount: Int { entries.filter { !$0.synced }.count }

    private let fileURL: URL
    private let api: APIClient

    init(fileURL: URL = DiaryStore.defaultFileURL, api: APIClient = .shared) {
        self.fileURL = fileURL
        self.api = api
        load()
    }

    static var defaultFileURL: URL {
        URL.applicationSupportDirectory.appending(path: "diary.json")
    }

    /// Entries grouped by calendar day, newest day and newest entry first.
    var entriesByDay: [(day: Date, entries: [DiaryEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
        return grouped
            .map { (day: $0.key, entries: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    func entries(on day: Date) -> [DiaryEntry] {
        entries.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    /// Saves the entry locally, then tries to send it. Returns false if it could not be synced yet.
    @discardableResult
    func add(_ entry: DiaryEntry, token: String?) async -> Bool {
        entries.append(entry)
        save()
        guard let token else { return false }
        return await sync(entry.id, token: token)
    }

    func delete(_ entry: DiaryEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    /// Retries every entry that hasn't reached the server yet.
    func syncPending(token: String?) async {
        guard let token, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        for entry in entries where !entry.synced {
            await sync(entry.id, token: token)
        }
    }

    @discardableResult
    private func sync(_ id: DiaryEntry.ID, token: String) async -> Bool {
        guard let entry = entries.first(where: { $0.id == id }) else { return false }
        do {
            try await api.submit(entry, token: token)
            if let index = entries.firstIndex(where: { $0.id == id }) {
                entries[index].synced = true
                save()
            }
            return true
        } catch {
            return false
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        entries = (try? JSONDecoder().decode([DiaryEntry].self, from: data)) ?? []
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(entries).write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            assertionFailure("Failed to save diary: \(error)")
        }
    }
}
