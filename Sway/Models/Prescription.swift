import Foundation

/// Public prescription payload returned by `GET /pub/prescriptions/:code`.
struct Prescription: Decodable, Hashable, Sendable {
    struct Client: Decodable, Hashable, Sendable {
        var name: String
        var preferredName: String?

        var displayName: String {
            if let preferredName, !preferredName.isEmpty { return preferredName }
            return name
        }
    }

    struct Details: Decodable, Hashable, Sendable {
        var code: String
        var notes: String?
    }

    struct Exercise: Decodable, Hashable, Identifiable, Sendable {
        var id: Int
        var instructions: String
        var repetitions: Int
        var sets: Int
        /// Seconds to hold each contraction.
        var hold: Int
        /// Seconds to rest between contractions.
        var rest: Int
        var index: Int
    }

    struct LifestyleTip: Decodable, Hashable, Identifiable, Sendable {
        var id: Int
        var instructions: String
        var index: Int
    }

    struct Document: Decodable, Hashable, Identifiable, Sendable {
        var id: Int
        var title: String
        var fileId: String
        var index: Int
    }

    var client: Client
    var prescription: Details
    var exercises: [Exercise]
    var lifestyle: [LifestyleTip]
    var documents: [Document]
    var clientSubmissionToken: String?
}

/// One hold or rest interval in a guided exercise session.
struct ExerciseStep: Hashable, Sendable {
    enum Action: Sendable { case hold, rest }

    var action: Action
    var duration: Int
    var exerciseIndex: Int
    var exerciseCount: Int
    var repetition: Int
    var repetitionCount: Int
    var set: Int
    var setCount: Int
}

extension Prescription {
    /// Flattens every exercise into a hold/rest sequence: each set runs all its repetitions.
    var exerciseSequence: [ExerciseStep] {
        let exercises = exercises.sorted { $0.index < $1.index }
        var steps: [ExerciseStep] = []
        for (exerciseIndex, exercise) in exercises.enumerated() {
            for set in 0..<max(exercise.sets, 0) {
                for rep in 0..<max(exercise.repetitions, 0) {
                    for (action, duration) in [(ExerciseStep.Action.hold, exercise.hold), (.rest, exercise.rest)] {
                        steps.append(ExerciseStep(
                            action: action,
                            duration: duration,
                            exerciseIndex: exerciseIndex,
                            exerciseCount: exercises.count,
                            repetition: rep,
                            repetitionCount: exercise.repetitions,
                            set: set,
                            setCount: exercise.sets
                        ))
                    }
                }
            }
        }
        return steps
    }
}
