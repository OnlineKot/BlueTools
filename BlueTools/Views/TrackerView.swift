import SwiftUI

struct TrackerView: View {
    @EnvironmentObject private var bluetooth: BluetoothManager
    @Environment(\.dismiss) private var dismiss
    @State private var finding: DiscoveredDevice?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(headline)
                            .font(.title3.weight(.semibold))
                        Text("BlueTools looks for AirTags and other Find My accessories, Galaxy SmartTags and Tiles. One that stays near you for more than \(Int(TrackerWatch.threshold / 60)) minutes while you move around is worth a look.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                let trackers = TrackerWatch.all(in: bluetooth.devices)
                if trackers.isEmpty {
                    Section {
                        Label("No trackers around right now", systemImage: "checkmark.shield")
                            .foregroundStyle(Color.mint1)
                    }
                } else {
                    Section("Seen around you") {
                        ForEach(trackers) { tracker in
                            HStack(spacing: 12) {
                                Image(systemName: tracker.identity.kind.symbol)
                                    .foregroundStyle(follows(tracker) ? Color.orange : Color.accentColor)
                                    .frame(width: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tracker.identity.model ?? tracker.displayName)
                                    Text("Near you for \(TrackerWatch.minutes(tracker)) min · \(tracker.distanceDescription)")
                                        .font(.caption)
                                        .foregroundStyle(follows(tracker) ? Color.orange : Color.secondary)
                                }
                                Spacer()
                                Button("Find") { finding = tracker }
                                    .glassButton()
                                    .controlSize(.small)
                            }
                        }
                    }
                }

                Section {
                    Text("Keep the app open while you walk or drive. If a tracker keeps showing up after you've changed places, use Find to locate it. Your iPhone also warns you about unknown AirTags on its own.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Tracker check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $finding) { tracker in
                FinderView(deviceID: tracker.id, title: tracker.identity.model ?? tracker.displayName)
            }
        }
    }

    private var headline: String {
        let count = TrackerWatch.following(in: bluetooth.devices).count
        if count == 0 { return "Nothing seems to be following you" }
        return count == 1 ? "One tracker has stayed with you" : "\(count) trackers have stayed with you"
    }

    private func follows(_ device: DiscoveredDevice) -> Bool {
        Date().timeIntervalSince(device.firstSeen) >= TrackerWatch.threshold
    }
}
