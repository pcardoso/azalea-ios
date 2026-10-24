import Foundation

/// A single bladder or bowel diary record, stored locally and synced to the backend.
struct DiaryEntry: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var date: Date
    var notes: String = ""
    var synced = false
    var details: Details

    enum Details: Codable, Hashable, Sendable {
        case wakeUp
        case sleep(quality: Int?)
        case drink(DrinkType, volumeML: Int)
        case urination(volumeML: Int, urgency: Urgency, leaked: Bool)
        case bowel(BowelMovement)
    }

    var kind: Kind {
        switch details {
        case .wakeUp: .wakeUp
        case .sleep: .sleep
        case .drink: .drink
        case .urination: .urination
        case .bowel: .bowel
        }
    }
}

extension DiaryEntry {
    enum Kind: String, CaseIterable, Identifiable, Sendable {
        case wakeUp, sleep, drink, urination, bowel

        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .wakeUp: "Wake up"
            case .sleep: "Sleep"
            case .drink: "Drink"
            case .urination: "Urination"
            case .bowel: "Bowel movement"
            }
        }

        var systemImage: String {
            switch self {
            case .wakeUp: "sunrise"
            case .sleep: "moon.zzz"
            case .drink: "cup.and.saucer"
            case .urination: "drop"
            case .bowel: "toilet"
            }
        }
    }

    enum DrinkType: String, Codable, CaseIterable, Identifiable, Sendable {
        case water, coffee, tea, other

        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .water: "Water"
            case .coffee: "Coffee"
            case .tea: "Tea"
            case .other: "Other"
            }
        }
    }

    /// Urge scale shared by bladder and bowel entries (0 = none, 4 = extreme).
    enum Urgency: Int, Codable, CaseIterable, Identifiable, Sendable {
        case none, mild, moderate, strong, extreme

        var id: Int { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .none: "None"
            case .mild: "Mild"
            case .moderate: "Moderate"
            case .strong: "Strong"
            case .extreme: "Extreme"
            }
        }

        /// Longer description used by the bowel diary form.
        var bowelDescription: LocalizedStringResource {
            switch self {
            case .none: "No urge"
            case .mild: "Mild, could delay 30 min"
            case .moderate: "Moderate, could delay 15 min"
            case .strong: "Strong, couldn't delay over 5 min"
            case .extreme: "Raced to the toilet"
            }
        }
    }

    enum Effort: Int, Codable, CaseIterable, Identifiable, Sendable {
        case none, minimal, moderate, considerable, maximum

        var id: Int { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .none: "None"
            case .minimal: "Minimal"
            case .moderate: "Moderate"
            case .considerable: "Considerable"
            case .maximum: "Maximum"
            }
        }
    }

    struct BowelMovement: Codable, Hashable, Sendable {
        var urgency: Urgency = .none
        var accident = false
        var accidentAmount = ""
        /// Minutes spent, 0 when not recorded.
        var minutesTaken = 0
        /// Bristol stool scale, 1...7.
        var stoolType = 4
        var effort: Effort = .none
        var feltEmpty = true
    }

    static func bristolDescription(_ type: Int) -> LocalizedStringResource {
        switch type {
        case 1: "Separate hard lumps"
        case 2: "Lumpy, sausage-shaped"
        case 3: "Sausage with cracks"
        case 4: "Smooth, soft sausage"
        case 5: "Soft blobs, clear edges"
        case 6: "Fluffy, ragged pieces"
        default: "Watery, no solid pieces"
        }
    }

    /// One-line summary shown under the entry title in lists.
    var summary: String? {
        switch details {
        case .wakeUp, .sleep:
            return nil
        case let .drink(type, volume):
            return "\(String(localized: type.title)) · \(volume) ml"
        case let .urination(volume, urgency, leaked):
            var parts = [String(localized: urgency.title)]
            if volume > 0 { parts.insert("\(volume) ml", at: 0) }
            if leaked { parts.append(String(localized: "Leaked")) }
            return parts.joined(separator: " · ")
        case let .bowel(movement):
            var parts = [String(localized: "Type \(movement.stoolType)")]
            if movement.accident { parts.append(String(localized: "Accident")) }
            return parts.joined(separator: " · ")
        }
    }
}
