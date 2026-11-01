import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var bluetooth: BluetoothManager
    @EnvironmentObject private var pins: PinStore
    @EnvironmentObject private var updates: UpdateChecker

    @AppStorage(PrefKey.hideUnnamed) private var hideUnnamed = false
    @AppStorage(PrefKey.minimumRSSI) private var minimumRSSI = -100.0
    @AppStorage(PrefKey.valueFormat) private var valueFormat = ValueFormat.auto
    @AppStorage(PrefKey.haptics) private var haptics = true
    @AppStorage(PrefKey.autoUpdates) private var autoUpdates = true

    private var version: String {
        "\(AppLinks.currentVersion) (\(AppLinks.currentBuild))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Ukryj urządzenia bez nazwy", isOn: $hideUnnamed)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Najsłabszy sygnał")
                            Spacer()
                            Text(minimumRSSI <= -100 ? "bez limitu" : "\(Int(minimumRSSI)) dBm")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $minimumRSSI, in: -100...(-40), step: 5)
                    }
                } header: {
                    Text("Lista")
                } footer: {
                    Text("Wokół zwykle kręci się sporo anonimowych urządzeń. Suwak odsiewa te najdalsze, przypięte zostają zawsze.")
                }

                Section {
                    Picker("Pokazuj wartości jako", selection: $valueFormat) {
                        ForEach(ValueFormat.allCases) { format in
                            Text(format.title).tag(format)
                        }
                    }
                    Toggle("Wibracje przy szukaniu", isOn: $haptics)
                } header: {
                    Text("Połączenia")
                }

                Section {
                    HStack {
                        Text("Stan")
                        Spacer()
                        if updates.status == .checking {
                            ProgressView()
                        } else {
                            updateStatus
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let info = updates.available {
                        Button {
                            updates.presented = info
                        } label: {
                            Text("Zainstaluj wersję \(info.version)")
                                .fontWeight(.semibold)
                        }
                    } else {
                        Button {
                            Task { await updates.check(manual: true) }
                        } label: {
                            Text("Sprawdź teraz")
                        }
                        .disabled(updates.status == .checking)
                    }
                    Toggle("Sprawdzaj przy starcie", isOn: $autoUpdates)
                } header: {
                    Text("Aktualizacje")
                } footer: {
                    Text("Apka pyta GitHuba tylko o numer najnowszej wersji. Nic o tobie ani o twoich urządzeniach nie wychodzi z telefonu.")
                }

                Section {
                    InstallLinks()
                } header: {
                    Text("Źródło aplikacji")
                } footer: {
                    Text("Po dodaniu źródła SideStore i LiveContainer same dadzą znać, kiedy wyjdzie nowa wersja.")
                }

                Section("Twoje dane") {
                    HStack {
                        Text("Przypięte urządzenia")
                        Spacer()
                        Text("\(pins.pinned.count)")
                            .foregroundStyle(.secondary)
                    }
                    Button("Wyczyść listę urządzeń") {
                        bluetooth.clear()
                    }
                }

                Section {
                    HStack {
                        Text("Wersja")
                        Spacer()
                        Text(version)
                            .foregroundStyle(.secondary)
                    }
                    Link(destination: AppLinks.repository) {
                        HStack {
                            Text("Kod źródłowy")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                    HStack {
                        Text("Licencja")
                        Spacer()
                        Text("GPL-3.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("O aplikacji")
                } footer: {
                    Text("Bez reklam, bez analityki, bez kont. Wszystko, co zobaczysz przez Bluetooth, zostaje na telefonie.")
                }
            }
            .navigationTitle("Ustawienia")
        }
    }

    @ViewBuilder
    private var updateStatus: some View {
        switch updates.status {
        case .idle:
            Text("Nie sprawdzano")
        case .checking:
            Text("Sprawdzam…")
        case .upToDate:
            Text("Aktualna")
        case .available(let info):
            Text("Jest \(info.version)")
        case .failed:
            Text("Brak połączenia")
        }
    }
}
