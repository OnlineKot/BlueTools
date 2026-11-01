import Foundation
import CoreBluetooth

enum KnownIDs {
    private static func load(_ name: String) -> [String: String] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let table = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return table
    }

    private static let companyTable = load("companies")
    private static let serviceTable = load("services")
    private static let characteristicTable = load("characteristics")

    static var companyCount: Int { companyTable.count }

    static func company(_ id: UInt16) -> String? {
        companyTable[String(id)]
    }

    static func serviceName(_ uuid: CBUUID) -> String? {
        serviceTable[uuid.uuidString.uppercased()]
    }

    static func characteristicName(_ uuid: CBUUID) -> String? {
        characteristicTable[uuid.uuidString.uppercased()]
    }
}
