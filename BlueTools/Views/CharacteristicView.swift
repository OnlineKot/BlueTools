import SwiftUI
import UIKit
import CoreBluetooth

struct CharacteristicView: View {
    @ObservedObject var session: PeripheralSession
    let characteristic: CBCharacteristic

    @EnvironmentObject private var customCommands: CustomCommandStore
    @AppStorage(PrefKey.valueFormat) private var valueFormat = ValueFormat.auto
    @State private var input = ""
    @State private var inputIsHex = false
    @State private var inputError: String?
    @State private var showSave = false
    @State private var commandName = ""
    @FocusState private var inputFocused: Bool

    private var props: CBCharacteristicProperties { characteristic.properties }
    private var canRead: Bool { props.contains(.read) }
    private var canWrite: Bool { props.contains(.write) || props.contains(.writeWithoutResponse) }
    private var canNotify: Bool { props.contains(.notify) || props.contains(.indicate) }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    valueCard
                    if canWrite { writeCard }
                    historyCard
                    CardSection(title: "Details") {
                        InfoRow(label: "UUID", value: characteristic.uuid.uuidString, mono: true)
                        Divider().padding(.vertical, 8)
                        InfoRow(label: "Service", value: characteristic.service.map { PeripheralSession.name(of: $0) } ?? "?")
                        Divider().padding(.vertical, 8)
                        InfoRow(label: "Supports", value: PropertyBadge.badges(for: props).joined(separator: ", "))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(PeripheralSession.name(of: characteristic))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { inputFocused = false }
            }
        }
        .alert("Save as command", isPresented: $showSave) {
            TextField("Name, e.g. Lights on", text: $commandName)
            Button("Save") { saveCommand() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It will show up under Commands on every device that has this characteristic.")
        }
    }

    private var valueCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(current)
                .font(.system(.title2, design: .rounded).weight(.semibold).monospacedDigit())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Picker("Format", selection: $valueFormat) {
                ForEach(ValueFormat.allCases) { format in
                    Text(format.title).tag(format)
                }
            }
            .pickerStyle(.segmented)
            if canRead || canNotify {
                GlassGroup(spacing: 10) {
                    HStack(spacing: 10) {
                        if canRead {
                            Button {
                                session.read(characteristic)
                            } label: {
                                Label("Read", systemImage: "arrow.down")
                                    .frame(maxWidth: .infinity)
                            }
                            .glassButton()
                        }
                        if canNotify {
                            Button {
                                session.toggleNotify(characteristic)
                            } label: {
                                Label(session.isNotifying(characteristic) ? "Stop" : "Listen",
                                      systemImage: session.isNotifying(characteristic) ? "pause.fill" : "waveform")
                                    .frame(maxWidth: .infinity)
                            }
                            .glassButton(prominent: session.isNotifying(characteristic))
                        }
                    }
                    .controlSize(.large)
                }
                .disabled(!session.isConnected)
            }
            if !session.isConnected {
                Text("The device is disconnected. Go back and connect again.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .glassCard(radius: 28)
    }

    private var writeCard: some View {
        CardSection(title: "Write") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Input", selection: $inputIsHex) {
                    Text("Text").tag(false)
                    Text("Hex").tag(true)
                }
                .pickerStyle(.segmented)

                TextField(inputIsHex ? "01 FF A0" : "What should I send?", text: $input, axis: .vertical)
                    .font(.body.monospaced())
                    .textInputAutocapitalization(inputIsHex ? .characters : .never)
                    .autocorrectionDisabled()
                    .focused($inputFocused)
                    .lineLimit(1...4)
                    .padding(12)
                    .glassCard(radius: 14)

                if let inputError {
                    Text(inputError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                GlassGroup(spacing: 10) {
                    HStack(spacing: 10) {
                        Button {
                            send()
                        } label: {
                            Label("Send", systemImage: "paperplane.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .glassButton(prominent: true)
                        .disabled(input.isEmpty || !session.isConnected)

                        Button {
                            commandName = ""
                            showSave = true
                        } label: {
                            Label("Save as command", systemImage: "star")
                                .frame(maxWidth: .infinity)
                        }
                        .glassButton()
                        .disabled(payload == nil)
                    }
                    .controlSize(.large)
                }
            }
        }
    }

    private var historyCard: some View {
        let entries = session.entries(for: characteristic)
        return CardSection(
            title: "History",
            trailing: entries.isEmpty ? nil : AnyView(
                Button("Clear") { session.clearHistory(for: characteristic) }
                    .font(.footnote.weight(.semibold))
            )
        ) {
            if entries.isEmpty {
                Text("Everything that comes in or goes out will show up here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(entries.prefix(100)) { entry in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: entry.direction == .sent ? "arrow.up.right" : "arrow.down.left")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(entry.direction == .sent ? Color.accentColor : Color.mint1)
                        .frame(width: 16)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ValueDecoder.decode(characteristic.uuid, entry.data) ?? valueFormat.render(entry.data))
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                        Text(entry.date, format: .dateTime.hour().minute().second())
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var current: String {
        guard let data = session.value(for: characteristic) else {
            return canRead || canNotify ? "No value yet" : "Write only"
        }
        return ValueDecoder.decode(characteristic.uuid, data) ?? valueFormat.render(data)
    }

    private var payload: Data? {
        guard !input.isEmpty else { return nil }
        return inputIsHex ? Data(hex: input) : Data(input.utf8)
    }

    private func send() {
        inputError = nil
        guard let data = payload else {
            inputError = "That doesn't look like valid hex. Use pairs of 0-9 and A-F."
            return
        }
        session.write(data, to: characteristic)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func saveCommand() {
        guard let data = payload else { return }
        let name = commandName.trimmingCharacters(in: .whitespaces)
        customCommands.add(CustomCommand(
            name: name.isEmpty ? "Send \(data.hexString)" : name,
            characteristic: characteristic.uuid.uuidString,
            hex: data.hexString
        ))
        session.toast = "Saved “\(name.isEmpty ? data.hexString : name)”"
    }
}
