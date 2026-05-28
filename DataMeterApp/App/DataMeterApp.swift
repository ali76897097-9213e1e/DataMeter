import ServiceManagement
import SwiftUI

@main
struct DataMeterApp: App {
    @StateObject private var viewModel = UsageViewModel()
    @StateObject private var appearanceSettings = AppAppearanceSettings.shared

    init() {
        try? SMAppService.mainApp.register()
    }

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(viewModel)
                .environmentObject(appearanceSettings)
                .frame(minWidth: 720, minHeight: 460)
        }

        MenuBarExtra("DataMeter", systemImage: "antenna.radiowaves.left.and.right") {
            MenuBarRootView()
                .environmentObject(viewModel)
                .environmentObject(appearanceSettings)
                .frame(width: 280)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
