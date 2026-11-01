import Foundation
import CoreBluetooth

enum DemoData {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-demo")
    }

    static var screen: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-screen"), index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    static let keysID = UUID(uuidString: "6F1C2B4E-0D4A-4E57-9C3B-1A2B3C4D5E60")!

    static func devices() -> [DiscoveredDevice] {
        [
            make(keysID, -62, nil, company: 0x0059, connectable: true, minutesAgo: 14),
            make(UUID(), -48, "AirPods Pro", company: 0x004C, connectable: true, minutesAgo: 9),
            make(UUID(), -57, "Mi Smart Band 8", company: 0x038F, connectable: true, minutesAgo: 6),
            make(UUID(), -66, "JBL Flip 6", company: 0x0057, connectable: true, minutesAgo: 5),
            make(UUID(), -71, "Ruuvi 3A7F", company: 0x0499, connectable: false, minutesAgo: 4),
            make(UUID(), -74, "MX Keys", company: 0x01DA, connectable: true, minutesAgo: 3),
            make(UUID(), -79, nil, company: 0x0075, connectable: false, minutesAgo: 2),
            make(UUID(), -83, nil, company: 0x0006, connectable: false, minutesAgo: 2),
            make(UUID(), -88, "LE-Bose QC45", company: 0x009E, connectable: true, minutesAgo: 1)
        ]
    }

    private static func make(_ id: UUID, _ rssi: Int, _ name: String?, company: UInt16, connectable: Bool, minutesAgo: Double) -> DiscoveredDevice {
        var advertisement: [String: Any] = [
            CBAdvertisementDataManufacturerDataKey: Data([UInt8(company & 0xFF), UInt8(company >> 8), 0x02, 0x15]),
            CBAdvertisementDataIsConnectable: NSNumber(value: connectable)
        ]
        if let name {
            advertisement[CBAdvertisementDataLocalNameKey] = name
        }
        var device = DiscoveredDevice(id: id, rssi: rssi, advertisement: advertisement, name: name)
        device.firstSeen = Date().addingTimeInterval(-minutesAgo * 60)
        device.packets = Int(minutesAgo * 37)
        return device
    }
}
