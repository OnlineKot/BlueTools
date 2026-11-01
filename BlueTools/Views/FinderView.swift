import SwiftUI
import UIKit

struct FinderView: View {
    @EnvironmentObject private var bluetooth: BluetoothManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PrefKey.haptics) private var haptics = true

    let deviceID: UUID
    let title: String

    @State private var previous: Double?
    @State private var trend: Trend = .steady
    @State private var wasScanning = true

    enum Trend {
        case warmer
        case colder
        case steady
    }

    private var device: DiscoveredDevice? {
        bluetooth.devices.first { $0.id == deviceID }
    }

    private var strength: Double {
        guard let rssi = device?.smoothedRSSI else { return 0 }
        return min(max((rssi + 100) / 60, 0), 1)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 2)
                        .frame(width: 260, height: 260)
                    Circle()
                        .fill(ringColor.opacity(0.18))
                        .frame(width: 60 + 200 * strength, height: 60 + 200 * strength)
                    Circle()
                        .fill(ringColor)
                        .frame(width: 40 + 80 * strength, height: 40 + 80 * strength)
                        .shadow(color: ringColor.opacity(0.5), radius: 18)
                    Text(device.map { "\(Int($0.smoothedRSSI.rounded()))" } ?? "?")
                        .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: strength)

                VStack(spacing: 6) {
                    Text(headline)
                        .font(.title.weight(.bold))
                        .contentTransition(.opacity)
                    Text(subline)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .animation(.easeInOut, value: headline)

                Spacer()

                Text("Wynik to szacunek. Ściany, ciało i inne urządzenia potrafią mocno namieszać, więc patrz raczej na to, czy rośnie, niż na same metry.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zamknij") { dismiss() }
                }
            }
        }
        .onAppear {
            wasScanning = bluetooth.wantsScanning
            bluetooth.wantsScanning = true
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            bluetooth.wantsScanning = wasScanning
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: device?.smoothedRSSI) { value in
            react(to: value)
        }
    }

    private var ringColor: Color {
        if strength >= 0.75 { return .green }
        if strength >= 0.5 { return .mint }
        if strength >= 0.3 { return .orange }
        return .red
    }

    private var headline: String {
        guard let device else { return "Nie widzę go" }
        if device.isStale() { return "Zgubiłem sygnał" }
        switch trend {
        case .warmer: return "Cieplej"
        case .colder: return "Zimniej"
        case .steady: return device.distanceDescription.capitalizedFirst
        }
    }

    private var subline: String {
        guard let device else { return "Podejdź bliżej albo upewnij się, że urządzenie jest włączone." }
        if device.isStale() { return "Ostatni sygnał \(device.lastSeen.shortAgo)." }
        return "Chodź powoli i obracaj się. Im większe koło, tym bliżej."
    }

    private func react(to value: Double?) {
        guard let value else { return }
        let last = previous
        previous = value
        guard let last else { return }
        let delta = value - last
        let newTrend: Trend
        if delta > 1.5 {
            newTrend = .warmer
        } else if delta < -1.5 {
            newTrend = .colder
        } else {
            newTrend = .steady
        }
        if newTrend != trend {
            trend = newTrend
            if haptics && newTrend == .warmer {
                UIImpactFeedbackGenerator(style: strength > 0.7 ? .heavy : .medium).impactOccurred()
            }
        }
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
