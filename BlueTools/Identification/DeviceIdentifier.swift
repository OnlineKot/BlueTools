import Foundation
import CoreBluetooth

enum DeviceKind: String {
    case headphones
    case phone
    case tablet
    case computer
    case watch
    case tracker
    case beacon
    case keyboard
    case mouse
    case gamepad
    case speaker
    case tv
    case sensor
    case health
    case fitness
    case light
    case lock
    case car
    case toothbrush
    case unknown

    var symbol: String {
        switch self {
        case .headphones: return "headphones"
        case .phone: return "iphone"
        case .tablet: return "ipad"
        case .computer: return "laptopcomputer"
        case .watch: return "applewatch"
        case .tracker: return "tag"
        case .beacon: return "sensor.tag.radiowaves.forward"
        case .keyboard: return "keyboard"
        case .mouse: return "computermouse"
        case .gamepad: return "gamecontroller"
        case .speaker: return "hifispeaker"
        case .tv: return "tv"
        case .sensor: return "thermometer.medium"
        case .health: return "heart"
        case .fitness: return "figure.run"
        case .light: return "lightbulb"
        case .lock: return "lock"
        case .car: return "car"
        case .toothbrush: return "mouth"
        case .unknown: return "dot.radiowaves.right"
        }
    }

    var label: String {
        switch self {
        case .headphones: return "Headphones"
        case .phone: return "Phone"
        case .tablet: return "Tablet"
        case .computer: return "Computer"
        case .watch: return "Watch"
        case .tracker: return "Tracker"
        case .beacon: return "Beacon"
        case .keyboard: return "Keyboard"
        case .mouse: return "Mouse"
        case .gamepad: return "Game controller"
        case .speaker: return "Speaker"
        case .tv: return "TV"
        case .sensor: return "Sensor"
        case .health: return "Health device"
        case .fitness: return "Fitness device"
        case .light: return "Light"
        case .lock: return "Lock"
        case .car: return "Car"
        case .toothbrush: return "Toothbrush"
        case .unknown: return "Device"
        }
    }
}

struct DeviceIdentity: Equatable {
    var kind: DeviceKind = .unknown
    var model: String?
    var details: [String] = []
}

enum DeviceIdentifier {
    private static let airpodsModels: [UInt16: (String, DeviceKind)] = [
        0x0220: ("AirPods", .headphones),
        0x0F20: ("AirPods (2nd gen)", .headphones),
        0x1320: ("AirPods (3rd gen)", .headphones),
        0x1920: ("AirPods 4", .headphones),
        0x1B20: ("AirPods 4 (ANC)", .headphones),
        0x0E20: ("AirPods Pro", .headphones),
        0x1420: ("AirPods Pro 2", .headphones),
        0x2420: ("AirPods Pro 2 (USB-C)", .headphones),
        0x0A20: ("AirPods Max", .headphones),
        0x1F20: ("AirPods Max (USB-C)", .headphones),
        0x0320: ("Powerbeats3", .headphones),
        0x0B20: ("Powerbeats Pro", .headphones),
        0x0C20: ("Beats Solo Pro", .headphones),
        0x0520: ("BeatsX", .headphones),
        0x0620: ("Beats Solo3", .headphones),
        0x0920: ("Beats Studio3", .headphones),
        0x1020: ("Beats Flex", .headphones),
        0x1120: ("Beats Studio Buds", .headphones),
        0x1220: ("Beats Fit Pro", .headphones),
        0x1620: ("Beats Studio Buds+", .headphones),
        0x1720: ("Beats Studio Pro", .headphones)
    ]

    static func identify(_ device: DiscoveredDevice) -> DeviceIdentity {
        var identity = DeviceIdentity()
        let services = Set(device.serviceUUIDs.map { $0.uuidString.uppercased() })
            .union(device.serviceData.keys.map { $0.uuidString.uppercased() })

        if let data = device.manufacturerData, let company = device.companyID {
            let payload = data.count > 2 ? Data(data.dropFirst(2)) : Data()
            switch company {
            case 0x004C: apple(payload, into: &identity)
            case 0x0006: microsoft(payload, into: &identity)
            default: break
            }
        }

        if services.contains("FD5A") { set(&identity, .tracker, "Galaxy SmartTag") }
        if services.contains("FEED") || services.contains("FEEC") || services.contains("FEEE") { set(&identity, .tracker, "Tile") }
        if services.contains("FE2C") { identity.details.append("Google Fast Pair") }
        if services.contains("FD6F") { set(&identity, .phone, nil); identity.details.append("Exposure Notifications") }
        if services.contains("FE95") { identity.details.append("Xiaomi MiBeacon") }
        if services.contains("FEAA") {
            set(&identity, .beacon, nil)
            identity.details.append(eddystone(device.serviceData[CBUUID(string: "FEAA")]))
        }
        if services.contains("180D") { set(&identity, .health, nil); identity.details.append("Heart rate") }
        if services.contains("1810") { set(&identity, .health, nil); identity.details.append("Blood pressure") }
        if services.contains("1809") { set(&identity, .health, nil); identity.details.append("Thermometer") }
        if services.contains("1808") { set(&identity, .health, nil); identity.details.append("Glucose") }
        if services.contains("181D") { set(&identity, .health, nil); identity.details.append("Scale") }
        if services.contains("1812") { set(&identity, .keyboard, nil); identity.details.append("HID") }
        if services.contains("1816") || services.contains("1818") || services.contains("1826") { set(&identity, .fitness, nil) }
        if services.contains("181A") { set(&identity, .sensor, nil) }

        if identity.kind == .unknown, let name = device.name {
            identity.kind = kind(fromName: name)
        }
        if identity.kind == .unknown, let company = device.companyID {
            switch company {
            case 0x0087, 0x0157, 0x006B: identity.kind = .watch
            case 0x009E, 0x0057, 0x05A7: identity.kind = .speaker
            case 0x0499: identity.kind = .sensor
            case 0x022B: identity.kind = .car
            default: break
            }
        }
        return identity
    }

    private static func set(_ identity: inout DeviceIdentity, _ kind: DeviceKind, _ model: String?) {
        if identity.kind == .unknown || model != nil { identity.kind = kind }
        if let model, identity.model == nil { identity.model = model }
    }

    private static func apple(_ payload: Data, into identity: inout DeviceIdentity) {
        var index = payload.startIndex
        while index + 1 < payload.endIndex {
            let type = payload[index]
            let length = Int(payload[index + 1])
            let start = index + 2
            let end = min(start + length, payload.endIndex)
            let body = payload[start..<end]
            switch type {
            case 0x02:
                if body.count >= 20 {
                    let bytes = Array(body)
                    let uuid = UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
                    let major = UInt16(bytes[16]) << 8 | UInt16(bytes[17])
                    let minor = UInt16(bytes[18]) << 8 | UInt16(bytes[19])
                    set(&identity, .beacon, "iBeacon")
                    identity.details.append("UUID \(uuid.uuidString)")
                    identity.details.append("Major \(major) · Minor \(minor)")
                }
            case 0x07:
                if body.count >= 3 {
                    let bytes = Array(body)
                    let model = UInt16(bytes[1]) << 8 | UInt16(bytes[2])
                    if let known = airpodsModels[model] {
                        set(&identity, known.1, known.0)
                    } else {
                        set(&identity, .headphones, "AirPods or Beats")
                    }
                    if bytes.count >= 6 {
                        let levels = [bytes[4] >> 4, bytes[4] & 0x0F, bytes[5] & 0x0F]
                            .filter { $0 <= 10 }
                            .map { "\(Int($0) * 10)%" }
                        if !levels.isEmpty {
                            identity.details.append("Battery " + levels.joined(separator: " · "))
                        }
                    }
                }
            case 0x12:
                set(&identity, .tracker, "Find My accessory")
                identity.details.append("Find My network")
            case 0x10:
                if identity.model == nil { set(&identity, .phone, "iPhone, iPad or Mac") }
            case 0x0C:
                identity.details.append("Handoff")
            case 0x09:
                set(&identity, .tv, "AirPlay receiver")
            case 0x0B:
                set(&identity, .watch, "Apple Watch")
            case 0x0F:
                identity.details.append("Nearby Action")
            case 0x05:
                identity.details.append("AirDrop")
            case 0x0D, 0x0E:
                identity.details.append("Personal Hotspot")
            default:
                break
            }
            index = end
        }
        if identity.kind == .unknown { identity.kind = .phone }
    }

    private static func microsoft(_ payload: Data, into identity: inout DeviceIdentity) {
        let bytes = Array(payload)
        if bytes.count >= 3, bytes[0] == 0x03, bytes[1] == 0x00, bytes[2] == 0x80 {
            identity.details.append("Windows Swift Pair")
            if bytes.count > 3, let name = String(bytes: bytes.dropFirst(3), encoding: .utf8), !name.isEmpty {
                identity.model = name.trimmingCharacters(in: .controlCharacters)
            }
        } else if bytes.first == 0x01 {
            set(&identity, .computer, "Windows PC")
        }
    }

    private static func eddystone(_ data: Data?) -> String {
        guard let first = data?.first else { return "Eddystone" }
        switch first {
        case 0x00: return "Eddystone UID"
        case 0x10: return "Eddystone URL"
        case 0x20: return "Eddystone TLM"
        case 0x30: return "Eddystone EID"
        default: return "Eddystone"
        }
    }

    static func kind(fromName raw: String) -> DeviceKind {
        let name = raw.lowercased()
        let table: [(DeviceKind, [String])] = [
            (.headphones, ["airpods", "buds", "headphone", "headset", "earbud", "wh-", "wf-", "beats", "jabra", "qc", "soundcore", "freebuds", "pods"]),
            (.watch, ["watch", "band", "fitbit", "garmin", "amazfit", "forerunner", "fenix", "venu", "whoop", "oura"]),
            (.keyboard, ["keyboard", "keys", "kbd"]),
            (.mouse, ["mouse", "mx master", "trackpad", "mx anywhere"]),
            (.gamepad, ["controller", "xbox", "dualsense", "dualshock", "joy-con", "gamepad", "8bitdo"]),
            (.speaker, ["speaker", "jbl", "sonos", "boom", "flip", "charge", "soundlink", "homepod", "echo", "marshall"]),
            (.tv, ["tv", "bravia", "roku", "chromecast", "fire tv", "[tv]"]),
            (.phone, ["iphone", "galaxy s", "pixel", "phone", "redmi", "oneplus"]),
            (.tablet, ["ipad", "tab "]),
            (.computer, ["macbook", "imac", "mac ", "laptop", "thinkpad", "surface", "desktop", "-pc"]),
            (.tracker, ["tile", "airtag", "smarttag", "chipolo", "tag"]),
            (.sensor, ["ruuvi", "thermo", "hygro", "sensor", "lywsd", "atc_", "govee h5"]),
            (.light, ["bulb", "light", "lamp", "led", "hue", "govee h6", "triones"]),
            (.lock, ["lock", "nuki", "august"]),
            (.toothbrush, ["oral-b", "sonicare", "toothbrush"]),
            (.health, ["scale", "omron", "blood", "hrm", "polar h", "heart"]),
            (.car, ["tesla", "car", "bmw", "audi", "vw "])
        ]
        for (kind, needles) in table where needles.contains(where: { name.contains($0) }) {
            return kind
        }
        return .unknown
    }
}
