import SwiftUI

@main
struct BlueToolsApp: App {
    @StateObject private var bluetooth = BluetoothManager()
    @StateObject private var pins = PinStore()
    @StateObject private var updates = UpdateChecker()
    @StateObject private var customCommands = CustomCommandStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(bluetooth)
                .environmentObject(pins)
                .environmentObject(updates)
                .environmentObject(customCommands)
                .onAppear(perform: prepareDemo)
        }
    }

    private func prepareDemo() {
        guard DemoData.isEnabled else { return }
        if !pins.isPinned(DemoData.keysID) {
            pins.toggle(DemoData.keysID)
        }
        pins.setNickname("Keys", for: DemoData.keysID)
    }
}

struct RootView: View {
    enum Tab: Hashable {
        case nearby
        case settings
    }

    @EnvironmentObject private var updates: UpdateChecker
    @EnvironmentObject private var bluetooth: BluetoothManager
    @AppStorage(PrefKey.autoUpdates) private var autoUpdates = true
    @State private var tab: Tab = DemoData.screen == "settings" ? .settings : .nearby
    @State private var demoFinder = DemoData.screen == "finder"

    var body: some View {
        TabView(selection: $tab) {
            ScannerView()
                .tabItem { Label("Nearby", systemImage: "dot.radiowaves.left.and.right") }
                .tag(Tab.nearby)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .badge(updates.available == nil ? 0 : 1)
                .tag(Tab.settings)
        }
        .modifier(GlassTabBar())
        .onAppear {
            if !DemoData.isEnabled {
                updates.checkOnLaunch(enabled: autoUpdates)
            }
        }
        .sheet(item: $updates.presented) { info in
            UpdateSheet(info: info)
        }
        .sheet(isPresented: $demoFinder) {
            FinderView(deviceID: DemoData.keysID, title: "Keys")
        }
    }
}

private struct GlassTabBar: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
    }
}
