import Foundation
import CoreBluetooth

struct ValueEntry: Identifiable {
    enum Direction {
        case received
        case sent
    }

    let id = UUID()
    let date: Date
    let data: Data
    let direction: Direction
}

struct LogEntry: Identifiable {
    enum Kind {
        case info
        case success
        case error
    }

    let id = UUID()
    let date = Date()
    let text: String
    let kind: Kind
}

final class PeripheralSession: NSObject, ObservableObject {
    enum State: Equatable {
        case idle
        case connecting
        case connected
        case disconnected(String?)
        case failed(String)
    }

    let peripheral: CBPeripheral
    private weak var manager: BluetoothManager?

    @Published private(set) var state: State = .idle
    @Published private(set) var services: [CBService] = []
    @Published private(set) var values: [ObjectIdentifier: Data] = [:]
    @Published private(set) var history: [ObjectIdentifier: [ValueEntry]] = [:]
    @Published private(set) var notifying: Set<ObjectIdentifier> = []
    @Published private(set) var log: [LogEntry] = []
    @Published private(set) var liveRSSI: Int?
    @Published private(set) var lastError: String?

    private var rssiTimer: Timer?

    init(peripheral: CBPeripheral, manager: BluetoothManager) {
        self.peripheral = peripheral
        self.manager = manager
        super.init()
        peripheral.delegate = self
    }

    var isConnected: Bool {
        state == .connected
    }

    var isBusy: Bool {
        state == .connecting
    }

    func connect() {
        manager?.connect(self)
    }

    func disconnect() {
        manager?.disconnect(self)
    }

    func markConnecting() {
        state = .connecting
        lastError = nil
        addLog("Łączenie…", .info)
    }

    func markFailed(_ message: String) {
        state = .failed(message)
        lastError = message
        addLog(message, .error)
    }

    func didConnect() {
        state = .connected
        peripheral.delegate = self
        addLog("Połączono", .success)
        peripheral.discoverServices(nil)
        startRSSIUpdates()
    }

    func didDisconnect(error: Error?) {
        guard state != .idle else { return }
        stopRSSIUpdates()
        notifying.removeAll()
        if let error {
            state = .disconnected(error.localizedDescription)
            addLog("Rozłączono: \(error.localizedDescription)", .error)
        } else if case .disconnected = state {
            return
        } else {
            state = .disconnected(nil)
            addLog("Rozłączono", .info)
        }
    }

    func read(_ characteristic: CBCharacteristic) {
        guard isConnected else { return }
        peripheral.readValue(for: characteristic)
    }

    func toggleNotify(_ characteristic: CBCharacteristic) {
        guard isConnected else { return }
        let enable = !notifying.contains(ObjectIdentifier(characteristic))
        peripheral.setNotifyValue(enable, for: characteristic)
    }

    func write(_ data: Data, to characteristic: CBCharacteristic) {
        guard isConnected else { return }
        let props = characteristic.properties
        let type: CBCharacteristicWriteType = props.contains(.write) ? .withResponse : .withoutResponse
        peripheral.writeValue(data, for: characteristic, type: type)
        appendHistory(data, for: characteristic, direction: .sent)
        if type == .withoutResponse {
            addLog("Wysłano \(data.count) B do \(Self.name(of: characteristic))", .info)
        }
    }

    func value(for characteristic: CBCharacteristic) -> Data? {
        values[ObjectIdentifier(characteristic)]
    }

    func entries(for characteristic: CBCharacteristic) -> [ValueEntry] {
        history[ObjectIdentifier(characteristic)] ?? []
    }

    func isNotifying(_ characteristic: CBCharacteristic) -> Bool {
        notifying.contains(ObjectIdentifier(characteristic))
    }

    func clearHistory(for characteristic: CBCharacteristic) {
        history[ObjectIdentifier(characteristic)] = []
    }

    static func name(of characteristic: CBCharacteristic) -> String {
        KnownIDs.characteristicName(characteristic.uuid) ?? characteristic.uuid.uuidString
    }

    static func name(of service: CBService) -> String {
        KnownIDs.serviceName(service.uuid) ?? service.uuid.uuidString
    }

    private func startRSSIUpdates() {
        stopRSSIUpdates()
        rssiTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, self.isConnected else { return }
            self.peripheral.readRSSI()
        }
    }

    private func stopRSSIUpdates() {
        rssiTimer?.invalidate()
        rssiTimer = nil
        liveRSSI = nil
    }

    private func appendHistory(_ data: Data, for characteristic: CBCharacteristic, direction: ValueEntry.Direction) {
        let key = ObjectIdentifier(characteristic)
        var list = history[key] ?? []
        list.insert(ValueEntry(date: Date(), data: data, direction: direction), at: 0)
        if list.count > 200 {
            list.removeLast(list.count - 200)
        }
        history[key] = list
    }

    private func addLog(_ text: String, _ kind: LogEntry.Kind) {
        log.insert(LogEntry(text: text, kind: kind), at: 0)
        if log.count > 300 {
            log.removeLast(log.count - 300)
        }
    }
}

extension PeripheralSession: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            addLog("Błąd usług: \(error.localizedDescription)", .error)
            return
        }
        let found = peripheral.services ?? []
        services = found
        addLog("Znaleziono usługi: \(found.count)", .info)
        for service in found {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            addLog("Błąd charakterystyk: \(error.localizedDescription)", .error)
            return
        }
        objectWillChange.send()
        services = peripheral.services ?? services
        for characteristic in service.characteristics ?? [] where characteristic.properties.contains(.read) {
            peripheral.readValue(for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            addLog("\(Self.name(of: characteristic)): \(error.localizedDescription)", .error)
            return
        }
        guard let data = characteristic.value else { return }
        values[ObjectIdentifier(characteristic)] = data
        appendHistory(data, for: characteristic, direction: .received)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            addLog("Zapis nieudany: \(error.localizedDescription)", .error)
        } else {
            addLog("Zapisano do \(Self.name(of: characteristic))", .success)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        let key = ObjectIdentifier(characteristic)
        if let error {
            addLog("Powiadomienia: \(error.localizedDescription)", .error)
            return
        }
        if characteristic.isNotifying {
            notifying.insert(key)
            addLog("Słucham: \(Self.name(of: characteristic))", .info)
        } else {
            notifying.remove(key)
            addLog("Koniec słuchania: \(Self.name(of: characteristic))", .info)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard error == nil else { return }
        liveRSSI = RSSI.intValue
    }

    func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        objectWillChange.send()
    }

    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        peripheral.discoverServices(nil)
    }
}
