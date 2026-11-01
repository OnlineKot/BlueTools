import Foundation
import CoreBluetooth

enum ValueDecoder {
    static func decode(_ uuid: CBUUID, _ data: Data) -> String? {
        let bytes = Array(data)
        switch uuid.uuidString.uppercased() {
        case "2A19":
            return bytes.first.map { "\($0)%" }
        case "2A37":
            guard let flags = bytes.first else { return nil }
            if flags & 0x01 == 0, bytes.count >= 2 { return "\(bytes[1]) bpm" }
            if bytes.count >= 3 { return "\(UInt16(bytes[1]) | UInt16(bytes[2]) << 8) bpm" }
            return nil
        case "2A6E", "2A1F":
            guard bytes.count >= 2 else { return nil }
            let raw = Int16(bitPattern: UInt16(bytes[0]) | UInt16(bytes[1]) << 8)
            return String(format: "%.1f °C", Double(raw) * (uuid.uuidString.uppercased() == "2A6E" ? 0.01 : 0.1))
        case "2A6F":
            guard bytes.count >= 2 else { return nil }
            return String(format: "%.1f %%", Double(UInt16(bytes[0]) | UInt16(bytes[1]) << 8) * 0.01)
        case "2A6D":
            guard bytes.count >= 4 else { return nil }
            let raw = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
            return String(format: "%.1f hPa", Double(raw) * 0.1 / 100)
        case "2A07":
            return bytes.first.map { "\(Int8(bitPattern: $0)) dBm" }
        case "2A06":
            switch bytes.first {
            case 0: return "No alert"
            case 1: return "Mild alert"
            case 2: return "High alert"
            default: return nil
            }
        case "2A2B":
            guard bytes.count >= 7 else { return nil }
            let year = Int(UInt16(bytes[0]) | UInt16(bytes[1]) << 8)
            return String(format: "%04d-%02d-%02d %02d:%02d:%02d", year, Int(bytes[2]), Int(bytes[3]), Int(bytes[4]), Int(bytes[5]), Int(bytes[6]))
        case "2A9D":
            guard bytes.count >= 3 else { return nil }
            let raw = Double(UInt16(bytes[1]) | UInt16(bytes[2]) << 8)
            return bytes[0] & 0x01 == 0 ? String(format: "%.2f kg", raw * 0.005) : String(format: "%.2f lb", raw * 0.01)
        case "2A00", "2A24", "2A25", "2A26", "2A27", "2A28", "2A29":
            return data.readableText
        default:
            return nil
        }
    }
}
