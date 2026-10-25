import SwiftUI

struct RootView: View {
    private enum RootTab: Hashable { case today, diary, exercises, settings }

    /// A prescription code from a link, waiting for the user to be signed in with it.
    private struct LinkedCode: Identifiable {
        let code: String
        var id: String { code }
    }

    @Environment(SessionStore.self) private var session
    @Environment(DiaryStore.self) private var diary
    @Environment(ExerciseRunStore.self) private var exerciseRuns
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection = RootTab.today
    @State private var linkedCode: LinkedCode?

    var body: some View {
        TabView(selection: $selection) {
            Tab("Today", systemImage: "sun.max", value: .today) {
                HomeView()
            }
            Tab("Diary", systemImage: "book.closed", value: .diary) {
                DiaryView()
            }
            Tab("Exercises", systemImage: "figure.mind.and.body", value: .exercises) {
                PrescriptionView()
            }
            Tab("Settings", systemImage: "gearshape", value: .settings) {
                SettingsView()
            }
        }
        // Opened from a prescription link: show that prescription, signing in with its code first if needed.
        .onOpenURL { url in
            guard let code = DeepLinks.prescriptionCode(from: url) else { return }
            selection = .exercises
            if code == session.code {
                Task { try? await session.refreshPrescription() }
            } else {
                linkedCode = LinkedCode(code: code)
            }
        }
        .sheet(item: $linkedCode) { linked in
            SignInView(linkedCode: linked.code)
        }
        .task {
            try? await session.refreshPrescription()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            Task {
                await diary.syncPending(token: session.submissionToken)
                await exerciseRuns.syncPending(token: session.submissionToken)
            }
        }
    }
}
