import Foundation
import Observation
import UserNotifications

/// Daily local reminders for drinking water and doing the prescribed exercises.
@Observable
final class ReminderSettings {
    var waterEnabled: Bool { didSet { persistAndReschedule() } }
    /// Minutes after midnight.
    var waterStart: Int { didSet { persistAndReschedule() } }
    var waterEnd: Int { didSet { persistAndReschedule() } }
    var waterIntervalHours: Int { didSet { persistAndReschedule() } }

    var exerciseEnabled: Bool { didSet { persistAndReschedule() } }
    var exerciseTime: Int { didSet { persistAndReschedule() } }

    private(set) var authorizationDenied = false

    private let defaults: UserDefaults
    private let center = UNUserNotificationCenter.current()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            "reminders.water.start": 9 * 60,
            "reminders.water.end": 21 * 60,
            "reminders.water.interval": 2,
            "reminders.exercise.time": 9 * 60,
        ])
        waterEnabled = defaults.bool(forKey: "reminders.water.enabled")
        waterStart = defaults.integer(forKey: "reminders.water.start")
        waterEnd = defaults.integer(forKey: "reminders.water.end")
        waterIntervalHours = defaults.integer(forKey: "reminders.water.interval")
        exerciseEnabled = defaults.bool(forKey: "reminders.exercise.enabled")
        exerciseTime = defaults.integer(forKey: "reminders.exercise.time")
    }

    /// Times of day (minutes after midnight) a water reminder fires.
    var waterSlots: [Int] {
        guard waterIntervalHours > 0, waterEnd >= waterStart else { return [waterStart] }
        return Array(stride(from: waterStart, through: waterEnd, by: waterIntervalHours * 60))
    }

    func refreshAuthorization() async {
        let settings = await center.notificationSettings()
        authorizationDenied = settings.authorizationStatus == .denied
    }

    private func persistAndReschedule() {
        defaults.set(waterEnabled, forKey: "reminders.water.enabled")
        defaults.set(waterStart, forKey: "reminders.water.start")
        defaults.set(waterEnd, forKey: "reminders.water.end")
        defaults.set(waterIntervalHours, forKey: "reminders.water.interval")
        defaults.set(exerciseEnabled, forKey: "reminders.exercise.enabled")
        defaults.set(exerciseTime, forKey: "reminders.exercise.time")
        Task { await reschedule() }
    }

    func reschedule() async {
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix("reminder.") })

        guard waterEnabled || exerciseEnabled else { return }
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        authorizationDenied = !granted
        guard granted else { return }

        if waterEnabled {
            for minutes in waterSlots {
                await add(
                    id: "reminder.water.\(minutes)",
                    title: String(localized: "Time for some water"),
                    body: String(localized: "Have a glass of water and log it in your diary."),
                    minutes: minutes)
            }
        }
        if exerciseEnabled {
            await add(
                id: "reminder.exercise",
                title: String(localized: "Exercise time"),
                body: String(localized: "Take a few minutes for today's exercises."),
                minutes: exerciseTime)
        }
    }

    private func add(id: String, title: String, body: String, minutes: Int) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let components = DateComponents(hour: minutes / 60, minute: minutes % 60)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}

extension Date {
    /// Today's date at the given minutes after midnight, for binding to a `DatePicker`.
    init(minutesAfterMidnight minutes: Int) {
        self = Calendar.current.date(
            bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
    }

    var minutesAfterMidnight: Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: self)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}
