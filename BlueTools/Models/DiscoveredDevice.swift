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
    var serviceData: [CBUUID: Data]
    var identity: DeviceIdentity
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
        self.serviceData = [:]
        self.identity = DeviceIdentity()
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
        var changed = packets == 0
        if let local = advertisement[CBAdvertisementDataLocalNameKey] as? String, !local.isEmpty {
            changed = changed || name != local
            name = local
        } else if let peripheralName, !peripheralName.isEmpty, name == nil {
            changed = true
            name = peripheralName
        }
        if let tx = advertisement[CBAdvertisementDataTxPowerLevelKey] as? NSNumber {
            txPower = tx.intValue
        }
        if let connectable = advertisement[CBAdvertisementDataIsConnectable] as? NSNumber {
            isConnectable = connectable.boolValue
        }
        if let data = advertisement[CBAdvertisementDataManufacturerDataKey] as? Data, data != manufacturerData {
            manufacturerData = data
            changed = true
        }
        if let uuids = advertisement[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID], !uuids.isEmpty, uuids != serviceUUIDs {
            serviceUUIDs = uuids
            changed = true
        }
        if let data = advertisement[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data], !data.isEmpty {
            for (key, value) in data where serviceData[key] != value {
                serviceData[key] = value
                changed = true
            }
        }
        if changed {
            identity = DeviceIdentifier.identify(self)
        }
        lastSeen = Date()
        packets += 1
    }

    var displayName: String {
        if let name, !name.isEmpty { return name }
        if let model = identity.model { return model }
        if let company = companyName { return "\(company) \(identity.kind.label.lowercased())" }
        if identity.kind != .unknown { return identity.kind.label }
        return "Unnamed device"
    }

    var hasName: Bool {
        if let name, !name.isEmpty { return true }
        return identity.model != nil
    }

    var companyID: UInt16? {
        guard let data = manufacturerData, data.count >= 2 else { return nil }
        return UInt16(data[data.startIndex]) | (UInt16(data[data.startIndex + 1]) << 8)
    }

    var companyName: String? {
        guard let companyID else { return nil }
        return KnownIDs.company(companyID)
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
        if meters < 0.5 { return "right here" }
        if meters < 2 { return "about \(String(format: "%.1f", meters)) m" }
        if meters < 20 { return "about \(Int(meters.rounded())) m" }
        return "far away"
    }

    func isStale(now: Date = Date()) -> Bool {
        now.timeIntervalSince(lastSeen) > 10
    }
}
