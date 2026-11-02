import Foundation
import Combine
import CoreMotion

final class DirectionFinder: ObservableObject {
    static let bucketCount = 36

    @Published private(set) var heading: Double?
    @Published private(set) var strengths: [Double?] = Array(repeating: nil, count: DirectionFinder.bucketCount)
    @Published private(set) var bearing: Double?
    @Published private(set) var confidence: Double = 0
    @Published private(set) var coverage: Double = 0
    @Published private(set) var latestRSSI: Double?
    @Published private(set) var usesCompass = true
    @Published private(set) var history: [SignalSample] = []

    struct SignalSample: Identifiable {
        let id = UUID()
        let date: Date
        let rssi: Double
    }

    private var estimate: Double?
    private var variance: Double = 16
    private var lastHistory = Date.distantPast

    private let motion = CMMotionManager()
    private var values: [Double?] = Array(repeating: nil, count: DirectionFinder.bucketCount)
    private var stamps: [Date?] = Array(repeating: nil, count: DirectionFinder.bucketCount)
    private var subscription: AnyCancellable?
    private var demoTimer: Timer?

    func start(deviceID: UUID, manager: BluetoothManager) {
        reset()
        if DemoData.isEnabled {
            startDemo()
            return
        }
        subscription = manager.rssiSamples
            .filter { $0.0 == deviceID }
            .receive(on: RunLoop.main)
            .sink { [weak self] sample in self?.add(rssi: Double(sample.1)) }
        startMotion()
    }

    func stop() {
        subscription = nil
        motion.stopDeviceMotionUpdates()
        demoTimer?.invalidate()
        demoTimer = nil
    }

    var proximity: Double {
        guard let latestRSSI else { return 0 }
        return min(max((latestRSSI + 95) / 55, 0), 1)
    }

    func reset() {
        history = []
        values = Array(repeating: nil, count: Self.bucketCount)
        stamps = Array(repeating: nil, count: Self.bucketCount)
        strengths = values
        bearing = nil
        confidence = 0
        coverage = 0
    }

    var relativeAngle: Double? {
        guard let bearing, let heading else { return nil }
        var angle = bearing - heading
        while angle > 180 { angle -= 360 }
        while angle < -180 { angle += 360 }
        return angle
    }

    private func startMotion() {
        guard motion.isDeviceMotionAvailable else {
            heading = nil
            return
        }
        motion.deviceMotionUpdateInterval = 1.0 / 30.0
        let frames = CMMotionManager.availableAttitudeReferenceFrames()
        if frames.contains(.xMagneticNorthZVertical) {
            usesCompass = true
            motion.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: .main) { [weak self] data, _ in
                guard let data, data.heading >= 0 else { return }
                self?.heading = data.heading
            }
        } else {
            usesCompass = false
            motion.startDeviceMotionUpdates(using: .xArbitraryCorrectedZVertical, to: .main) { [weak self] data, _ in
                guard let data else { return }
                var degrees = -data.attitude.yaw * 180 / .pi
                if degrees < 0 { degrees += 360 }
                self?.heading = degrees
            }
        }
    }

    private func startDemo() {
        var simulated = 0.0
        heading = 0
        demoTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            simulated = (simulated + 3).truncatingRemainder(dividingBy: 360)
            self.heading = simulated
            let radians = (simulated - 40) * .pi / 180
            let noise = Double.random(in: -1.5...1.5)
            self.add(rssi: -66 + 11 * cos(radians) + noise)
        }
    }

    private func add(rssi: Double) {
        if let current = estimate {
            let predicted = variance + 0.6
            let gain = predicted / (predicted + 9)
            estimate = current + gain * (rssi - current)
            variance = (1 - gain) * predicted
        } else {
            estimate = rssi
            variance = 9
        }
        latestRSSI = estimate
        let now = Date()
        if now.timeIntervalSince(lastHistory) >= 0.25, let estimate {
            lastHistory = now
            history.append(SignalSample(date: now, rssi: estimate))
            history.removeAll { now.timeIntervalSince($0.date) > 60 }
        }
        guard let heading else { return }
        let index = Int(heading / (360.0 / Double(Self.bucketCount))) % Self.bucketCount
        if let old = values[index], let stamp = stamps[index], Date().timeIntervalSince(stamp) < 20 {
            values[index] = old * 0.6 + rssi * 0.4
        } else {
            values[index] = rssi
        }
        stamps[index] = Date()
        recompute()
    }

    private func recompute() {
        let now = Date()
        var fresh: [Double?] = values
        for index in 0..<Self.bucketCount {
            if let stamp = stamps[index], now.timeIntervalSince(stamp) > 30 {
                fresh[index] = nil
            }
        }
        let present = fresh.compactMap { $0 }
        coverage = Double(present.count) / Double(Self.bucketCount)
        guard let strongest = present.max(), let weakest = present.min() else {
            strengths = fresh
            bearing = nil
            return
        }
        let span = max(strongest - weakest, 1)
        strengths = fresh.map { value in value.map { ($0 - weakest) / span } }
        var x = 0.0
        var y = 0.0
        var total = 0.0
        for index in 0..<Self.bucketCount {
            guard let value = fresh[index] else { continue }
            let weight = pow(10, (value - strongest) / 6)
            let angle = (Double(index) + 0.5) * (360.0 / Double(Self.bucketCount)) * .pi / 180
            x += cos(angle) * weight
            y += sin(angle) * weight
            total += weight
        }
        guard total > 0, coverage >= 0.4 else {
            bearing = nil
            confidence = 0
            return
        }
        var degrees = atan2(y, x) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        bearing = degrees
        let concentration = sqrt(x * x + y * y) / total
        confidence = min(1, concentration * min(1, coverage / 0.75) * min(1, span / 6))
    }
}
