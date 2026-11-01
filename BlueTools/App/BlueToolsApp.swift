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
    @Environment(\.scenePhase) private var scenePhase
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
        .overlay(alignment: .top) {
            if let countdown = updates.countdown {
                UpdateCountdownBanner(countdown: countdown)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: updates.countdown)
        .onChange(of: scenePhase) { phase in
            if phase == .active && !DemoData.isEnabled {
                updates.checkOnLaunch(enabled: autoUpdates)
            }
        }
        .onAppear {
            if !DemoData.isEnabled {
                updates.checkOnLaunch(enabled: autoUpdates)
            }
        }
        .alert(
            "\(updates.missingInstaller?.title ?? "That app") isn't installed",
            isPresented: Binding(get: { updates.missingInstaller != nil }, set: { if !$0 { updates.missingInstaller = nil } })
        ) {
            Button("Download IPA instead") {
                updates.missingInstaller = nil
                ExternalApp.open(updates.available?.ipa ?? AppLinks.latestIPA)
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Pick another installer, or grab the IPA in Safari.")
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
