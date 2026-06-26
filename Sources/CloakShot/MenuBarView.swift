import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: appState.shieldEnabled ? "shield.fill" : "shield")
                    .foregroundColor(appState.shieldEnabled ? .green : .secondary)
                Text("CloakShot")
                    .font(.headline)
                Spacer()
            }

            Toggle(appState.shieldEnabled ? "Shield ON" : "Shield OFF", isOn: Binding(
                get: { appState.shieldEnabled },
                set: { _ in appState.toggleShield() }
            ))
            .toggleStyle(.switch)

            Divider()

            Label("\(appState.config.allowedBundleIDs.count) apps allowed", systemImage: "app.badge")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label("\(appState.config.allowedFolders.count) folders allowed", systemImage: "folder")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label("\(appState.config.secretStrings.count) secrets protected", systemImage: "key")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            SettingsLink {
                Label("Settings...", systemImage: "gear")
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit CloakShot", systemImage: "xmark.circle")
            }
            .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 240)
    }
}
