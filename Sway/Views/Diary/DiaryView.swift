import SwiftUI

struct DiaryView: View {
    @Environment(SessionStore.self) private var session
    @Environment(DiaryStore.self) private var diary
    @State private var newEntryKind: DiaryEntry.Kind?

    var body: some View {
        NavigationStack {
            List {
                if diary.pendingCount > 0 {
                    Section {
                        PendingSyncRow(count: diary.pendingCount, signedIn: session.isSignedIn)
                    }
                }
                ForEach(diary.entriesByDay, id: \.day) { group in
                    Section {
                        ForEach(group.entries) { entry in
                            NavigationLink(value: entry) {
                                DiaryEntryRow(entry: entry)
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { group.entries[$0] }.forEach(diary.delete)
                        }
                    } header: {
                        Text(group.day, format: .dateTime.weekday(.wide).day().month(.wide))
                    }
                }
            }
            .overlay {
                if diary.entries.isEmpty {
                    ContentUnavailableView {
                        Label("No entries yet", systemImage: "book.closed")
                    } description: {
                        Text("Log drinks, bathroom visits and sleep to build your diary.")
                    } actions: {
                        Button("Add entry") { newEntryKind = .drink }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .refreshable {
                await diary.syncPending(token: session.submissionToken)
            }
            .navigationTitle("Diary")
            .navigationDestination(for: DiaryEntry.self) { entry in
                DiaryEntryDetailView(entry: entry)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(DiaryEntry.Kind.allCases) { kind in
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
                    } label: {
                        Label("Add entry", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $newEntryKind) { kind in
                DiaryEntryForm(kind: kind)
            }
        }
    }
}

struct DiaryEntryRow: View {
    let entry: DiaryEntry

    var body: some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.kind.title)
                    if let summary = entry.summary {
                        Text(summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if !entry.notes.isEmpty {
                        Text(entry.notes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } icon: {
                Image(systemName: entry.kind.systemImage)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(entry.date, format: .dateTime.hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !entry.synced {
                    Image(systemName: "icloud.slash")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .accessibilityLabel(Text("Not synced"))
                }
            }
        }
    }
}

private struct PendingSyncRow: View {
    @Environment(SessionStore.self) private var session
    @Environment(DiaryStore.self) private var diary
    let count: Int
    let signedIn: Bool

    var body: some View {
        HStack {
            Label {
                VStack(alignment: .leading) {
                    Text("\(count) entries not synced")
                    Text(signedIn ? "They'll be sent when you're online." : "Sign in to share your diary with your therapist.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "icloud.slash").foregroundStyle(.orange)
            }
            Spacer()
            if signedIn {
                if diary.isSyncing {
                    ProgressView()
                } else {
                    Button("Retry") {
                        Task { await diary.syncPending(token: session.submissionToken) }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}

struct DiaryEntryDetailView: View {
    @Environment(DiaryStore.self) private var diary
    @Environment(\.dismiss) private var dismiss
    let entry: DiaryEntry

    var body: some View {
        Form {
            Section {
                LabeledContent("Type") { Text(entry.kind.title) }
                LabeledContent("Time") {
                    Text(entry.date, format: .dateTime.day().month().year().hour().minute())
                }
                LabeledContent("Synced") {
                    Image(systemName: entry.synced ? "checkmark.circle.fill" : "icloud.slash")
                        .foregroundStyle(entry.synced ? .green : .orange)
                }
            }
            details
            if !entry.notes.isEmpty {
                Section("Notes") { Text(entry.notes) }
            }
            Section {
                Button("Delete entry", role: .destructive) {
                    diary.delete(entry)
                    dismiss()
                }
            } footer: {
                if entry.synced {
                    Text("Deleting only removes the entry from this device.")
                }
            }
        }
        .navigationTitle(Text(entry.kind.title))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var details: some View {
        switch entry.details {
        case .wakeUp, .sleep:
            EmptyView()
        case let .drink(type, volume):
            Section {
                LabeledContent("Drink") { Text(type.title) }
                LabeledContent("Volume", value: "\(volume) ml")
            }
        case let .urination(volume, urgency, leaked):
            Section {
                LabeledContent("Volume", value: volume > 0 ? "\(volume) ml" : "–")
                LabeledContent("Urgency") { Text(urgency.title) }
                LabeledContent("Leaked") { Text(leaked ? "Yes" : "No") }
            }
        case let .bowel(movement):
            Section {
                LabeledContent("Stool type") {
                    Text("Type \(movement.stoolType)")
                }
                LabeledContent("Urgency") { Text(movement.urgency.title) }
                LabeledContent("Effort") { Text(movement.effort.title) }
                LabeledContent("Time taken", value: movement.minutesTaken > 0 ? "\(movement.minutesTaken) min" : "–")
                LabeledContent("Felt empty") { Text(movement.feltEmpty ? "Yes" : "No") }
                LabeledContent("Accident") { Text(movement.accident ? "Yes" : "No") }
                if movement.accident, !movement.accidentAmount.isEmpty {
                    LabeledContent("Amount", value: movement.accidentAmount)
                }
            }
        }
    }
}
