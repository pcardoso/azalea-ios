import SwiftUI
import UserNotifications

@main
struct SwayApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var session = SessionStore()
    @State private var diary = DiaryStore()
    @State private var exerciseRuns = ExerciseRunStore()
    @State private var reminders = ReminderSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(diary)
                .environment(exerciseRuns)
                .environment(reminders)
        }
    }
}

/// Shows reminder notifications as banners while the app is in the foreground.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}
