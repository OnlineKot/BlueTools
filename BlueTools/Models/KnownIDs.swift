import Foundation
import CoreBluetooth

enum KnownIDs {
    static let companies: [UInt16: String] = [
        0x0002: "Intel",
        0x0006: "Microsoft",
        0x000A: "Qualcomm",
        0x000D: "Texas Instruments",
        0x000F: "Broadcom",
        0x001D: "Qualcomm",
        0x004C: "Apple",
        0x0057: "Harman",
        0x0059: "Nordic Semiconductor",
        0x0075: "Samsung",
        0x0087: "Garmin",
        0x009E: "Bose",
        0x00D2: "Dialog Semiconductor",
        0x00E0: "Google",
        0x006B: "Polar",
        0x0131: "Cypress",
        0x0157: "Huami",
        0x0171: "Amazon",
        0x01DA: "Logitech",
        0x022B: "Tesla",
        0x02E5: "Espressif",
        0x038F: "Xiaomi",
        0x0499: "Ruuvi",
        0x05A7: "Sonos",
        0x027D: "Huawei",
        0x0118: "Radius Networks",
        0x012D: "Sony",
        0x0046: "MediaTek",
        0x005D: "Realtek",
        0x0001: "Nokia",
        0x00C4: "LG Electronics",
        0x0030: "ST Microelectronics",
        0x0065: "HP",
        0x0078: "Nike",
        0x02FF: "Silicon Labs"
    ]

    static let services: [String: String] = [
        "1800": "Dostęp ogólny",
        "1801": "Atrybuty ogólne",
        "180A": "Informacje o urządzeniu",
        "180F": "Bateria",
        "180D": "Tętno",
        "1809": "Termometr",
        "1810": "Ciśnienie krwi",
        "1812": "Klawiatura / mysz (HID)",
        "1816": "Kadencja i prędkość",
        "1818": "Moc (rower)",
        "1819": "Lokalizacja i nawigacja",
        "181A": "Czujniki środowiskowe",
        "181C": "Dane użytkownika",
        "181D": "Waga",
        "1802": "Natychmiastowy alarm",
        "1803": "Utrata połączenia",
        "1804": "Moc nadawania",
        "1805": "Aktualny czas",
        "FE9F": "Google",
        "FEAA": "Eddystone",
        "FD6F": "Powiadomienia o narażeniu",
        "FE2C": "Google Fast Pair",
        "FEED": "Tile",
        "6E400001-B5A3-F393-E0A9-E50E24DCCA9E": "Nordic UART"
    ]

    static let characteristics: [String: String] = [
        "2A00": "Nazwa urządzenia",
        "2A01": "Wygląd",
        "2A04": "Preferowane parametry połączenia",
        "2A05": "Zmiana usług",
        "2A19": "Poziom baterii",
        "2A23": "System ID",
        "2A24": "Model",
        "2A25": "Numer seryjny",
        "2A26": "Wersja firmware",
        "2A27": "Wersja sprzętu",
        "2A28": "Wersja oprogramowania",
        "2A29": "Producent",
        "2A37": "Pomiar tętna",
        "2A38": "Położenie czujnika",
        "2A1C": "Temperatura",
        "2A6E": "Temperatura",
        "2A6F": "Wilgotność",
        "2A6D": "Ciśnienie",
        "2A2B": "Aktualny czas",
        "2A06": "Poziom alarmu",
        "2A07": "Moc nadawania",
        "2A4D": "Raport HID",
        "2A50": "PnP ID",
        "6E400002-B5A3-F393-E0A9-E50E24DCCA9E": "UART RX (zapis)",
        "6E400003-B5A3-F393-E0A9-E50E24DCCA9E": "UART TX (odczyt)"
    ]

    static func serviceName(_ uuid: CBUUID) -> String? {
        services[uuid.uuidString.uppercased()]
    }

    static func characteristicName(_ uuid: CBUUID) -> String? {
        characteristics[uuid.uuidString.uppercased()]
    }

    static let textCharacteristics: Set<String> = ["2A00", "2A24", "2A25", "2A26", "2A27", "2A28", "2A29"]
}
