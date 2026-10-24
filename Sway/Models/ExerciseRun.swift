import Foundation

/// One guided exercise session, recorded when it finishes or is terminated early.
struct ExerciseRun: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var prescriptionId: Int?
    var startedAt: Date
    var endedAt: Date
    /// Hold/rest steps fully completed.
    var completedSteps: Int
    var totalSteps: Int
    var terminatedEarly: Bool
    var synced = false
}
