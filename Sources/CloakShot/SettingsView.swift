import SwiftUI
import Shared
import ScreenShield

struct SettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        TabView {
            AppsTab(appState: appState)
                .tabItem { Label("Apps", systemImage: "app.badge") }
            FoldersTab(appState: appState)
                .tabItem { Label("Folders", systemImage: "folder") }
            SecretsTab(appState: appState)
                .tabItem { Label("Secrets", systemImage: "key") }
            MCPTab()
                .tabItem { Label("MCP", systemImage: "link") }
        }
        .frame(width: 520, height: 420)
    }
}

// MARK: - Apps Tab

struct AppsTab: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Allowed Apps")
                .font(.headline)
            Text("AI agents can only see these apps. Everything else is hidden.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            List {
                Section("Running Apps") {
                    ForEach(appState.runningApps, id: \.bundleID) { app in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(app.name)
                                Text(app.bundleID)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if app.isAlwaysBlocked {
                                Text("Always blocked")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            } else {
                                Toggle("", isOn: Binding(
                                    get: { appState.config.allowedBundleIDs.contains(app.bundleID) },
                                    set: { enabled in
                                        if enabled {
                                            appState.addApp(app.bundleID)
                                        } else {
                                            appState.removeApp(app.bundleID)
                                        }
                                    }
                                ))
                                .toggleStyle(.switch)
                                .labelsHidden()
                            }
                        }
                    }
                }

                if !manuallyAddedApps.isEmpty {
                    Section("Manually Added") {
                        ForEach(manuallyAddedApps, id: \.self) { bundleID in
                            HStack {
                                Text(bundleID)
                                Spacer()
                                Button(role: .destructive) {
                                    appState.removeApp(bundleID)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
            }

            HStack {
                Button("Refresh Apps") {
                    appState.refreshRunningApps()
                }

                Spacer()

                Button("Add Bundle ID...") {
                    addBundleID()
                }
            }
        }
        .padding()
        .onAppear {
            appState.refreshRunningApps()
        }
    }

    private var manuallyAddedApps: [String] {
        let runningIDs = Set(appState.runningApps.map(\.bundleID))
        return appState.config.allowedBundleIDs.filter { !runningIDs.contains($0) }.sorted()
    }

    private func addBundleID() {
        let alert = NSAlert()
        alert.messageText = "Add App by Bundle ID"
        alert.informativeText = "Run in Terminal: osascript -e 'id of app \"AppName\"'"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.placeholderString = "com.example.app"
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn {
            let value = input.stringValue.trimmingCharacters(in: .whitespaces)
            if !value.isEmpty {
                appState.addApp(value)
            }
        }
    }
}

// MARK: - Folders Tab

struct FoldersTab: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Allowed Folders")
                .font(.headline)
            Text("AI agents can only read files from these folders. Everything else is blocked.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            List {
                Section("Your Folders") {
                    ForEach(appState.config.allowedFolders, id: \.self) { folder in
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(.blue)
                            Text(folder)
                            Spacer()
                            Button(role: .destructive) {
                                appState.removeFolder(folder)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    if appState.config.allowedFolders.isEmpty {
                        Text("No folders allowed. AI agents cannot read any files.")
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }

                Section("Always Blocked") {
                    ForEach(CloakConstants.alwaysBlockedPaths, id: \.self) { path in
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.red)
                            Text("~\(path)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Add Folder...") {
                    addFolder()
                }
            }
        }
        .padding()
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder AI agents are allowed to read"

        if panel.runModal() == .OK, let url = panel.url {
            appState.addFolder(url.path)
        }
    }
}

// MARK: - Secrets Tab

struct SecretsTab: View {
    @ObservedObject var appState: AppState
    @State private var newSecret = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Secret Strings")
                .font(.headline)
            Text("If any of these strings appear on screen or in files, they will be redacted before the AI sees them.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            List {
                ForEach(appState.config.secretStrings, id: \.self) { secret in
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundStyle(.orange)
                        Text(String(repeating: "*", count: min(secret.count, 20)))
                        Spacer()
                        Button(role: .destructive) {
                            appState.removeSecret(secret)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                if appState.config.secretStrings.isEmpty {
                    Text("No secrets configured. Add strings like your address, account numbers, etc.")
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }

            HStack {
                SecureField("Add a secret string...", text: $newSecret)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addSecret() }

                Button("Add") { addSecret() }
                    .disabled(newSecret.isEmpty)
            }
        }
        .padding()
    }

    private func addSecret() {
        appState.addSecret(newSecret)
        newSecret = ""
    }
}

// MARK: - MCP Tab

struct MCPTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Agent Integration")
                .font(.headline)
            Text("Add CloakShot as an MCP server in your AI desktop agent to filter screenshots and file reads.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            GroupBox("Setup") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Open your AI agent's MCP config file")
                    Text("2. Add CloakShot as a server:")

                    let configSnippet = """
                    {
                      "mcpServers": {
                        "cloakshot": {
                          "command": "\(mcpBinaryPath)"
                        }
                      }
                    }
                    """

                    Text(configSnippet)
                        .font(.system(.caption, design: .monospaced))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary)
                        .cornerRadius(6)
                        .textSelection(.enabled)

                    Text("3. Restart your AI agent")
                    Text("4. (Recommended) Revoke the AI agent's screen recording permission in System Settings > Privacy & Security. CloakShot will handle screenshots instead.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(4)
            }

            GroupBox("Available Tools") {
                VStack(alignment: .leading, spacing: 4) {
                    Label("cloakshot_screenshot - filtered screen capture", systemImage: "camera")
                    Label("cloakshot_read_file - filtered file read", systemImage: "doc")
                    Label("cloakshot_list_directory - filtered directory listing", systemImage: "folder")
                    Label("cloakshot_check_command - check if a command is safe", systemImage: "terminal")
                    Label("cloakshot_status - current shield status", systemImage: "info.circle")
                }
                .font(.caption)
                .padding(4)
            }

            Spacer()
        }
        .padding()
    }

    private var mcpBinaryPath: String {
        if let execURL = Bundle.main.executableURL {
            let dir = execURL.deletingLastPathComponent()
            return dir.appendingPathComponent("cloakshot-mcp").path
        }
        return "/path/to/cloakshot-mcp"
    }
}
