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
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var updates: UpdateChecker
    @AppStorage(PrefKey.autoUpdates) private var autoUpdates = true

    var body: some View {
        tabs
            .onAppear { updates.checkOnLaunch(enabled: autoUpdates) }
            .sheet(item: $updates.presented) { info in
                UpdateSheet(info: info)
            }
    }

    private var tabs: some View {
        TabView {
            ScannerView()
                .tabItem { Label("W pobliżu", systemImage: "dot.radiowaves.left.and.right") }
            SettingsView()
                .tabItem { Label("Ustawienia", systemImage: "slider.horizontal.3") }
                .badge(updates.available == nil ? 0 : 1)
        }
    }
}
