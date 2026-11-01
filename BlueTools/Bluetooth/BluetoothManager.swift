import Foundation
import CoreBluetooth
import Combine

final class BluetoothManager: NSObject, ObservableObject {
    enum Availability: Equatable {
        case unknown
        case ready
        case poweredOff
        case unauthorized
        case unsupported
        case resetting
    }

    @Published private(set) var availability: Availability = .unknown
    @Published private(set) var devices: [DiscoveredDevice] = []
    @Published private(set) var isScanning = false
    @Published var wantsScanning = true {
        didSet { applyScanState() }
    }

    private var central: CBCentralManager?
    let isDemo = DemoData.isEnabled
    private var store: [UUID: DiscoveredDevice] = [:]
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var sessions: [UUID: PeripheralSession] = [:]
    private var refreshTimer: AnyCancellable?
    let rssiSamples = PassthroughSubject<(UUID, Int), Never>()

    override init() {
        super.init()
        if isDemo {
            availability = .ready
            isScanning = true
            for device in DemoData.devices() {
                store[device.id] = device
            }
            devices = Array(store.values)
        } else {
            central = CBCentralManager(delegate: self, queue: nil)
        }
        refreshTimer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.publishSnapshot() }
    }

    func device(with id: UUID) -> DiscoveredDevice? {
        store[id]
    }

    func clear() {
        store = store.filter { sessions[$0.key]?.isConnected == true }
        publishSnapshot()
    }

    func session(for id: UUID) -> PeripheralSession? {
        if let existing = sessions[id] { return existing }
        guard let central, let peripheral = peripherals[id] ?? central.retrievePeripherals(withIdentifiers: [id]).first else {
            return nil
        }
        peripherals[id] = peripheral
        let session = PeripheralSession(peripheral: peripheral, manager: self)
        sessions[id] = session
        return session
    }

    func connect(_ session: PeripheralSession) {
        guard availability == .ready else {
            session.markFailed("Bluetooth is not ready.")
            return
        }
        session.markConnecting()
        central?.connect(session.peripheral, options: nil)
    }

    func disconnect(_ session: PeripheralSession) {
        central?.cancelPeripheralConnection(session.peripheral)
    }

    private func applyScanState() {
        if isDemo {
            isScanning = wantsScanning
            return
        }
        guard let central, availability == .ready else {
            isScanning = false
            return
        }
        if wantsScanning && !central.isScanning {
            central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        } else if !wantsScanning && central.isScanning {
            central.stopScan()
        }
        isScanning = wantsScanning
    }

    private func publishSnapshot() {
        let now = Date()
        if isDemo {
            for id in store.keys {
                store[id]?.lastSeen = now
            }
        }
        store = store.filter { entry in
            now.timeIntervalSince(entry.value.lastSeen) < 90 || sessions[entry.key]?.isConnected == true
        }
        let snapshot = Array(store.values)
        if snapshot != devices {
            devices = snapshot
        }
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: availability = .ready
        case .poweredOff: availability = .poweredOff
        case .unauthorized: availability = .unauthorized
        case .unsupported: availability = .unsupported
        case .resetting: availability = .resetting
        default: availability = .unknown
        }
        if availability != .ready {
            isScanning = false
            for session in sessions.values {
                session.didDisconnect(error: nil)
            }
        }
        applyScanState()
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let id = peripheral.identifier
        peripherals[id] = peripheral
        rssiSamples.send((id, RSSI.intValue))
        if var existing = store[id] {
            existing.update(rssi: RSSI.intValue, advertisement: advertisementData, name: peripheral.name)
            store[id] = existing
        } else {
            store[id] = DiscoveredDevice(id: id, rssi: RSSI.intValue, advertisement: advertisementData, name: peripheral.name)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        sessions[peripheral.identifier]?.didConnect()
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        sessions[peripheral.identifier]?.markFailed(error?.localizedDescription ?? "Could not connect.")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        sessions[peripheral.identifier]?.didDisconnect(error: error)
    }
}
