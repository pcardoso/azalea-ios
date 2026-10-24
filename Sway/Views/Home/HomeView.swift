import SwiftUI

struct HomeView: View {
    @Environment(SessionStore.self) private var session
    @Environment(DiaryStore.self) private var diary
    @State private var newEntryKind: DiaryEntry.Kind?
    @State private var showingSignIn = false

    private var today: [DiaryEntry] { diary.entries(on: .now) }

    var body: some View {
        NavigationStack {
            List {
                if !session.isSignedIn {
                    Section {
                        SignInPrompt { showingSignIn = true }
                    }
                }

                Section("Today") {
                    LabeledContent {
                        Text(drinkTotal, format: .measurement(width: .abbreviated, usage: .asProvided))
                    } label: {
                        Label("Fluids", systemImage: "drop.fill")
                    }
                    LabeledContent {
                        Text(count(.urination), format: .number)
                    } label: {
                        Label("Urinations", systemImage: "drop")
                    }
                    LabeledContent {
                        Text(leaks, format: .number)
                    } label: {
                        Label("Leaks", systemImage: "exclamationmark.triangle")
                    }
                    LabeledContent {
                        Text(count(.bowel), format: .number)
                    } label: {
                        Label("Bowel movements", systemImage: "toilet")
                    }
                }

                Section("Quick add") {
                    ForEach([DiaryEntry.Kind.drink, .urination, .bowel]) { kind in
                        Button {
                            newEntryKind = kind
                        } label: {
                            Label {
                                Text(kind.title)
                            } icon: {
                                Image(systemName: kind.systemImage)
                            }
                        }
                    }
                }

                if let prescription = session.prescription, !prescription.exercises.isEmpty {
                    Section("Exercises") {
                        NavigationLink {
                            PrescriptionDetailView(prescription: prescription)
                        } label: {
                            Label {
                                VStack(alignment: .leading) {
                                    Text("Today's exercises")
                                    Text("\(prescription.exercises.count) exercises")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "figure.mind.and.body")
                            }
                        }
                    }
                }
            }
            .navigationTitle(greeting)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AccountButton()
                }
            }
            .sheet(item: $newEntryKind) { kind in
                DiaryEntryForm(kind: kind)
            }
            .sheet(isPresented: $showingSignIn) {
                SignInView()
            }
        }
    }

    private var greeting: String {
        if let name = session.name {
            return String(localized: "Hello, \(name)")
        }
        return String(localized: "Welcome to Sway")
    }

    private var drinkTotal: Measurement<UnitVolume> {
        let ml = today.reduce(0) { total, entry in
            if case let .drink(_, volume) = entry.details { return total + volume }
            return total
        }
        return Measurement(value: Double(ml), unit: .milliliters)
    }

    private var leaks: Int {
        today.filter { entry in
            if case let .urination(_, _, leaked) = entry.details { return leaked }
            if case let .bowel(movement) = entry.details { return movement.accident }
            return false
        }.count
    }

    private func count(_ kind: DiaryEntry.Kind) -> Int {
        today.filter { $0.kind == kind }.count
    }
}

private struct SignInPrompt: View {
    var action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Connect to your therapist", systemImage: "person.badge.key")
                .font(.headline)
            Text("Enter the code from your prescription to see your exercises and share your diary.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Enter code", action: action)
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }
}

/// Toolbar button that opens the account sheet, or sign-in when signed out.
struct AccountButton: View {
    @Environment(SessionStore.self) private var session
    @State private var presented = false

    var body: some View {
        Button {
            presented = true
        } label: {
            Image(systemName: session.isSignedIn ? "person.crop.circle.fill" : "person.crop.circle")
        }
        .accessibilityLabel(Text("Account"))
        .sheet(isPresented: $presented) {
            if session.isSignedIn {
                AccountView()
            } else {
                SignInView()
            }
        }
    }
}
