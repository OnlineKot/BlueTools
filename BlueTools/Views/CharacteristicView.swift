import SwiftUI
import UIKit
import CoreBluetooth

struct CharacteristicView: View {
    @ObservedObject var session: PeripheralSession
    let characteristic: CBCharacteristic

    @AppStorage(PrefKey.valueFormat) private var valueFormat = ValueFormat.auto
    @State private var input = ""
    @State private var inputIsHex = false
    @State private var inputError: String?
    @FocusState private var inputFocused: Bool

    private var props: CBCharacteristicProperties { characteristic.properties }
    private var canRead: Bool { props.contains(.read) }
    private var canWrite: Bool { props.contains(.write) || props.contains(.writeWithoutResponse) }
    private var canNotify: Bool { props.contains(.notify) || props.contains(.indicate) }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(current)
                        .font(.system(.title3, design: .monospaced).weight(.medium))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Picker("Format", selection: $valueFormat) {
                        ForEach(ValueFormat.allCases) { format in
                            Text(format.title).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.vertical, 4)

                if canRead || canNotify {
                    HStack(spacing: 10) {
                        if canRead {
                            Button {
                                session.read(characteristic)
                            } label: {
                                Label("Odczytaj", systemImage: "arrow.down.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        if canNotify {
                            Button {
                                session.toggleNotify(characteristic)
                            } label: {
                                Label(session.isNotifying(characteristic) ? "Przestań" : "Słuchaj",
                                      systemImage: session.isNotifying(characteristic) ? "pause.circle" : "waveform")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(session.isNotifying(characteristic) ? .orange : .accentColor)
                        }
                    }
                    .disabled(!session.isConnected)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            } header: {
                Text("Wartość")
            } footer: {
                if !session.isConnected {
                    Text("Urządzenie jest rozłączone. Wróć i połącz się ponownie.")
                }
            }

            if canWrite {
                Section {
                    Picker("Wpisuję", selection: $inputIsHex) {
                        Text("Tekst").tag(false)
                        Text("Hex").tag(true)
                    }
                    .pickerStyle(.segmented)

                    TextField(inputIsHex ? "np. 01 FF A0" : "Co wysłać?", text: $input, axis: .vertical)
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
                        Label("Wyślij", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(input.isEmpty || !session.isConnected)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } header: {
                    Text("Zapis")
                }
            }

            Section {
                let entries = session.entries(for: characteristic)
                if entries.isEmpty {
                    Text("Tu pojawi się wszystko, co przyjdzie lub wyjdzie.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                ForEach(entries) { entry in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: entry.direction == .sent ? "arrow.up.right" : "arrow.down.left")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(entry.direction == .sent ? Color.accentColor : Color.green)
                            .frame(width: 16)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(valueFormat.render(entry.data))
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
                    Text("Historia")
                    Spacer()
                    if !session.entries(for: characteristic).isEmpty {
                        Button("Wyczyść") {
                            session.clearHistory(for: characteristic)
                        }
                        .font(.caption)
                        .textCase(nil)
                    }
                }
            }

            Section("Szczegóły") {
                InfoRow(label: "UUID", value: characteristic.uuid.uuidString, mono: true)
                InfoRow(label: "Usługa", value: characteristic.service.map { PeripheralSession.name(of: $0) } ?? "?")
                InfoRow(label: "Możliwości", value: PropertyBadge.badges(for: props).joined(separator: ", "))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(PeripheralSession.name(of: characteristic))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Gotowe") { inputFocused = false }
            }
        }
    }

    private var current: String {
        guard let data = session.value(for: characteristic) else {
            return canRead || canNotify ? "jeszcze nic" : "tylko do zapisu"
        }
        return valueFormat.render(data)
    }

    private func send() {
        inputError = nil
        let data: Data
        if inputIsHex {
            guard let parsed = Data(hex: input) else {
                inputError = "To nie wygląda na poprawny hex. Potrzebuję par znaków 0-9 i A-F."
                return
            }
            data = parsed
        } else {
            data = Data(input.utf8)
        }
        session.write(data, to: characteristic)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
