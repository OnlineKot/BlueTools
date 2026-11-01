import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var bluetooth: BluetoothManager
    @EnvironmentObject private var pins: PinStore
    @EnvironmentObject private var updates: UpdateChecker
    @EnvironmentObject private var customCommands: CustomCommandStore

    @AppStorage(PrefKey.hideUnnamed) private var hideUnnamed = false
    @AppStorage(PrefKey.minimumRSSI) private var minimumRSSI = -100.0
    @AppStorage(PrefKey.valueFormat) private var valueFormat = ValueFormat.auto
    @AppStorage(PrefKey.haptics) private var haptics = true
    @AppStorage(PrefKey.autoUpdates) private var autoUpdates = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Hide unnamed devices", isOn: $hideUnnamed)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Weakest signal")
                            Spacer()
                            Text(minimumRSSI <= -100 ? "No limit" : "\(Int(minimumRSSI)) dBm")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $minimumRSSI, in: -100...(-40), step: 5)
                    }
                } header: {
                    Text("List")
                } footer: {
                    Text("There are usually lots of anonymous devices around. The slider hides the farthest ones. Pinned devices always stay.")
                }

                Section("Connections") {
                    Picker("Show values as", selection: $valueFormat) {
                        ForEach(ValueFormat.allCases) { format in
                            Text(format.title).tag(format)
                        }
                    }
                    Toggle("Haptics while finding", isOn: $haptics)
                }

                if !customCommands.commands.isEmpty {
                    Section {
                        ForEach(customCommands.commands) { command in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(command.name)
                                Text(command.hex)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { customCommands.commands[$0] }.forEach(customCommands.remove)
                        }
                    } header: {
                        Text("Your commands")
                    } footer: {
                        Text("Swipe to delete. Save new ones from any characteristic you can write to.")
                    }
                }

                Section {
                    HStack {
                        Text("Status")
                        Spacer()
                        if updates.status == .checking {
                            ProgressView()
                        } else {
                            updateStatus
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let info = updates.available {
                        Button("Install version \(info.version)") {
                            updates.presented = info
                        }
                        .fontWeight(.semibold)
                    } else {
                        Button("Check now") {
                            Task { await updates.check(manual: true) }
                        }
                        .disabled(updates.status == .checking)
                    }
                    Toggle("Check on launch", isOn: $autoUpdates)
                } header: {
                    Text("Updates")
                } footer: {
                    Text("BlueTools only asks GitHub for the latest version number. Nothing about you or your devices leaves the phone.")
                }

                Section {
                    InstallLinks()
                } header: {
                    Text("App source")
                } footer: {
                    Text("Add the source once and SideStore or LiveContainer will tell you when there's a new version.")
                }

                Section("Your data") {
                    LabeledContent("Pinned devices", value: "\(pins.pinned.count)")
                    Button("Clear device list") {
                        bluetooth.clear()
                    }
                }

                Section {
                    LabeledContent("Version", value: "\(AppLinks.currentVersion) (\(AppLinks.currentBuild))")
                    LabeledContent("Known manufacturers", value: "\(KnownIDs.companyCount)")
                    Link(destination: AppLinks.repository) {
                        HStack {
                            Text("Source code")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                    LabeledContent("License", value: "GPL-3.0")
                } header: {
                    Text("About")
                } footer: {
                    Text("No ads, no analytics, no accounts. Everything BlueTools sees over Bluetooth stays on your phone.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Settings")
        }
    }

    @ViewBuilder
    private var updateStatus: some View {
        switch updates.status {
        case .idle:
            Text("Not checked")
        case .checking:
            Text("Checking…")
        case .upToDate:
            Text("Up to date")
        case .available(let info):
            Text("\(info.version) available")
        case .failed:
            Text("Offline")
        }
    }
}
