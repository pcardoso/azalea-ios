import Foundation
import Observation

/// Local log of exercise sessions, persisted as JSON and synced like the diary.
@Observable
final class ExerciseRunStore {
    private(set) var runs: [ExerciseRun] = []
    private var isSyncing = false

    private let fileURL: URL
    private let api: APIClient

    init(fileURL: URL = URL.applicationSupportDirectory.appending(path: "exercise-runs.json"), api: APIClient = .shared) {
        self.fileURL = fileURL
        self.api = api
        if let data = try? Data(contentsOf: fileURL) {
            runs = (try? JSONDecoder().decode([ExerciseRun].self, from: data)) ?? []
        }
    }

    func add(_ run: ExerciseRun, token: String?) async {
        runs.append(run)
        save()
        guard let token else { return }
        await sync(run.id, token: token)
    }

    func syncPending(token: String?) async {
        guard let token, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        for run in runs where !run.synced {
            await sync(run.id, token: token)
        }
    }

    private func sync(_ id: ExerciseRun.ID, token: String) async {
        guard let run = runs.first(where: { $0.id == id }) else { return }
        do {
            try await api.submit(run, token: token)
            if let index = runs.firstIndex(where: { $0.id == id }) {
                runs[index].synced = true
                save()
            }
        } catch {
            // Left unsynced; retried on next launch or sign-in.
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(runs).write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            assertionFailure("Failed to save exercise runs: \(error)")
        }
    }
}
