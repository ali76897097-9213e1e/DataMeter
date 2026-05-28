import AppKit
import Foundation

@MainActor
final class AppAppearanceSettings: ObservableObject {
    static let shared = AppAppearanceSettings()

    @Published var showDockIcon: Bool {
        didSet {
            UserDefaults.standard.set(showDockIcon, forKey: Self.showDockIconKey)
            applyActivationPolicy()
        }
    }

    private static let showDockIconKey = "ShowDockIcon"

    private init() {
        if UserDefaults.standard.object(forKey: Self.showDockIconKey) == nil {
            showDockIcon = true
        } else {
            showDockIcon = UserDefaults.standard.bool(forKey: Self.showDockIconKey)
        }
        applyActivationPolicy()
    }

    func applyActivationPolicy() {
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
    }
}
