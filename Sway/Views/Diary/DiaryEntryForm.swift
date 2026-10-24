import SwiftUI

/// Sheet for logging a new diary entry of any kind.
struct DiaryEntryForm: View {
    @Environment(SessionStore.self) private var session
    @Environment(DiaryStore.self) private var diary
    @Environment(\.dismiss) private var dismiss

    @State var kind: DiaryEntry.Kind
    @State private var date = Date.now
    @State private var notes = ""
    @State private var drinkType: DiaryEntry.DrinkType = .water
    @State private var volume: Int?
    @State private var urgency: DiaryEntry.Urgency = .none
    @State private var leaked = false
    @State private var bowel = DiaryEntry.BowelMovement()
    @State private var showingBristolInfo = false
    @State private var saving = false

    private static let quickVolumes = [150, 250, 330, 500]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(DiaryEntry.Kind.allCases) { kind in
                            Label {
                                Text(kind.title)
                            } icon: {
                                Image(systemName: kind.systemImage)
                            }
                            .tag(kind)
                        }
                    }
                    DatePicker("Time", selection: $date, in: ...Date.now)
                }

                switch kind {
                case .wakeUp, .sleep:
                    EmptyView()
                case .drink:
                    drinkSection
                case .urination:
                    urinationSection
                case .bowel:
                    bowelSections
                }

                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(Text(kind.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(saving || (kind == .drink && (volume ?? 0) <= 0))
                }
            }
            .sheet(isPresented: $showingBristolInfo) {
                BristolScaleView()
                    .presentationDetents([.medium, .large])
            }
            .interactiveDismissDisabled(saving)
        }
    }

    private var drinkSection: some View {
        Section("Drink") {
            Picker("Drink", selection: $drinkType) {
                ForEach(DiaryEntry.DrinkType.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            volumeField
            HStack {
                ForEach(Self.quickVolumes, id: \.self) { ml in
                    Button("\(ml)") { volume = ml }
                        .buttonStyle(.bordered)
                        .tint(volume == ml ? .accentColor : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var urinationSection: some View {
        Section {
            volumeField
            Picker("Urgency", selection: $urgency) {
                ForEach(DiaryEntry.Urgency.allCases) { Text($0.title).tag($0) }
            }
            Toggle("Leaked", isOn: $leaked)
        } footer: {
            Text("Leave the volume empty if you didn't measure it.")
        }
    }

    @ViewBuilder private var bowelSections: some View {
        Section {
            Picker(selection: $bowel.stoolType) {
                ForEach(1...7, id: \.self) { type in
                    VStack(alignment: .leading) {
                        Text("Type \(type)")
                        Text(DiaryEntry.bristolDescription(type))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(type)
                }
            } label: {
                Text("Stool type")
            }
            .pickerStyle(.navigationLink)
        } header: {
            HStack {
                Text("Bristol scale")
                Spacer()
                Button {
                    showingBristolInfo = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel(Text("About the Bristol scale"))
            }
        }

        Section {
            Picker("Urgency", selection: $bowel.urgency) {
                ForEach(DiaryEntry.Urgency.allCases) { Text($0.bowelDescription).tag($0) }
            }
            .pickerStyle(.navigationLink)
            Picker("Effort", selection: $bowel.effort) {
                ForEach(DiaryEntry.Effort.allCases) { Text($0.title).tag($0) }
            }
            Stepper(value: $bowel.minutesTaken, in: 0...120) {
                LabeledContent("Time taken", value: bowel.minutesTaken > 0 ? "\(bowel.minutesTaken) min" : "–")
            }
            Toggle("Felt empty afterwards", isOn: $bowel.feltEmpty)
        }

        Section {
            Toggle("Accident", isOn: $bowel.accident.animation())
            if bowel.accident {
                TextField("Amount (e.g. small, large)", text: $bowel.accidentAmount)
            }
        }
    }

    private var volumeField: some View {
        LabeledContent("Volume") {
            HStack(spacing: 4) {
                TextField("0", value: $volume, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                Text("ml").foregroundStyle(.secondary)
            }
        }
    }

    private func save() {
        let details: DiaryEntry.Details = switch kind {
        case .wakeUp: .wakeUp
        case .sleep: .sleep(quality: nil)
        case .drink: .drink(drinkType, volumeML: volume ?? 0)
        case .urination: .urination(volumeML: volume ?? 0, urgency: urgency, leaked: leaked)
        case .bowel: .bowel(bowel)
        }
        let entry = DiaryEntry(date: date, notes: notes.trimmingCharacters(in: .whitespacesAndNewlines), details: details)
        saving = true
        Task {
            // Saved locally right away; a failed upload is retried later from the diary list.
            await diary.add(entry, token: session.submissionToken)
            dismiss()
        }
    }
}

struct BristolScaleView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(1...7, id: \.self) { type in
                LabeledContent {
                    Text(DiaryEntry.bristolDescription(type))
                } label: {
                    Text("Type \(type)").bold()
                }
            }
            .navigationTitle("Bristol stool scale")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Text("Types 3 and 4 are considered normal. Types 1–2 suggest constipation and 6–7 diarrhoea.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
