import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var bluetooth: BluetoothManager
    @EnvironmentObject private var pins: PinStore

    @AppStorage(PrefKey.hideUnnamed) private var hideUnnamed = false
    @AppStorage(PrefKey.minimumRSSI) private var minimumRSSI = -100.0
    @AppStorage(PrefKey.valueFormat) private var valueFormat = ValueFormat.auto
    @AppStorage(PrefKey.haptics) private var haptics = true

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
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
                    Link(destination: URL(string: "https://github.com/OnlineKot/BlueTools")!) {
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
                    Text("BlueTools nic nie wysyła do internetu. Bez reklam, bez analityki, bez kont. Wszystko zostaje na telefonie.")
                }
            }
            .navigationTitle("Ustawienia")
        }
    }
}
