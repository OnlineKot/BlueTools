import Foundation
import CoreBluetooth

struct DeviceCommand: Identifiable {
    enum Action {
        case read
        case readMany([CBUUID])
        case subscribe
        case write(Data)
        case writeNow(() -> Data)
        case prompt(placeholder: String, appendNewline: Bool)
        case readAll
        case subscribeAll
    }

    let id: String
    let title: String
    let symbol: String
    let service: CBUUID?
    let characteristic: CBUUID?
    let action: Action

    func target(in session: PeripheralSession) -> CBCharacteristic? {
        guard let characteristic else { return nil }
        return session.characteristic(characteristic, in: service)
    }

    func isAvailable(in session: PeripheralSession) -> Bool {
        switch action {
        case .readAll:
            return session.allCharacteristics.contains { $0.properties.contains(.read) }
        case .subscribeAll:
            return session.allCharacteristics.contains { $0.properties.contains(.notify) || $0.properties.contains(.indicate) }
        case .readMany(let uuids):
            return uuids.contains { session.characteristic($0, in: service)?.properties.contains(.read) == true }
        default:
            break
        }
        guard let target = target(in: session) else { return false }
        let props = target.properties
        switch action {
        case .read: return props.contains(.read)
        case .subscribe: return props.contains(.notify) || props.contains(.indicate)
        case .write, .writeNow, .prompt: return props.contains(.write) || props.contains(.writeWithoutResponse)
        default: return false
        }
    }
}

enum CommandLibrary {
    private static func uuid(_ value: String) -> CBUUID { CBUUID(string: value) }

    static let all: [DeviceCommand] = [
        DeviceCommand(id: "ring-high", title: "Ring loudly", symbol: "speaker.wave.3.fill", service: uuid("1802"), characteristic: uuid("2A06"), action: .write(Data([0x02]))),
        DeviceCommand(id: "ring-mild", title: "Ring softly", symbol: "speaker.wave.1.fill", service: uuid("1802"), characteristic: uuid("2A06"), action: .write(Data([0x01]))),
        DeviceCommand(id: "ring-stop", title: "Stop ringing", symbol: "speaker.slash.fill", service: uuid("1802"), characteristic: uuid("2A06"), action: .write(Data([0x00]))),
        DeviceCommand(id: "loss-on", title: "Alert when out of range", symbol: "bell.badge.fill", service: uuid("1803"), characteristic: uuid("2A06"), action: .write(Data([0x02]))),
        DeviceCommand(id: "loss-off", title: "Silence range alert", symbol: "bell.slash.fill", service: uuid("1803"), characteristic: uuid("2A06"), action: .write(Data([0x00]))),
        DeviceCommand(id: "battery", title: "Battery level", symbol: "battery.75percent", service: nil, characteristic: uuid("2A19"), action: .read),
        DeviceCommand(id: "battery-live", title: "Watch battery", symbol: "bolt.badge.clock.fill", service: nil, characteristic: uuid("2A19"), action: .subscribe),
        DeviceCommand(id: "info", title: "Device info", symbol: "info.circle.fill", service: uuid("180A"), characteristic: nil, action: .readMany([uuid("2A29"), uuid("2A24"), uuid("2A25"), uuid("2A27"), uuid("2A26"), uuid("2A28")])),
        DeviceCommand(id: "tx-power", title: "Transmit power", symbol: "antenna.radiowaves.left.and.right", service: nil, characteristic: uuid("2A07"), action: .read),
        DeviceCommand(id: "sync-time", title: "Sync clock", symbol: "clock.arrow.2.circlepath", service: nil, characteristic: uuid("2A2B"), action: .writeNow(CommandLibrary.currentTime)),
        DeviceCommand(id: "heart-live", title: "Live heart rate", symbol: "heart.fill", service: nil, characteristic: uuid("2A37"), action: .subscribe),
        DeviceCommand(id: "heart-reset", title: "Reset energy counter", symbol: "arrow.counterclockwise", service: nil, characteristic: uuid("2A39"), action: .write(Data([0x01]))),
        DeviceCommand(id: "temp-live", title: "Live temperature", symbol: "thermometer.medium", service: nil, characteristic: uuid("2A6E"), action: .subscribe),
        DeviceCommand(id: "humidity-live", title: "Live humidity", symbol: "humidity.fill", service: nil, characteristic: uuid("2A6F"), action: .subscribe),
        DeviceCommand(id: "pressure-live", title: "Live pressure", symbol: "gauge.with.dots.needle.50percent", service: nil, characteristic: uuid("2A6D"), action: .subscribe),
        DeviceCommand(id: "cycling-live", title: "Live cycling data", symbol: "bicycle", service: nil, characteristic: uuid("2A5B"), action: .subscribe),
        DeviceCommand(id: "running-live", title: "Live running data", symbol: "figure.run", service: nil, characteristic: uuid("2A53"), action: .subscribe),
        DeviceCommand(id: "weight-live", title: "Live weight", symbol: "scalemass.fill", service: nil, characteristic: uuid("2A9D"), action: .subscribe),
        DeviceCommand(id: "uart-send", title: "Send text (UART)", symbol: "text.bubble.fill", service: nil, characteristic: uuid("6E400002-B5A3-F393-E0A9-E50E24DCCA9E"), action: .prompt(placeholder: "Text to send", appendNewline: true)),
        DeviceCommand(id: "uart-listen", title: "Listen (UART)", symbol: "ear.fill", service: nil, characteristic: uuid("6E400003-B5A3-F393-E0A9-E50E24DCCA9E"), action: .subscribe),
        DeviceCommand(id: "hm10-send", title: "Send text (HM-10)", symbol: "text.bubble.fill", service: nil, characteristic: uuid("FFE1"), action: .prompt(placeholder: "Text to send", appendNewline: true)),
        DeviceCommand(id: "hm10-listen", title: "Listen (HM-10)", symbol: "ear.fill", service: nil, characteristic: uuid("FFE1"), action: .subscribe),
        DeviceCommand(id: "rename", title: "Rename device", symbol: "character.cursor.ibeam", service: nil, characteristic: uuid("2A00"), action: .prompt(placeholder: "New name", appendNewline: false)),
        DeviceCommand(id: "read-all", title: "Read everything", symbol: "arrow.down.doc.fill", service: nil, characteristic: nil, action: .readAll),
        DeviceCommand(id: "listen-all", title: "Listen to everything", symbol: "waveform", service: nil, characteristic: nil, action: .subscribeAll)
    ]

    static func currentTime() -> Data {
        let calendar = Calendar(identifier: .gregorian)
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .weekday, .nanosecond], from: Date())
        let year: Int = parts.year ?? 2026
        let weekday: Int = ((parts.weekday ?? 1) + 5) % 7 + 1
        let nanos: Double = Double(parts.nanosecond ?? 0)
        let fraction: Int = min(255, Int(nanos / 1_000_000_000 * 256))
        var bytes: [UInt8] = []
        bytes.append(UInt8(year & 0xFF))
        bytes.append(UInt8((year >> 8) & 0xFF))
        bytes.append(UInt8(parts.month ?? 1))
        bytes.append(UInt8(parts.day ?? 1))
        bytes.append(UInt8(parts.hour ?? 0))
        bytes.append(UInt8(parts.minute ?? 0))
        bytes.append(UInt8(parts.second ?? 0))
        bytes.append(UInt8(weekday))
        bytes.append(UInt8(fraction))
        bytes.append(0x01)
        return Data(bytes)
    }
}

struct CustomCommand: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var characteristic: String
    var hex: String
}

final class CustomCommandStore: ObservableObject {
    @Published private(set) var commands: [CustomCommand] = []
    private let key = "customCommands"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([CustomCommand].self, from: data) {
            commands = decoded
        }
    }

    func add(_ command: CustomCommand) {
        commands.append(command)
        save()
    }

    func remove(_ command: CustomCommand) {
        commands.removeAll { $0.id == command.id }
        save()
    }

    func commands(for session: PeripheralSession) -> [CustomCommand] {
        commands.filter { session.characteristic(CBUUID(string: $0.characteristic)) != nil }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(commands) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
