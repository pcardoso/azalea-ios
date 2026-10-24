import SwiftUI

struct RootView: View {
    @Environment(SessionStore.self) private var session
    @Environment(DiaryStore.self) private var diary
    @Environment(ExerciseRunStore.self) private var exerciseRuns
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            Tab("Today", systemImage: "sun.max") {
                HomeView()
            }
            Tab("Diary", systemImage: "book.closed") {
                DiaryView()
            }
            Tab("Exercises", systemImage: "figure.mind.and.body") {
                PrescriptionView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
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
