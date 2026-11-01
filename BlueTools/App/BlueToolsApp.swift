import SwiftUI

@main
struct BlueToolsApp: App {
    @StateObject private var bluetooth = BluetoothManager()
    @StateObject private var pins = PinStore()
    @StateObject private var updates = UpdateChecker()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(bluetooth)
                .environmentObject(pins)
                .environmentObject(updates)
                .onAppear(perform: prepareDemo)
        }
    }

    private func prepareDemo() {
        guard DemoData.isEnabled else { return }
        if !pins.isPinned(DemoData.keysID) {
            pins.toggle(DemoData.keysID)
        }
        pins.setNickname("Klucze", for: DemoData.keysID)
    }
}

struct RootView: View {
    enum Tab: Hashable {
        case nearby
        case settings
    }

    @EnvironmentObject private var updates: UpdateChecker
    @AppStorage(PrefKey.autoUpdates) private var autoUpdates = true
    @State private var tab: Tab = DemoData.screen == "settings" ? .settings : .nearby
    @State private var demoFinder = DemoData.screen == "finder"

    var body: some View {
        TabView(selection: $tab) {
            ScannerView()
                .tabItem { Label("W pobliżu", systemImage: "dot.radiowaves.left.and.right") }
                .tag(Tab.nearby)
            SettingsView()
                .tabItem { Label("Ustawienia", systemImage: "gearshape") }
                .badge(updates.available == nil ? 0 : 1)
                .tag(Tab.settings)
        }
        .onAppear {
            if !DemoData.isEnabled {
                updates.checkOnLaunch(enabled: autoUpdates)
            }
        }
        .sheet(item: $updates.presented) { info in
            UpdateSheet(info: info)
        }
        .sheet(isPresented: $demoFinder) {
            FinderView(deviceID: DemoData.keysID, title: "Klucze")
        }
    }
}
