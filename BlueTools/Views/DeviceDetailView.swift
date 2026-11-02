import SwiftUI
import UIKit
import CoreBluetooth

struct DeviceDetailView: View {
    @EnvironmentObject private var bluetooth: BluetoothManager
    @EnvironmentObject private var pins: PinStore
    let deviceID: UUID

    @State private var showFinder = false
    @State private var showRename = false
    @State private var draftName = ""

    private var device: DiscoveredDevice? {
        bluetooth.devices.first { $0.id == deviceID } ?? bluetooth.device(with: deviceID)
    }

    private var title: String {
        pins.nickname(for: deviceID) ?? device?.displayName ?? "Device"
    }

    var body: some View {
        let session = bluetooth.session(for: deviceID)
        List {
            Section {
                header(session)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

            if let session {
                SessionSections(session: session)
            }
            if let device {
                identitySection(device)
                advertisementSection(device)
            }
        }
        .listStyle(.insetGrouped)
        .overlay(alignment: .bottom) {
            if let session {
                ToastHost(session: session)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        pins.toggle(deviceID)
                    } label: {
                        Label(pins.isPinned(deviceID) ? "Unpin" : "Pin", systemImage: "pin")
                    }
                    Button {
                        draftName = pins.nickname(for: deviceID) ?? ""
                        showRename = true
                    } label: {
                        Label("Nickname", systemImage: "pencil")
                    }
                    Button {
                        UIPasteboard.general.string = deviceID.uuidString
                    } label: {
                        Label("Copy identifier", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $showFinder) {
            FinderView(deviceID: deviceID, title: title)
        }
        .alert("Nickname", isPresented: $showRename) {
            TextField("Keys, bike, kitchen speaker…", text: $draftName)
            Button("Save") { pins.setNickname(draftName, for: deviceID) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only you see it. Leave it empty to use the original name.")
        }
    }

    private func header(_ session: PeripheralSession?) -> some View {
        VStack(spacing: 14) {
            Image(systemName: device?.identity.kind.symbol ?? "dot.radiowaves.right")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(Color.accentColor)
                .padding(.top, 8)

            VStack(spacing: 3) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                if let session {
                    SessionStateLabel(session: session, connectable: device?.isConnectable ?? true)
                        .padding(.top, 2)
                } else if device?.isConnectable == false {
                    StatusLabel(text: "Broadcast only", symbol: "dot.radiowaves.forward")
                        .padding(.top, 2)
                }
            }

            HStack(spacing: 0) {
                stat(device.map { "\($0.rssi)" } ?? "?", "dBm")
                Divider().frame(height: 28)
                stat(device?.distanceDescription ?? "?", "distance")
                Divider().frame(height: 28)
                stat(device.map { "\($0.packets)" } ?? "?", "packets")
            }

            GlassGroup(spacing: 10) {
                HStack(spacing: 10) {
                    if let session {
                        ConnectButton(session: session, connectable: device?.isConnectable ?? true)
                    }
                    Button {
                        showFinder = true
                    } label: {
                        Label("Find", systemImage: "location.north.line")
                            .frame(maxWidth: .infinity)
                    }
                    .glassButton(prominent: session == nil || device?.isConnectable == false)
                    .controlSize(.large)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var subtitle: String? {
        guard let device else { return nil }
        var parts: [String] = []
        if let model = device.identity.model, model != title { parts.append(model) }
        if let company = device.companyName { parts.append(company) }
        if parts.isEmpty, device.identity.kind != .unknown { parts.append(device.identity.kind.label) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func identitySection(_ device: DiscoveredDevice) -> some View {
        Section("Identified") {
            LabeledContent("Type", value: device.identity.kind.label)
            if let model = device.identity.model {
                LabeledContent("Model", value: model)
            }
            if let company = device.companyName, let id = device.companyID {
                LabeledContent("Manufacturer", value: "\(company) · 0x\(String(format: "%04X", Int(id)))")
            }
            ForEach(device.identity.details, id: \.self) { detail in
                Text(detail)
                    .font(.callout)
            }
            if !device.serviceUUIDs.isEmpty {
                InfoRow(label: "Advertised services", value: device.serviceUUIDs.map { KnownIDs.serviceName($0) ?? $0.uuidString }.joined(separator: "\n"))
            }
        }
    }

    private func advertisementSection(_ device: DiscoveredDevice) -> some View {
        Section("Advertisement") {
            InfoRow(label: "Identifier", value: device.id.uuidString, mono: true)
            LabeledContent("Connectable", value: device.isConnectable ? "Yes" : "No")
            if let tx = device.txPower {
                LabeledContent("TX power", value: "\(tx) dBm")
            }
            if let data = device.manufacturerData {
                InfoRow(label: "Manufacturer data", value: data.hexString, mono: true)
            }
            ForEach(Array(device.serviceData.keys), id: \.self) { key in
                InfoRow(label: "Service data \(key.uuidString)", value: device.serviceData[key]?.hexString ?? "", mono: true)
            }
            LabeledContent("First seen", value: device.firstSeen.formatted(date: .omitted, time: .standard))
        }
    }
}

private struct SessionStateLabel: View {
    @ObservedObject var session: PeripheralSession
    let connectable: Bool

    var body: some View {
        switch session.state {
        case .idle:
            StatusLabel(text: connectable ? "Not connected" : "Broadcast only", symbol: connectable ? "link" : "dot.radiowaves.forward")
        case .connecting:
            StatusLabel(text: "Connecting", color: .orange, symbol: "hourglass")
        case .connected:
            StatusLabel(text: "Connected", color: .mint1, symbol: "checkmark.circle.fill")
        case .disconnected(let reason):
            StatusLabel(text: reason == nil ? "Disconnected" : "Connection lost", symbol: "link")
        case .failed:
            StatusLabel(text: "Couldn't connect", color: .red, symbol: "exclamationmark.triangle.fill")
        }
    }
}

private struct ConnectButton: View {
    @ObservedObject var session: PeripheralSession
    let connectable: Bool

    var body: some View {
        Group {
            if session.isConnected {
                Button(role: .destructive) {
                    session.disconnect()
                } label: {
                    Label("Disconnect", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .glassButton()
            } else {
                Button {
                    session.connect()
                } label: {
                    Group {
                        if session.isBusy {
                            ProgressView()
                        } else {
                            Label("Connect", systemImage: "link")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .glassButton(prominent: true)
                .disabled(session.isBusy || !connectable)
            }
        }
        .controlSize(.large)
    }
}

private struct ToastHost: View {
    @ObservedObject var session: PeripheralSession

    var body: some View {
        Group {
            if let text = session.toast {
                Toast(text: text)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: text) {
                        try? await Task.sleep(nanoseconds: 2_600_000_000)
                        withAnimation { session.toast = nil }
                    }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: session.toast)
        .padding(.bottom, 16)
    }
}

private struct SessionSections: View {
    @ObservedObject var session: PeripheralSession
    @EnvironmentObject private var customCommands: CustomCommandStore
    @AppStorage(PrefKey.valueFormat) private var valueFormat = ValueFormat.auto

    @State private var prompting: DeviceCommand?
    @State private var promptText = ""
    @State private var showLog = false

    private var commands: [DeviceCommand] {
        CommandLibrary.all.filter { $0.isAvailable(in: session) }
    }

    var body: some View {
        Group {
            if session.isConnected {
                if session.services.isEmpty {
                    Section {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Asking the device what it can do…")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    commandsSection
                }
            }

            ForEach(session.services, id: \.self) { service in
                Section {
                    let characteristics = service.characteristics ?? []
                    if characteristics.isEmpty {
                        Text("No characteristics")
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
                    Text(PeripheralSession.name(of: service))
                }
            }

            if !session.log.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $showLog) {
                        ForEach(session.log.prefix(80)) { entry in
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
                        Label("Log", systemImage: "list.bullet.rectangle")
                    }
                }
            }
        }
        .alert(prompting?.title ?? "", isPresented: Binding(get: { prompting != nil }, set: { if !$0 { prompting = nil } })) {
            TextField(placeholder, text: $promptText)
            Button("Send") {
                if let command = prompting {
                    session.run(command, input: promptText)
                }
                promptText = ""
            }
            Button("Cancel", role: .cancel) { promptText = "" }
        }
    }

    private var placeholder: String {
        if case .prompt(let text, _) = prompting?.action { return text }
        return ""
    }

    @ViewBuilder
    private var commandsSection: some View {
        let custom = customCommands.commands(for: session)
        Section {
            if commands.isEmpty && custom.isEmpty {
                Text("No ready-made commands for this device. Open a characteristic below to send your own bytes and save them as a command.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(commands) { command in
                Button {
                    if case .prompt = command.action {
                        prompting = command
                    } else {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        session.run(command)
                    }
                } label: {
                    Label(command.title, systemImage: command.symbol)
                }
            }
            ForEach(custom) { command in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    session.run(command)
                } label: {
                    Label(command.name, systemImage: "star")
                }
                .swipeActions {
                    Button(role: .destructive) {
                        customCommands.remove(command)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        } header: {
            Text("Commands")
        }
    }

    private func color(for kind: LogEntry.Kind) -> Color {
        switch kind {
        case .info: return .primary
        case .success: return .mint1
        case .error: return .red
        }
    }
}

struct CharacteristicRow: View {
    let characteristic: CBCharacteristic
    let value: Data?
    let notifying: Bool
    let format: ValueFormat

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(PeripheralSession.name(of: characteristic))
                    .lineLimit(1)
                if notifying {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundStyle(Color.mint1)
                }
            }
            if let value {
                Text(ValueDecoder.decode(characteristic.uuid, value) ?? format.render(value))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text(PropertyBadge.badges(for: characteristic.properties).joined(separator: " · "))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

enum PropertyBadge {
    static func badges(for properties: CBCharacteristicProperties) -> [String] {
        var result: [String] = []
        if properties.contains(.read) { result.append("read") }
        if properties.contains(.write) { result.append("write") }
        if properties.contains(.writeWithoutResponse) { result.append("write without response") }
        if properties.contains(.notify) { result.append("notify") }
        if properties.contains(.indicate) { result.append("indicate") }
        return result
    }
}
