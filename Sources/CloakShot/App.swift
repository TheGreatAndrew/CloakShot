import SwiftUI
import Shared
import ScreenShield
import FileShield
import TextRedactor

@main
struct CloakShotApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            Image(systemName: appState.shieldEnabled ? "shield.fill" : "shield")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(appState: appState)
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var config: CloakConfig {
        didSet { saveAndSync() }
    }
    @Published var shieldEnabled: Bool
    @Published var runningApps: [RunningApp] = []

    let screenShield: ScreenShield
    let fileShield: FileShield
    let textRedactor: TextRedactor
    let ruleEngine: AppRuleEngine

    init() {
        let config = CloakConfig.load()
        let ruleEngine = AppRuleEngine()
        ruleEngine.loadBundledRules()

        self.config = config
        self.shieldEnabled = config.shieldEnabled
        self.ruleEngine = ruleEngine
        self.screenShield = ScreenShield(config: config, ruleEngine: ruleEngine)
        self.fileShield = FileShield(config: config)
        self.textRedactor = TextRedactor(config: config)
    }

    func toggleShield() {
        shieldEnabled.toggle()
        config.shieldEnabled = shieldEnabled
    }

    func addApp(_ bundleID: String) {
        config.allowedBundleIDs.insert(bundleID)
    }

    func removeApp(_ bundleID: String) {
        config.allowedBundleIDs.remove(bundleID)
    }

    func addFolder(_ path: String) {
        if !config.allowedFolders.contains(path) {
            config.allowedFolders.append(path)
        }
    }

    func removeFolder(_ path: String) {
        config.allowedFolders.removeAll { $0 == path }
    }

    func addSecret(_ secret: String) {
        if !secret.isEmpty && !config.secretStrings.contains(secret) {
            config.secretStrings.append(secret)
        }
    }

    func removeSecret(_ secret: String) {
        config.secretStrings.removeAll { $0 == secret }
    }

    func refreshRunningApps() {
        Task {
            do {
                let apps = try await screenShield.listRunningApps()
                await MainActor.run {
                    self.runningApps = apps
                }
            } catch {
                // Screen capture permission not granted yet
            }
        }
    }

    private func saveAndSync() {
        try? config.save()
        screenShield.updateConfig(config)
        fileShield.updateConfig(config)
        textRedactor.updateConfig(config)
    }
}
