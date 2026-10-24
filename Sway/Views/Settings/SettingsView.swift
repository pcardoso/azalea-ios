import SwiftUI

struct SettingsView: View {
    @Environment(SessionStore.self) private var session
    @Environment(ReminderSettings.self) private var reminders
    @Environment(\.openURL) private var openURL
    @State private var showingSignIn = false
    @State private var showingAccount = false

    var body: some View {
        @Bindable var reminders = reminders

        NavigationStack {
            Form {
                Section("Account") {
                    if session.isSignedIn {
                        Button {
                            showingAccount = true
                        } label: {
                            LabeledContent {
                                Text(session.code ?? "").monospaced()
                            } label: {
                                Label(session.name ?? "", systemImage: "person.crop.circle.fill")
                            }
                        }
                        .tint(.primary)
                    } else {
                        Button {
                            showingSignIn = true
                        } label: {
                            Label("Enter prescription code", systemImage: "person.badge.key")
                        }
                    }
                }

                Section {
                    Toggle(isOn: $reminders.waterEnabled.animation()) {
                        Label("Drink water", systemImage: "drop.fill")
                    }
                    if reminders.waterEnabled {
                        DatePicker("From", selection: minutes($reminders.waterStart), displayedComponents: .hourAndMinute)
                        DatePicker("Until", selection: minutes($reminders.waterEnd), displayedComponents: .hourAndMinute)
                        Picker("Every", selection: $reminders.waterIntervalHours) {
                            ForEach(1...6, id: \.self) { hours in
                                Text("\(hours) h").tag(hours)
                            }
                        }
                    }
                    Toggle(isOn: $reminders.exerciseEnabled.animation()) {
                        Label("Exercises", systemImage: "figure.mind.and.body")
                    }
                    if reminders.exerciseEnabled {
                        DatePicker("Time", selection: minutes($reminders.exerciseTime), displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    if reminders.authorizationDenied {
                        Button("Notifications are turned off for Sway. Open Settings to allow them.") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                openURL(url)
                            }
                        }
                        .font(.footnote)
                    }
                }

                Section {
                    NavigationLink("Credits") { CreditsView() }
                    LabeledContent("Version", value: Bundle.main.appVersion)
                }
            }
            .navigationTitle("Settings")
            .task { await reminders.refreshAuthorization() }
            .sheet(isPresented: $showingSignIn) { SignInView() }
            .sheet(isPresented: $showingAccount) { AccountView() }
        }
    }

    private func minutes(_ binding: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { Date(minutesAfterMidnight: binding.wrappedValue) },
            set: { binding.wrappedValue = $0.minutesAfterMidnight }
        )
    }
}

struct CreditsView: View {
    var body: some View {
        List {
            Section {
                Text("Thanks to everyone who contributed to this project.")
            } footer: {
                Text("© \(Calendar.current.component(.year, from: .now).formatted(.number.grouping(.never))) Sway. All rights reserved.")
            }
        }
        .navigationTitle("Credits")
    }
}

extension Bundle {
    var appVersion: String {
        let version = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }
}
