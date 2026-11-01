import Foundation
import CoreBluetooth

struct DiscoveredDevice: Identifiable, Equatable {
    let id: UUID
    var name: String?
    var rssi: Int
    var smoothedRSSI: Double
    var txPower: Int?
    var isConnectable: Bool
    var manufacturerData: Data?
    var serviceUUIDs: [CBUUID]
    var firstSeen: Date
    var lastSeen: Date
    var packets: Int

    init(id: UUID, rssi: Int, advertisement: [String: Any], name: String?) {
        self.id = id
        self.name = nil
        self.rssi = rssi
        self.smoothedRSSI = Double(rssi)
        self.txPower = nil
        self.isConnectable = false
        self.manufacturerData = nil
        self.serviceUUIDs = []
        self.firstSeen = Date()
        self.lastSeen = Date()
        self.packets = 0
        update(rssi: rssi, advertisement: advertisement, name: name)
    }

    mutating func update(rssi newRSSI: Int, advertisement: [String: Any], name peripheralName: String?) {
        if newRSSI < 0 && newRSSI > -127 {
            rssi = newRSSI
            smoothedRSSI = packets == 0 ? Double(newRSSI) : smoothedRSSI * 0.75 + Double(newRSSI) * 0.25
        }
        if let local = advertisement[CBAdvertisementDataLocalNameKey] as? String, !local.isEmpty {
            name = local
        } else if let peripheralName, !peripheralName.isEmpty {
            name = peripheralName
        }
        if let tx = advertisement[CBAdvertisementDataTxPowerLevelKey] as? NSNumber {
            txPower = tx.intValue
        }
        if let connectable = advertisement[CBAdvertisementDataIsConnectable] as? NSNumber {
            isConnectable = connectable.boolValue
        }
        if let data = advertisement[CBAdvertisementDataManufacturerDataKey] as? Data {
            manufacturerData = data
        }
        if let uuids = advertisement[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID], !uuids.isEmpty {
            serviceUUIDs = uuids
        }
        lastSeen = Date()
        packets += 1
    }

    var displayName: String {
        if let name, !name.isEmpty { return name }
        if let company = companyName { return "Urządzenie \(company)" }
        return "Bez nazwy"
    }

    var hasName: Bool {
        if let name, !name.isEmpty { return true }
        return false
    }

    var companyID: UInt16? {
        guard let data = manufacturerData, data.count >= 2 else { return nil }
        return UInt16(data[data.startIndex]) | (UInt16(data[data.startIndex + 1]) << 8)
    }

    var companyName: String? {
        guard let companyID else { return nil }
        return KnownIDs.companies[companyID]
    }

    var signalLevel: Int {
        let value = smoothedRSSI
        if value >= -55 { return 4 }
        if value >= -67 { return 3 }
        if value >= -78 { return 2 }
        if value >= -90 { return 1 }
        return 0
    }

    var estimatedDistance: Double {
        let reference = Double(txPower ?? -59)
        let exponent = (reference - smoothedRSSI) / 25.0
        return pow(10.0, exponent)
    }

    var distanceDescription: String {
        let meters = estimatedDistance
        if meters < 0.5 { return "tuż obok" }
        if meters < 2 { return "ok. \(String(format: "%.1f", meters).replacingOccurrences(of: ".", with: ",")) m" }
        if meters < 20 { return "ok. \(Int(meters.rounded())) m" }
        return "daleko"
    }

    func isStale(now: Date = Date()) -> Bool {
        now.timeIntervalSince(lastSeen) > 10
    }
}
