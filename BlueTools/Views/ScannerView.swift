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
            content
                .navigationTitle("W pobliżu")
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
                title: "Bluetooth jest wyłączony",
                message: "Włącz go w Centrum sterowania albo w Ustawieniach i wróć tutaj."
            )
        case .unauthorized:
            EmptyStateView(
                icon: "hand.raised",
                title: "Brak dostępu do Bluetooth",
                message: "Bez tej zgody nie zobaczę żadnego urządzenia. Możesz ją dać w Ustawieniach systemu.",
                actionTitle: "Otwórz Ustawienia",
                action: openSettings
            )
        case .unsupported:
            EmptyStateView(
                icon: "exclamationmark.triangle",
                title: "To urządzenie nie obsługuje BLE",
                message: "Niestety tutaj nic nie zdziałam."
            )
        case .unknown, .resetting:
            ProgressView("Chwilka…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready:
            deviceList
        }
    }

    private var deviceList: some View {
        let all = filtered
        let pinned = all.filter { pins.isPinned($0.id) }
        let others = all.filter { !pins.isPinned($0.id) }

        return List {
            Section {
                statusRow
            }

            if !pinned.isEmpty {
                Section("Przypięte") {
                    ForEach(pinned) { row(for: $0) }
                }
            }

            Section {
                if others.isEmpty {
                    Text(bluetooth.isScanning ? "Szukam… zwykle trwa to kilka sekund." : "Skanowanie jest wstrzymane.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                        .padding(.vertical, 8)
                } else {
                    ForEach(others) { row(for: $0) }
                }
            } header: {
                Text(pinned.isEmpty ? "Urządzenia" : "Pozostałe")
            } footer: {
                if hiddenCount > 0 {
                    Text("Ukryte przez filtry: \(hiddenCount)")
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $query, prompt: "Nazwa, producent lub UUID")
        .refreshable {
            bluetooth.clear()
        }
        .animation(.default, value: all.map(\.id))
    }

    private var statusRow: some View {
        HStack(spacing: 12) {
            PulseDot(active: bluetooth.isScanning)
            VStack(alignment: .leading, spacing: 2) {
                Text(bluetooth.isScanning ? "Skanuję" : "Wstrzymane")
                    .font(.subheadline.weight(.semibold))
                Text("Widzę \(bluetooth.devices.count) \(deviceWord(bluetooth.devices.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(bluetooth.isScanning ? "Pauza" : "Wznów") {
                bluetooth.wantsScanning.toggle()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 2)
    }

    private func row(for device: DiscoveredDevice) -> some View {
        NavigationLink(value: device.id) {
            DeviceRow(device: device, nickname: pins.nickname(for: device.id), pinned: pins.isPinned(device.id))
        }
        .swipeActions(edge: .leading) {
            Button {
                pins.toggle(device.id)
            } label: {
                if pins.isPinned(device.id) {
                    Label("Odepnij", systemImage: "pin.slash")
                } else {
                    Label("Przypnij", systemImage: "pin")
                }
            }
            .tint(.orange)
        }
        .contextMenu {
            Button {
                pins.toggle(device.id)
            } label: {
                Label(pins.isPinned(device.id) ? "Odepnij" : "Przypnij", systemImage: "pin")
            }
            Button {
                UIPasteboard.general.string = device.id.uuidString
            } label: {
                Label("Kopiuj identyfikator", systemImage: "doc.on.doc")
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Picker("Sortuj", selection: $sortOrder) {
                    ForEach(SortOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                }
                Toggle("Ukryj bez nazwy", isOn: $hideUnnamed)
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
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
            device.companyName ?? "",
            device.id.uuidString
        ].joined(separator: " ").lowercased()
        return haystack.contains(text)
    }

    private func deviceWord(_ count: Int) -> String {
        if count == 1 { return "urządzenie" }
        let lastTwo = count % 100
        let last = count % 10
        if (2...4).contains(last) && !(12...14).contains(lastTwo) { return "urządzenia" }
        return "urządzeń"
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
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(stale ? 0.06 : 0.14))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(stale ? Color.secondary : Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(nickname ?? device.displayName)
                        .font(.body.weight(.medium))
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
        .padding(.vertical, 2)
        .opacity(stale ? 0.6 : 1)
    }

    private var details: String {
        var parts: [String] = []
        if let company = device.companyName, device.hasName || nickname != nil {
            parts.append(company)
        }
        parts.append(device.isStale() ? device.lastSeen.shortAgo : device.distanceDescription)
        if !device.isConnectable {
            parts.append("tylko rozgłasza")
        }
        return parts.joined(separator: " · ")
    }

    private var icon: String {
        let name = (nickname ?? device.name ?? "").lowercased()
        if name.contains("airpods") || name.contains("buds") || name.contains("headphone") || name.contains("słuch") { return "headphones" }
        if name.contains("watch") || name.contains("band") || name.contains("mi smart") { return "applewatch" }
        if name.contains("keyboard") || name.contains("klawiat") || name.contains("keys") { return "keyboard" }
        if name.contains("ruuvi") || name.contains("thermo") || name.contains("termo") { return "thermometer.medium" }
        if name.contains("mouse") || name.contains("mysz") { return "computermouse" }
        if name.contains("tv") { return "tv" }
        if name.contains("speaker") || name.contains("jbl") || name.contains("sonos") { return "hifispeaker" }
        if name.contains("iphone") || name.contains("phone") { return "iphone" }
        if name.contains("mac") || name.contains("laptop") { return "laptopcomputer" }
        if name.contains("tag") || name.contains("tile") { return "tag" }
        if name.contains("bulb") || name.contains("light") || name.contains("lamp") { return "lightbulb" }
        if device.companyID == 0x004C { return "apple.logo" }
        return "wave.3.right"
    }
}
