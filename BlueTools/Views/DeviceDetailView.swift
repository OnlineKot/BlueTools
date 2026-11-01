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
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header(session)
                    if let session {
                        SessionSections(session: session)
                    }
                    if let device {
                        identitySection(device)
                        advertisementSection(device)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 90)
            }
        }
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
        VStack(spacing: 16) {
            Image(systemName: device?.identity.kind.symbol ?? "dot.radiowaves.right")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 84, height: 84)
                .glassCircle(tint: Color.accentColor.opacity(0.18))

            VStack(spacing: 4) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let session {
                SessionStatePill(session: session, connectable: device?.isConnectable ?? true)
            } else if device?.isConnectable == false {
                Pill(text: "Broadcast only", color: .secondary, symbol: "dot.radiowaves.forward")
            }

            HStack(spacing: 0) {
                stat(rssiText, "dBm")
                stat(device?.distanceDescription ?? "?", "distance")
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
                        Label("Find", systemImage: "location.north.line.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .glassButton(prominent: session == nil || device?.isConnectable == false)
                    .controlSize(.large)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassCard(radius: 30)
    }

    private var subtitle: String? {
        guard let device else { return nil }
        var parts: [String] = []
        if let model = device.identity.model, model != title { parts.append(model) }
        if let company = device.companyName { parts.append(company) }
        if parts.isEmpty, device.identity.kind != .unknown { parts.append(device.identity.kind.label) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var rssiText: String {
        if let device { return "\(device.rssi)" }
        return "?"
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

    @ViewBuilder
    private func identitySection(_ device: DiscoveredDevice) -> some View {
        CardSection(title: "Identified") {
            InfoRow(label: "Type", value: device.identity.kind.label)
            if let model = device.identity.model {
                Divider().padding(.vertical, 8)
                InfoRow(label: "Model", value: model)
            }
            if let company = device.companyName, let id = device.companyID {
                Divider().padding(.vertical, 8)
                InfoRow(label: "Manufacturer", value: "\(company) (0x\(String(format: "%04X", Int(id))))")
            }
            ForEach(device.identity.details, id: \.self) { detail in
                Divider().padding(.vertical, 8)
                InfoRow(label: "Detail", value: detail)
            }
            if !device.serviceUUIDs.isEmpty {
                Divider().padding(.vertical, 8)
                InfoRow(label: "Advertised services", value: device.serviceUUIDs.map { KnownIDs.serviceName($0) ?? $0.uuidString }.joined(separator: "\n"))
            }
        }
    }

    private func advertisementSection(_ device: DiscoveredDevice) -> some View {
        CardSection(title: "Advertisement") {
            InfoRow(label: "Identifier", value: device.id.uuidString, mono: true)
            Divider().padding(.vertical, 8)
            InfoRow(label: "Connectable", value: device.isConnectable ? "Yes" : "No")
            if let tx = device.txPower {
                Divider().padding(.vertical, 8)
                InfoRow(label: "TX power", value: "\(tx) dBm")
            }
            if let data = device.manufacturerData {
                Divider().padding(.vertical, 8)
                InfoRow(label: "Manufacturer data", value: data.hexString, mono: true)
            }
            ForEach(Array(device.serviceData.keys), id: \.self) { key in
                Divider().padding(.vertical, 8)
                InfoRow(label: "Service data \(key.uuidString)", value: device.serviceData[key]?.hexString ?? "", mono: true)
            }
            Divider().padding(.vertical, 8)
            InfoRow(label: "First seen", value: device.firstSeen.formatted(date: .omitted, time: .standard))
        }
    }
}

private struct SessionStatePill: View {
    @ObservedObject var session: PeripheralSession
    let connectable: Bool

    var body: some View {
        switch session.state {
        case .idle:
            if connectable {
                Pill(text: "Not connected", color: .secondary, symbol: "link")
            } else {
                Pill(text: "Broadcast only", color: .secondary, symbol: "dot.radiowaves.forward")
            }
        case .connecting:
            Pill(text: "Connecting", color: .orange, symbol: "hourglass")
        case .connected:
            Pill(text: "Connected", color: .mint1, symbol: "checkmark.circle.fill")
        case .disconnected(let reason):
            Pill(text: reason == nil ? "Disconnected" : "Connection lost", color: .secondary, symbol: "link.badge.plus")
        case .failed:
            Pill(text: "Couldn't connect", color: .red, symbol: "exclamationmark.triangle.fill")
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
        VStack(alignment: .leading, spacing: 22) {
            if session.isConnected {
                if session.services.isEmpty {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Asking the device what it can do…")
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
                } else {
                    commandsSection
                }
            }

            ForEach(session.services, id: \.self) { service in
                CardSection(title: PeripheralSession.name(of: service)) {
                    let characteristics = service.characteristics ?? []
                    if characteristics.isEmpty {
                        Text("No characteristics")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(characteristics, id: \.self) { characteristic in
                        if characteristic != characteristics.first { Divider().padding(.vertical, 8) }
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
                        .buttonStyle(.plain)
                    }
                }
            }

            if !session.log.isEmpty {
                CardSection(title: "Log") {
                    DisclosureGroup(isExpanded: $showLog) {
                        VStack(alignment: .leading, spacing: 6) {
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
                        }
                        .padding(.top, 8)
                    } label: {
                        Text(session.log.first?.text ?? "")
                            .font(.callout)
                            .lineLimit(1)
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

    private var commandsSection: some View {
        let custom = customCommands.commands(for: session)
        return CardSection(title: "Commands") {
            if commands.isEmpty && custom.isEmpty {
                Text("No ready-made commands for this device yet. Open a characteristic to send your own and save it as a command.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                GlassGroup(spacing: 8) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(commands) { command in
                            CommandChip(title: command.title, symbol: command.symbol) {
                                if case .prompt = command.action {
                                    prompting = command
                                } else {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    session.run(command)
                                }
                            }
                        }
                        ForEach(custom) { command in
                            CommandChip(title: command.name, symbol: "star.fill") {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                session.run(command)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    customCommands.remove(command)
                                } label: {
                                    Label("Delete command", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
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

struct CommandChip: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .contentShape(Rectangle())
            .glassCard(radius: 16, tint: Color.accentColor.opacity(0.08), interactive: true)
        }
        .buttonStyle(.plain)
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CharacteristicRow: View {
    let characteristic: CBCharacteristic
    let value: Data?
    let notifying: Bool
    let format: ValueFormat

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(PeripheralSession.name(of: characteristic))
                        .font(.callout.weight(.semibold))
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
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
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
