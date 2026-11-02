import SwiftUI
import UIKit

struct ScannerView: View {
    @EnvironmentObject private var bluetooth: BluetoothManager
    @EnvironmentObject private var pins: PinStore

    @AppStorage(PrefKey.hideUnnamed) private var hideUnnamed = false
    @AppStorage(PrefKey.minimumRSSI) private var minimumRSSI = -100.0
    @AppStorage(PrefKey.sortOrder) private var sortOrder = SortOrder.signal

    @State private var query = ""
    @State private var kindFilter: DeviceKind?
    @State private var showTrackers = false
    @State private var exportURL: URL?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Nearby")
                .toolbar { toolbar }
                .navigationDestination(for: UUID.self) { id in
                    DeviceDetailView(deviceID: id)
                }
                .sheet(isPresented: $showTrackers) {
                    TrackerView()
                }
                .sheet(item: $exportURL) { url in
                    ShareSheet(items: [url])
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch bluetooth.availability {
        case .poweredOff:
            EmptyStateView(
                icon: "antenna.radiowaves.left.and.right.slash",
                title: "Bluetooth is off",
                message: "Turn it on in Control Center or Settings, then come back."
            )
        case .unauthorized:
            EmptyStateView(
                icon: "hand.raised",
                title: "No Bluetooth access",
                message: "BlueTools can't see anything without it. You can allow it in Settings.",
                actionTitle: "Open Settings",
                action: openSettings
            )
        case .unsupported:
            EmptyStateView(
                icon: "exclamationmark.triangle",
                title: "Bluetooth LE not supported",
                message: "This device can't scan for Bluetooth LE."
            )
        case .unknown, .resetting:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready:
            deviceList
        }
    }

    private var deviceList: some View {
        let all = filtered
        let pinned = all.filter { pins.isPinned($0.id) }
        let others = all.filter { !pins.isPinned($0.id) }
        let following = TrackerWatch.following(in: bluetooth.devices)

        return List {
            if #available(iOS 26.0, *) {
            } else {
                Section {
                    ScanStatusRow()
                }
            }

            if !following.isEmpty {
                Section {
                    Button {
                        showTrackers = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.shield.fill")
                                .font(.title2)
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(following.count == 1 ? "A tracker is moving with you" : "\(following.count) trackers are moving with you")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("Seen for \(TrackerWatch.minutes(following[0])) min. Tap to check.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if !pinned.isEmpty {
                Section("Pinned") {
                    ForEach(pinned) { row(for: $0) }
                }
            }

            Section {
                if others.isEmpty {
                    Text(bluetooth.isScanning ? "Looking around… this usually takes a few seconds." : "Scanning is paused.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(others) { row(for: $0) }
                }
            } header: {
                Text(kindFilter.map { "\($0.label)s" } ?? (pinned.isEmpty ? "Devices" : "Everything else"))
            } footer: {
                if hiddenCount > 0 {
                    Text("\(hiddenCount) hidden by filters")
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $query, prompt: "Name, maker, type or UUID")
        .refreshable { bluetooth.clear() }
        .animation(.default, value: all.map(\.id))
    }

    private func row(for device: DiscoveredDevice) -> some View {
        NavigationLink(value: device.id) {
            DeviceRow(device: device, nickname: pins.nickname(for: device.id), pinned: pins.isPinned(device.id))
        }
        .swipeActions(edge: .leading) {
            Button {
                pins.toggle(device.id)
            } label: {
                Label(pins.isPinned(device.id) ? "Unpin" : "Pin", systemImage: pins.isPinned(device.id) ? "pin.slash" : "pin")
            }
            .tint(.orange)
        }
        .contextMenu {
            Button {
                pins.toggle(device.id)
            } label: {
                Label(pins.isPinned(device.id) ? "Unpin" : "Pin", systemImage: "pin")
            }
            Button {
                UIPasteboard.general.string = device.id.uuidString
            } label: {
                Label("Copy identifier", systemImage: "doc.on.doc")
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                showTrackers = true
            } label: {
                Image(systemName: "shield.lefthalf.filled")
            }
            .accessibilityLabel("Tracker check")
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Picker("Sort by", selection: $sortOrder) {
                    ForEach(SortOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                }
                Picker("Show", selection: $kindFilter) {
                    Text("All devices").tag(DeviceKind?.none)
                    ForEach(availableKinds, id: \.self) { kind in
                        Label(kind.label, systemImage: kind.symbol).tag(DeviceKind?.some(kind))
                    }
                }
                Toggle("Hide unnamed", isOn: $hideUnnamed)
                Divider()
                Button {
                    exportURL = ScanExport.write(bluetooth.devices, nicknames: pins.nicknames)
                } label: {
                    Label("Export as CSV", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: kindFilter == nil ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
            }
        }
    }

    private var availableKinds: [DeviceKind] {
        let kinds = Set(bluetooth.devices.map(\.identity.kind)).subtracting([.unknown])
        return kinds.sorted { $0.label < $1.label }
    }

    private var hiddenCount: Int {
        bluetooth.devices.count - filtered.count
    }

    private var filtered: [DiscoveredDevice] {
        let text = query.trimmingCharacters(in: .whitespaces).lowercased()
        let list = bluetooth.devices.filter { device in
            if let kindFilter, device.identity.kind != kindFilter { return false }
            if pins.isPinned(device.id) { return matches(device, text) }
            if hideUnnamed && !device.hasName && pins.nickname(for: device.id) == nil { return false }
            if device.smoothedRSSI < minimumRSSI { return false }
            return matches(device, text)
        }
        switch sortOrder {
        case .signal:
            return list.sorted { $0.smoothedRSSI > $1.smoothedRSSI }
        case .name:
            return list.sorted { title(of: $0).localizedCaseInsensitiveCompare(title(of: $1)) == .orderedAscending }
        case .recent:
            return list.sorted { $0.firstSeen > $1.firstSeen }
        }
    }

    private func title(of device: DiscoveredDevice) -> String {
        pins.nickname(for: device.id) ?? device.displayName
    }

    private func matches(_ device: DiscoveredDevice, _ text: String) -> Bool {
        guard !text.isEmpty else { return true }
        let haystack = [
            title(of: device),
            device.name ?? "",
            device.identity.model ?? "",
            device.identity.kind.label,
            device.companyName ?? "",
            device.id.uuidString
        ].joined(separator: " ").lowercased()
        return haystack.contains(text)
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

struct ScanStatusRow: View {
    @EnvironmentObject private var bluetooth: BluetoothManager

    var body: some View {
        HStack(spacing: 10) {
            PulseDot(active: bluetooth.isScanning)
            VStack(alignment: .leading, spacing: 1) {
                Text(bluetooth.isScanning ? "Scanning" : "Paused")
                    .font(.subheadline.weight(.semibold))
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                bluetooth.wantsScanning.toggle()
            } label: {
                Image(systemName: bluetooth.isScanning ? "pause.fill" : "play.fill")
            }
            .glassButton()
        }
        .padding(.horizontal, 4)
    }

    private var summary: String {
        let devices = bluetooth.devices
        let identified = devices.filter { $0.identity.kind != .unknown || $0.identity.model != nil }.count
        return "\(devices.count) \(devices.count == 1 ? "device" : "devices") · \(identified) identified"
    }
}

struct DeviceRow: View {
    let device: DiscoveredDevice
    let nickname: String?
    let pinned: Bool

    var body: some View {
        let stale = device.isStale()
        HStack(spacing: 12) {
            Image(systemName: device.identity.kind.symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(stale ? Color.secondary : Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(nickname ?? device.displayName)
                        .foregroundStyle(device.hasName || nickname != nil ? Color.primary : Color.secondary)
                        .lineLimit(1)
                    if pinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                SignalBars(level: device.signalLevel, dimmed: stale)
                Text("\(device.rssi)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .opacity(stale ? 0.55 : 1)
    }

    private var details: String {
        var parts: [String] = []
        if let model = device.identity.model, model != (nickname ?? device.displayName) {
            parts.append(model)
        } else if let company = device.companyName {
            parts.append(company)
        } else if device.identity.kind != .unknown {
            parts.append(device.identity.kind.label)
        }
        parts.append(device.isStale() ? device.lastSeen.shortAgo : device.distanceDescription)
        return parts.joined(separator: " · ")
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}
