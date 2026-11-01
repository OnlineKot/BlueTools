import SwiftUI
import UIKit

struct FinderView: View {
    @EnvironmentObject private var bluetooth: BluetoothManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PrefKey.haptics) private var haptics = true
    @StateObject private var finder = DirectionFinder()

    let deviceID: UUID
    let title: String

    @State private var wasScanning = true
    @State private var wasFacing = false

    private var device: DiscoveredDevice? {
        bluetooth.devices.first { $0.id == deviceID }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 24) {
                    headline
                    dial
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
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
        .onAppear {
            wasScanning = bluetooth.wantsScanning
            bluetooth.wantsScanning = true
            finder.start(deviceID: deviceID, manager: bluetooth)
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            finder.stop()
            bluetooth.wantsScanning = wasScanning
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: facing) { now in
            if now && !wasFacing && haptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            wasFacing = now
        }
    }

    private var facing: Bool {
        guard let angle = finder.relativeAngle, finder.confidence > 0.35 else { return false }
        return abs(angle) < 15
    }

    private var headline: some View {
        VStack(spacing: 6) {
            Text(primaryText)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .contentTransition(.opacity)
                .animation(.easeInOut, value: primaryText)
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
            let side = angle > 0 ? "right" : "left"
            let amount = Int(abs(angle).rounded())
            if amount > 150 { return "Behind you" }
            return "\(amount)° \(side)"
        }
        guard let device else { return "Out of range" }
        return device.distanceDescription.prefix(1).uppercased() + device.distanceDescription.dropFirst()
    }

    private var secondaryText: String {
        if finder.heading == nil { return "No compass on this device. Use the signal strength instead." }
        if finder.coverage < 0.4 { return "Hold your phone in front of you and turn slowly in a full circle." }
        if let device { return "\(device.distanceDescription) · signal \(Int(device.smoothedRSSI)) dBm" }
        return "Keep turning, the arrow gets better with every lap."
    }

    private var dial: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let rotation = -(finder.heading ?? 0)
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .glassCircle(tint: Color.mint1.opacity(0.10))

                ForEach(0..<DirectionFinder.bucketCount, id: \.self) { index in
                    let strength = finder.strengths[index]
                    Capsule()
                        .fill(strength.map { barColor($0) } ?? Color.secondary.opacity(0.18))
                        .frame(width: 6, height: 10 + CGFloat(strength ?? 0) * size * 0.11)
                        .offset(y: -size * 0.40)
                        .rotationEffect(.degrees(Double(index) * 10 + 5 + rotation))
                }

                Text("N")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .offset(y: -size * 0.30)
                    .rotationEffect(.degrees(rotation))
                    .opacity(finder.usesCompass ? 1 : 0)

                arrow(size: size)

                VStack(spacing: 0) {
                    Text(finder.latestRSSI.map { "\(Int($0.rounded()))" } ?? "…")
                        .font(.system(size: size * 0.10, weight: .bold, design: .rounded).monospacedDigit())
                    Text("dBm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: size * 0.30, height: size * 0.30)
                .glassCircle()
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.interpolatingSpring(stiffness: 120, damping: 18), value: finder.relativeAngle ?? 0)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func arrow(size: CGFloat) -> some View {
        if let angle = finder.relativeAngle, finder.confidence > 0.2 {
            Image(systemName: "location.north.fill")
                .font(.system(size: size * 0.14, weight: .bold))
                .foregroundStyle(facing ? Color.mint1 : Color.accentColor)
                .frame(width: size * 0.22, height: size * 0.22)
                .glassCircle(tint: (facing ? Color.mint1 : Color.accentColor).opacity(0.25))
                .offset(y: -size * 0.23)
                .rotationEffect(.degrees(angle))
                .opacity(0.4 + finder.confidence * 0.6)
                .transition(.scale.combined(with: .opacity))
        }
    }

    private func barColor(_ strength: Double) -> Color {
        if strength > 0.75 { return .mint1 }
        if strength > 0.45 { return Color.accentColor }
        return Color.accentColor.opacity(0.45)
    }

    private var footer: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scan coverage")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ProgressView(value: finder.coverage)
                        .tint(Color.mint1)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Confidence")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ProgressView(value: finder.confidence)
                        .tint(Color.accentColor)
                }
            }
            HStack(spacing: 10) {
                Text("Your body blocks the signal behind you, so the strongest reading points toward the device. Walk that way and do another lap.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    finder.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .glassButton()
            }
        }
        .padding(16)
        .glassCard(radius: 26)
    }
}
