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
        List {
            Section {
                Text(current)
                    .font(.system(.title2, design: .rounded).weight(.semibold).monospacedDigit())
                    .textSelection(.enabled)
                    .padding(.vertical, 6)
                Picker("Format", selection: $valueFormat) {
                    ForEach(ValueFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Value")
            } footer: {
                if !session.isConnected {
                    Text("The device is disconnected. Go back and connect again.")
                }
            }

            if canRead || canNotify {
                Section {
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
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            if canWrite {
                Section {
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
                    if let inputError {
                        Text(inputError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Button {
                        send()
                    } label: {
                        Label("Send", systemImage: "paperplane")
                    }
                    .disabled(input.isEmpty || !session.isConnected)
                    Button {
                        commandName = ""
                        showSave = true
                    } label: {
                        Label("Save as command", systemImage: "star")
                    }
                    .disabled(payload == nil)
                } header: {
                    Text("Write")
                }
            }

            let entries = session.entries(for: characteristic)
            Section {
                if entries.isEmpty {
                    Text("Everything that comes in or goes out shows up here.")
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
                }
            } header: {
                HStack {
                    Text("History")
                    Spacer()
                    if !entries.isEmpty {
                        Button("Clear") { session.clearHistory(for: characteristic) }
                            .font(.footnote)
                            .textCase(nil)
                    }
                }
            }

            Section("Details") {
                InfoRow(label: "UUID", value: characteristic.uuid.uuidString, mono: true)
                LabeledContent("Service", value: characteristic.service.map { PeripheralSession.name(of: $0) } ?? "?")
                LabeledContent("Supports", value: PropertyBadge.badges(for: props).joined(separator: ", "))
            }
        }
        .listStyle(.insetGrouped)
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
            Text("It shows up under Commands on every device that has this characteristic.")
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
        session.toast = "Saved \(name.isEmpty ? data.hexString : name)"
    }
}
