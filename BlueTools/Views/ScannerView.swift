import SwiftUI
import UIKit

struct ScannerView: View {
    @EnvironmentObject private var bluetooth: BluetoothManager
    @EnvironmentObject private var pins: PinStore

    @AppStorage(PrefKey.hideUnnamed) private var hideUnnamed = false
    @AppStorage(PrefKey.minimumRSSI) private var minimumRSSI = -100.0
    @AppStorage(PrefKey.sortOrder) private var sortOrder = SortOrder.signal

    @State private var query = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                content
            }
            .navigationTitle("Nearby")
            .toolbar { toolbar }
            .navigationDestination(for: UUID.self) { id in
                DeviceDetailView(deviceID: id)
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
                icon: "hand.raised.fill",
                title: "No Bluetooth access",
                message: "BlueTools can't see anything without it. You can allow it in Settings.",
                actionTitle: "Open Settings",
                action: openSettings
            )
        case .unsupported:
            EmptyStateView(
                icon: "exclamationmark.triangle.fill",
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

        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                statusCard

                if !pinned.isEmpty {
                    group(title: "Pinned", devices: pinned)
                }

                if others.isEmpty {
                    Text(bluetooth.isScanning ? "Looking around… this usually takes a few seconds." : "Scanning is paused.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .glassCard()
                } else {
                    group(title: pinned.isEmpty ? "Devices" : "Everything else", devices: others)
                }

                if hiddenCount > 0 {
                    Text("\(hiddenCount) hidden by filters")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: all.map(\.id))
        }
        .scrollDismissesKeyboard(.immediately)
        .searchable(text: $query, prompt: "Name, maker, type or UUID")
        .refreshable { bluetooth.clear() }
    }

    private func group(title: String, devices: [DiscoveredDevice]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 6)
            GlassGroup(spacing: 10) {
                VStack(spacing: 10) {
                    ForEach(devices) { device in
                        NavigationLink(value: device.id) {
                            DeviceRow(device: device, nickname: pins.nickname(for: device.id), pinned: pins.isPinned(device.id))
                        }
                        .buttonStyle(.plain)
                        .contextMenu { menu(for: device) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func menu(for device: DiscoveredDevice) -> some View {
        Button {
            pins.toggle(device.id)
        } label: {
            Label(pins.isPinned(device.id) ? "Unpin" : "Pin", systemImage: pins.isPinned(device.id) ? "pin.slash" : "pin")
        }
        Button {
            UIPasteboard.general.string = device.id.uuidString
        } label: {
            Label("Copy identifier", systemImage: "doc.on.doc")
        }
    }

    private var statusCard: some View {
        HStack(spacing: 14) {
            PulseDot(active: bluetooth.isScanning)
            VStack(alignment: .leading, spacing: 2) {
                Text(bluetooth.isScanning ? "Scanning" : "Paused")
                    .font(.headline)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { bluetooth.wantsScanning.toggle() }
            } label: {
                Image(systemName: bluetooth.isScanning ? "pause.fill" : "play.fill")
                    .frame(width: 22, height: 22)
            }
            .glassButton()
        }
        .padding(16)
        .glassCard(tint: Color.mint1.opacity(0.12))
    }

    private var summary: String {
        let devices = bluetooth.devices
        let identified = devices.filter { $0.identity.kind != .unknown || $0.identity.model != nil }.count
        let word = devices.count == 1 ? "device" : "devices"
        return "\(devices.count) \(word) · \(identified) identified"
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Picker("Sort by", selection: $sortOrder) {
                    ForEach(SortOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                }
                Toggle("Hide unnamed", isOn: $hideUnnamed)
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
            }
        }
    }

    private var hiddenCount: Int {
        bluetooth.devices.count - filtered.count
    }

    private var filtered: [DiscoveredDevice] {
        let text = query.trimmingCharacters(in: .whitespaces).lowercased()
        let list = bluetooth.devices.filter { device in
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

struct DeviceRow: View {
    let device: DiscoveredDevice
    let nickname: String?
    let pinned: Bool

    var body: some View {
        let stale = device.isStale()
        HStack(spacing: 14) {
            Image(systemName: device.identity.kind.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(stale ? Color.secondary : Color.accentColor)
                .frame(width: 44, height: 44)
                .glassCircle(tint: Color.accentColor.opacity(stale ? 0.04 : 0.14))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(nickname ?? device.displayName)
                        .font(.body.weight(.semibold))
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

            VStack(alignment: .trailing, spacing: 4) {
                SignalBars(level: device.signalLevel, dimmed: stale)
                Text("\(device.rssi) dBm")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .glassCard(radius: 22, interactive: true)
        .opacity(stale ? 0.6 : 1)
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
