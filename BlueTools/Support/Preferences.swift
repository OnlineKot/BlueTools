import Foundation

enum SortOrder: String, CaseIterable, Identifiable {
    case signal
    case name
    case recent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .signal: return "Strongest signal"
        case .name: return "Name"
        case .recent: return "Newest"
        }
    }
}

enum ValueFormat: String, CaseIterable, Identifiable {
    case auto
    case hex
    case text
    case decimal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Auto"
        case .hex: return "Hex"
        case .text: return "Text"
        case .decimal: return "Decimal"
        }
    }

    func render(_ data: Data) -> String {
        if data.isEmpty { return "empty" }
        switch self {
        case .hex:
            return data.hexString
        case .text:
            return String(decoding: data, as: UTF8.self)
        case .decimal:
            return data.map { String($0) }.joined(separator: " ")
        case .auto:
            if let text = data.readableText { return text }
            if data.count == 1 { return "\(data[data.startIndex])" }
            return data.hexString
        }
    }
}

enum PrefKey {
    static let hideUnnamed = "hideUnnamed"
    static let minimumRSSI = "minimumRSSI"
    static let sortOrder = "sortOrder"
    static let valueFormat = "valueFormat"
    static let haptics = "haptics"
    static let finderSound = "finderSound"
    static let autoUpdates = "autoUpdates"
    static let autoInstall = "autoInstall"
    static let installer = "installer"
}
