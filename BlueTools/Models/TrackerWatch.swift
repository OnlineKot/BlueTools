import Foundation

enum TrackerWatch {
    static let threshold: TimeInterval = 10 * 60

    static func isTracker(_ device: DiscoveredDevice) -> Bool {
        if device.identity.kind == .tracker { return true }
        return device.identity.details.contains("Find My network")
    }

    static func following(in devices: [DiscoveredDevice], now: Date = Date()) -> [DiscoveredDevice] {
        devices
            .filter { isTracker($0) && !$0.isStale(now: now) && now.timeIntervalSince($0.firstSeen) >= threshold }
            .sorted { $0.firstSeen < $1.firstSeen }
    }

    static func all(in devices: [DiscoveredDevice]) -> [DiscoveredDevice] {
        devices.filter(isTracker).sorted { $0.firstSeen < $1.firstSeen }
    }

    static func minutes(_ device: DiscoveredDevice, now: Date = Date()) -> Int {
        Int(now.timeIntervalSince(device.firstSeen) / 60)
    }
}

enum ScanExport {
    static func write(_ devices: [DiscoveredDevice], nicknames: [UUID: String]) -> URL? {
        var lines = ["identifier,name,nickname,type,model,manufacturer,rssi,distance_m,connectable,first_seen,last_seen,packets"]
        let formatter = ISO8601DateFormatter()
        for device in devices.sorted(by: { $0.smoothedRSSI > $1.smoothedRSSI }) {
            let fields: [String] = [
                device.id.uuidString,
                device.name ?? "",
                nicknames[device.id] ?? "",
                device.identity.kind.label,
                device.identity.model ?? "",
                device.companyName ?? "",
                String(device.rssi),
                String(format: "%.1f", device.estimatedDistance),
                device.isConnectable ? "yes" : "no",
                formatter.string(from: device.firstSeen),
                formatter.string(from: device.lastSeen),
                String(device.packets)
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }
        let stamp = Int(Date().timeIntervalSince1970)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bluetools-scan-\(stamp).csv")
        do {
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
