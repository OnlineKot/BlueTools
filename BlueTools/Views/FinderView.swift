import SwiftUI
import UIKit
import Charts
import AudioToolbox

struct FinderView: View {
    @EnvironmentObject private var bluetooth: BluetoothManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PrefKey.haptics) private var haptics = true
    @AppStorage(PrefKey.finderSound) private var sound = true
    @StateObject private var finder = DirectionFinder()

    let deviceID: UUID
    let title: String

    @State private var wasScanning = true
    @State private var wasFacing = false
    @State private var connectedForFinding = false

    private var device: DiscoveredDevice? {
        bluetooth.devices.first { $0.id == deviceID }
    }

    private var session: PeripheralSession? {
        DemoData.isEnabled ? nil : bluetooth.session(for: deviceID)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    headline
                    dial
                        .padding(.horizontal, 8)
                    chart
                    sweepInfo
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 110)
            }
            .background(Color(.systemGroupedBackground))
            .overlay(alignment: .bottom) { controls }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .onAppear(perform: begin)
        .onDisappear(perform: end)
        .onChange(of: facing) { now in
            if now && !wasFacing && haptics {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            wasFacing = now
        }
        .task {
            await geiger()
        }
    }

    private func begin() {
        wasScanning = bluetooth.wantsScanning
        bluetooth.wantsScanning = true
        finder.start(deviceID: deviceID, manager: bluetooth)
        UIApplication.shared.isIdleTimerDisabled = true
        if let session, device?.isConnectable == true {
            session.setRSSIInterval(0.25)
            if !session.isConnected {
                connectedForFinding = true
                session.connect()
            }
        }
    }

    private func end() {
        finder.stop()
        bluetooth.wantsScanning = wasScanning
        UIApplication.shared.isIdleTimerDisabled = false
        session?.setRSSIInterval(1.0)
        if connectedForFinding {
            session?.disconnect()
        }
    }

    private func geiger() async {
        while !Task.isCancelled {
            let closeness = finder.proximity
            let interval = 1.4 - 1.25 * closeness
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            guard finder.latestRSSI != nil else { continue }
            if sound { AudioServicesPlaySystemSound(1104) }
            if haptics { UIImpactFeedbackGenerator(style: closeness > 0.7 ? .heavy : .light).impactOccurred() }
        }
    }

    private var facing: Bool {
        guard let angle = finder.relativeAngle, finder.confidence > 0.35 else { return false }
        return abs(angle) < 15
    }

    private var headline: some View {
        VStack(spacing: 4) {
            Text(primaryText)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .monospacedDigit()
            Text(secondaryText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var primaryText: String {
        if facing { return "Straight ahead" }
        if let angle = finder.relativeAngle, finder.confidence > 0.2 {
            let amount = Int(abs(angle).rounded())
            if amount > 150 { return "Behind you" }
            return "\(amount)° \(angle > 0 ? "right" : "left")"
        }
        return zone
    }

    private var zone: String {
        let closeness = finder.proximity
        if finder.latestRSSI == nil { return device == nil ? "Out of range" : "Listening…" }
        if closeness > 0.82 { return "Right here" }
        if closeness > 0.6 { return "Very close" }
        if closeness > 0.38 { return "Nearby" }
        return "Far away"
    }

    private var secondaryText: String {
        var parts: [String] = []
        if facing || finder.relativeAngle != nil { parts.append(zone) }
        if let device { parts.append(device.distanceDescription) }
        if let rssi = finder.latestRSSI { parts.append("\(Int(rssi.rounded())) dBm") }
        if session?.isConnected == true { parts.append("fast mode") }
        return parts.joined(separator: " · ")
    }

    private var dial: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let rotation = -(finder.heading ?? 0)
            ZStack {
                Circle()
                    .fill(Color(.secondarySystemGroupedBackground))

                ForEach(0..<DirectionFinder.bucketCount, id: \.self) { index in
                    let strength = finder.strengths[index]
                    Capsule()
                        .fill(strength.map { barColor($0) } ?? Color.secondary.opacity(0.15))
                        .frame(width: 5, height: 8 + CGFloat(strength ?? 0) * size * 0.12)
                        .offset(y: -size * 0.40)
                        .rotationEffect(.degrees(Double(index) * 10 + 5 + rotation))
                }

                Text("N")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .offset(y: -size * 0.29)
                    .rotationEffect(.degrees(rotation))
                    .opacity(finder.usesCompass ? 1 : 0)

                Circle()
                    .fill(Color.mint1.opacity(0.10 + finder.proximity * 0.25))
                    .frame(width: size * (0.22 + finder.proximity * 0.26), height: size * (0.22 + finder.proximity * 0.26))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: finder.proximity)

                if let angle = finder.relativeAngle, finder.confidence > 0.2 {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: size * 0.11, weight: .bold))
                        .foregroundStyle(facing ? Color.mint1 : Color.accentColor)
                        .offset(y: -size * 0.21)
                        .rotationEffect(.degrees(angle))
                        .opacity(0.4 + finder.confidence * 0.6)
                        .animation(.interpolatingSpring(stiffness: 120, damping: 18), value: angle)
                }

                Text(finder.latestRSSI.map { "\(Int($0.rounded()))" } ?? "…")
                    .font(.system(size: size * 0.09, weight: .semibold, design: .rounded).monospacedDigit())
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func barColor(_ strength: Double) -> Color {
        if strength > 0.75 { return .mint1 }
        if strength > 0.45 { return Color.accentColor }
        return Color.accentColor.opacity(0.4)
    }

    private var chart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Signal, last minute")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Chart(finder.history) { sample in
                AreaMark(x: .value("Time", sample.date), yStart: .value("Floor", -100), yEnd: .value("RSSI", sample.rssi))
                    .foregroundStyle(Color.mint1.opacity(0.15))
                LineMark(x: .value("Time", sample.date), y: .value("RSSI", sample.rssi))
                    .foregroundStyle(Color.mint1)
                    .interpolationMethod(.monotone)
            }
            .chartYScale(domain: -100 ... -30)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: [-90, -70, -50]) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 110)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var sweepInfo: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                meter("Turned", finder.coverage, Color.mint1)
                meter("Confidence", finder.confidence, Color.accentColor)
            }
            Text(finder.heading == nil
                 ? "This device has no compass, so use the number and the ticking instead."
                 : "Hold the phone in front of you and turn slowly in a full circle. Your body blocks the signal behind you, so the arrow points to where it was strongest. Walk that way and turn again.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func meter(_ label: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            ProgressView(value: value)
                .tint(color)
        }
    }

    private var controls: some View {
        GlassGroup(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    sound.toggle()
                } label: {
                    Image(systemName: sound ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .frame(width: 24, height: 24)
                }
                .glassButton()
                .accessibilityLabel(sound ? "Mute ticking" : "Unmute ticking")

                if let session {
                    RingButton(session: session)
                }

                Button {
                    finder.reset()
                } label: {
                    Label("New lap", systemImage: "arrow.counterclockwise")
                }
                .glassButton()
            }
            .controlSize(.large)
        }
        .padding(.bottom, 12)
    }
}

private struct RingButton: View {
    @ObservedObject var session: PeripheralSession

    private var ring: DeviceCommand? {
        CommandLibrary.all.first { $0.id == "ring-high" && $0.isAvailable(in: session) }
    }

    var body: some View {
        if let ring {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                session.run(ring)
            } label: {
                Label("Play sound", systemImage: "speaker.wave.3.fill")
            }
            .glassButton(prominent: true)
        }
    }
}
