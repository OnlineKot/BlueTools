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
    @Published var toast: String?

    private var pendingReads: Set<ObjectIdentifier> = []

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
        addLog("Connecting…", .info)
    }

    func markFailed(_ message: String) {
        state = .failed(message)
        lastError = message
        addLog(message, .error)
    }

    func didConnect() {
        state = .connected
        peripheral.delegate = self
        addLog("Connected", .success)
        peripheral.discoverServices(nil)
        startRSSIUpdates()
    }

    func didDisconnect(error: Error?) {
        guard state != .idle else { return }
        stopRSSIUpdates()
        notifying.removeAll()
        if let error {
            state = .disconnected(error.localizedDescription)
            addLog("Disconnected: \(error.localizedDescription)", .error)
        } else if case .disconnected = state {
            return
        } else {
            state = .disconnected(nil)
            addLog("Disconnected", .info)
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
            addLog("Sent \(data.count) B to \(Self.name(of: characteristic))", .info)
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

    func run(_ command: DeviceCommand, input: String? = nil) {
        guard isConnected else { return }
        switch command.action {
        case .read:
            if let target = command.target(in: self) { requestRead(target) }
        case .readMany(let uuids):
            for uuid in uuids {
                if let target = characteristic(uuid, in: command.service), target.properties.contains(.read) {
                    requestRead(target)
                }
            }
        case .subscribe:
            guard let target = command.target(in: self) else { return }
            let wasOn = isNotifying(target)
            peripheral.setNotifyValue(!wasOn, for: target)
            toast = wasOn ? "Stopped listening" : "Listening…"
        case .write(let data):
            guard let target = command.target(in: self) else { return }
            write(data, to: target)
            toast = command.title
        case .writeNow(let make):
            guard let target = command.target(in: self) else { return }
            write(make(), to: target)
            toast = command.title
        case .prompt(_, let appendNewline):
            guard let input, !input.isEmpty, let target = command.target(in: self) else { return }
            var data = Data(input.utf8)
            if appendNewline { data.append(0x0A) }
            write(data, to: target)
            toast = "Sent \(data.count) bytes"
        case .readAll:
            let readable = allCharacteristics.filter { $0.properties.contains(.read) }
            readable.forEach(requestRead)
            toast = "Reading \(readable.count) values"
        case .subscribeAll:
            let targets = allCharacteristics.filter {
                ($0.properties.contains(.notify) || $0.properties.contains(.indicate)) && !isNotifying($0)
            }
            targets.forEach { peripheral.setNotifyValue(true, for: $0) }
            toast = "Listening to \(targets.count) values"
        }
    }

    func run(_ command: CustomCommand) {
        guard isConnected, let target = characteristic(CBUUID(string: command.characteristic)), let data = Data(hex: command.hex) else { return }
        write(data, to: target)
        toast = command.name
    }

    private func requestRead(_ characteristic: CBCharacteristic) {
        pendingReads.insert(ObjectIdentifier(characteristic))
        peripheral.readValue(for: characteristic)
    }

    func characteristic(_ uuid: CBUUID, in service: CBUUID? = nil) -> CBCharacteristic? {
        for item in services where service == nil || item.uuid == service {
            if let match = item.characteristics?.first(where: { $0.uuid == uuid }) {
                return match
            }
        }
        return nil
    }

    var allCharacteristics: [CBCharacteristic] {
        services.flatMap { $0.characteristics ?? [] }
    }

    func note(_ text: String, success: Bool = true) {
        addLog(text, success ? .success : .error)
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
            addLog("Service discovery failed: \(error.localizedDescription)", .error)
            return
        }
        let found = peripheral.services ?? []
        services = found
        addLog("Found \(found.count) services", .info)
        for service in found {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            addLog("Characteristic discovery failed: \(error.localizedDescription)", .error)
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
        let key = ObjectIdentifier(characteristic)
        values[key] = data
        appendHistory(data, for: characteristic, direction: .received)
        if pendingReads.remove(key) != nil {
            let text = ValueDecoder.decode(characteristic.uuid, data) ?? data.readableText ?? data.hexString
            addLog("\(Self.name(of: characteristic)): \(text)", .success)
            toast = "\(Self.name(of: characteristic)): \(text)"
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            addLog("Write failed: \(error.localizedDescription)", .error)
        } else {
            addLog("Wrote to \(Self.name(of: characteristic))", .success)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        let key = ObjectIdentifier(characteristic)
        if let error {
            addLog("Notifications: \(error.localizedDescription)", .error)
            return
        }
        if characteristic.isNotifying {
            notifying.insert(key)
            addLog("Listening to \(Self.name(of: characteristic))", .info)
        } else {
            notifying.remove(key)
            addLog("Stopped listening to \(Self.name(of: characteristic))", .info)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard error == nil else { return }
        liveRSSI = RSSI.intValue
        manager?.rssiSamples.send((peripheral.identifier, RSSI.intValue))
    }

    func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        objectWillChange.send()
    }

    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        peripheral.discoverServices(nil)
    }
}
