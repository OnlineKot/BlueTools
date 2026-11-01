import SwiftUI

@main
struct BlueToolsApp: App {
    @StateObject private var bluetooth = BluetoothManager()
    @StateObject private var pins = PinStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(bluetooth)
                .environmentObject(pins)
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            ScannerView()
                .tabItem { Label("W pobliżu", systemImage: "dot.radiowaves.left.and.right") }
            SettingsView()
                .tabItem { Label("Ustawienia", systemImage: "slider.horizontal.3") }
        }
    }
}
