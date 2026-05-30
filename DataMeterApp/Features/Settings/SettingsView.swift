import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Environment(\.appearsActive) private var appearsActive
    @StateObject private var appearanceSettings = AppAppearanceSettings.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchAtLoginError: String?

    var body: some View {
        Form {
            Section("Tracking") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .accessibilityHint("Starts DataMeter automatically when you log in")
                    .onChange(of: launchAtLogin) { _, newValue in
                        updateLaunchAtLogin(newValue)
                    }
                Text("Recommended so daily and monthly totals keep accumulating automatically.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }

            Section("Appearance") {
                Toggle("Show Dock icon", isOn: $appearanceSettings.showDockIcon)
                    .accessibilityHint("Shows or hides DataMeter in the Dock")
                Text("Turn this off to keep DataMeter as a quiet menu bar utility.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 440)
        .onAppear {
            refreshLaunchAtLogin()
        }
        .onChange(of: appearsActive) { _, isActive in
            if isActive { refreshLaunchAtLogin() }
        }
    }

    private func refreshLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
            refreshLaunchAtLogin()
        } catch {
            launchAtLoginError = error.localizedDescription
            refreshLaunchAtLogin()
        }
    }
}
