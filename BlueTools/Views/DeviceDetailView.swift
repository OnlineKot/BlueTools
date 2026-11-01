import SwiftUI
import UIKit
import CoreBluetooth

struct DeviceDetailView: View {
    @EnvironmentObject private var bluetooth: BluetoothManager
    let deviceID: UUID

    var body: some View {
        if let session = bluetooth.session(for: deviceID) {
            DeviceDetailContent(deviceID: deviceID, session: session)
        } else {
            EmptyStateView(
                icon: "questionmark.circle",
                title: "Zniknęło",
                message: "To urządzenie nie jest już widoczne. Wróć do listy i spróbuj jeszcze raz."
            )
        }
    }
}

private struct DeviceDetailContent: View {
    @EnvironmentObject private var bluetooth: BluetoothManager
    @EnvironmentObject private var pins: PinStore
    @AppStorage(PrefKey.valueFormat) private var valueFormat = ValueFormat.auto

    let deviceID: UUID
    @ObservedObject var session: PeripheralSession

    @State private var showFinder = false
    @State private var showRename = false
    @State private var draftName = ""
    @State private var showLog = false

    private var device: DiscoveredDevice? {
        bluetooth.devices.first { $0.id == deviceID } ?? bluetooth.device(with: deviceID)
    }

    private var title: String {
        pins.nickname(for: deviceID) ?? device?.displayName ?? session.peripheral.name ?? "Urządzenie"
    }

    var body: some View {
        List {
            Section {
                header
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

            if let device {
                advertisementSection(device)
            }

            servicesSection

            Section {
                DisclosureGroup(isExpanded: $showLog) {
                    if session.log.isEmpty {
                        Text("Na razie cisza.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(session.log) { entry in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(entry.date, format: .dateTime.hour().minute().second())
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Text(entry.text)
                                .font(.callout)
                                .foregroundStyle(color(for: entry.kind))
                        }
                    }
                } label: {
                    Label("Dziennik", systemImage: "list.bullet.rectangle")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        pins.toggle(deviceID)
                    } label: {
                        Label(pins.isPinned(deviceID) ? "Odepnij" : "Przypnij", systemImage: "pin")
                    }
                    Button {
                        draftName = pins.nickname(for: deviceID) ?? ""
                        showRename = true
                    } label: {
                        Label("Własna nazwa", systemImage: "pencil")
                    }
                    Button {
                        UIPasteboard.general.string = deviceID.uuidString
                    } label: {
                        Label("Kopiuj identyfikator", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showFinder) {
            FinderView(deviceID: deviceID, title: title)
        }
        .alert("Własna nazwa", isPresented: $showRename) {
            TextField("np. Klucze, Rower, Głośnik w kuchni", text: $draftName)
            Button("Zapisz") { pins.setNickname(draftName, for: deviceID) }
            Button("Anuluj", role: .cancel) {}
        } message: {
            Text("Widoczna tylko u ciebie. Zostaw puste, żeby wrócić do oryginalnej.")
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                if let company = device?.companyName {
                    Text(company)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                stateLabel
                    .padding(.top, 2)
            }

            HStack(spacing: 20) {
                stat(value: rssiText, label: "dBm")
                Divider().frame(height: 30)
                stat(value: device?.distanceDescription ?? "?", label: "odległość")
                Divider().frame(height: 30)
                stat(value: device.map { "\($0.packets)" } ?? "?", label: "pakietów")
            }

            HStack(spacing: 10) {
                connectButton
                Button {
                    showFinder = true
                } label: {
                    Label("Szukaj", systemImage: "location.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var connectButton: some View {
        if session.isConnected {
            Button(role: .destructive) {
                session.disconnect()
            } label: {
                Label("Rozłącz", systemImage: "xmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        } else {
            Button {
                session.connect()
            } label: {
                Group {
                    if session.isBusy {
                        ProgressView()
                    } else {
                        Label("Połącz", systemImage: "link")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(session.isBusy || device?.isConnectable == false)
        }
    }

    @ViewBuilder
    private var stateLabel: some View {
        switch session.state {
        case .idle:
            if device?.isConnectable == false {
                Pill(text: "Tylko rozgłasza, nie da się połączyć", color: .secondary)
            } else {
                Pill(text: "Niepołączone", color: .secondary)
            }
        case .connecting:
            Pill(text: "Łączę…", color: .orange)
        case .connected:
            Pill(text: "Połączone", color: .green)
        case .disconnected(let reason):
            Pill(text: reason == nil ? "Rozłączone" : "Połączenie zerwane", color: .secondary)
        case .failed:
            Pill(text: "Nie udało się połączyć", color: .red)
        }
    }

    private var rssiText: String {
        if let live = session.liveRSSI { return "\(live)" }
        if let device { return "\(device.rssi)" }
        return "?"
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 70)
    }

    private func advertisementSection(_ device: DiscoveredDevice) -> some View {
        Section("Rozgłaszanie") {
            InfoRow(label: "Identyfikator", value: device.id.uuidString, mono: true)
            if let name = device.name {
                InfoRow(label: "Nazwa", value: name)
            }
            InfoRow(label: "Można połączyć", value: device.isConnectable ? "Tak" : "Nie")
            if let tx = device.txPower {
                InfoRow(label: "Moc nadawania", value: "\(tx) dBm")
            }
            if let data = device.manufacturerData {
                InfoRow(label: "Dane producenta", value: data.hexString, mono: true)
            }
            if !device.serviceUUIDs.isEmpty {
                InfoRow(
                    label: "Ogłaszane usługi",
                    value: device.serviceUUIDs.map { KnownIDs.serviceName($0) ?? $0.uuidString }.joined(separator: "\n"),
                    mono: true
                )
            }
            InfoRow(label: "Pierwszy raz", value: device.firstSeen.formatted(date: .omitted, time: .standard))
        }
    }

    @ViewBuilder
    private var servicesSection: some View {
        if session.isConnected && session.services.isEmpty {
            Section("Usługi") {
                HStack {
                    ProgressView()
                    Text("Pytam urządzenie, co potrafi…")
                        .foregroundStyle(.secondary)
                        .padding(.leading, 6)
                }
            }
        }
        ForEach(session.services, id: \.self) { service in
            Section {
                let characteristics = service.characteristics ?? []
                if characteristics.isEmpty {
                    Text("Brak charakterystyk")
                        .foregroundStyle(.secondary)
                }
                ForEach(characteristics, id: \.self) { characteristic in
                    NavigationLink {
                        CharacteristicView(session: session, characteristic: characteristic)
                    } label: {
                        CharacteristicRow(
                            characteristic: characteristic,
                            value: session.value(for: characteristic),
                            notifying: session.isNotifying(characteristic),
                            format: valueFormat
                        )
                    }
                }
            } header: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(PeripheralSession.name(of: service))
                    if KnownIDs.serviceName(service.uuid) != nil {
                        Text(service.uuid.uuidString)
                            .font(.caption2.monospaced())
                            .textCase(nil)
                    }
                }
            }
        }
    }

    private func color(for kind: LogEntry.Kind) -> Color {
        switch kind {
        case .info: return .primary
        case .success: return .green
        case .error: return .red
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var mono = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(mono ? .callout.monospaced() : .callout)
                .textSelection(.enabled)
        }
        .padding(.vertical, 1)
    }
}

struct CharacteristicRow: View {
    let characteristic: CBCharacteristic
    let value: Data?
    let notifying: Bool
    let format: ValueFormat

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(PeripheralSession.name(of: characteristic))
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                if notifying {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            if let value {
                Text(format.render(value))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HStack(spacing: 4) {
                ForEach(PropertyBadge.badges(for: characteristic.properties), id: \.self) { badge in
                    Pill(text: badge, color: .accentColor)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

enum PropertyBadge {
    static func badges(for properties: CBCharacteristicProperties) -> [String] {
        var result: [String] = []
        if properties.contains(.read) { result.append("odczyt") }
        if properties.contains(.write) { result.append("zapis") }
        if properties.contains(.writeWithoutResponse) { result.append("zapis bez odp.") }
        if properties.contains(.notify) { result.append("powiadomienia") }
        if properties.contains(.indicate) { result.append("indykacje") }
        return result
    }
}
