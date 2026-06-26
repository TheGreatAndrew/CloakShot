# CloakShot

Control what AI agents can see on your computer.

AI desktop agents take screenshots and read your files to control your computer. CloakShot lets you decide which apps and folders they can access. Everything else is hidden.

## How it works

**Screen shield** - pick which apps the AI can see. Everything else shows as a grey box. Uses macOS ScreenCaptureKit to filter at the OS level before any screenshot is taken.

**File shield** - pick which folders the AI can read. Everything else is blocked. Attempts to read blocked paths return "blocked by CloakShot."

**Text redaction** - safety net. Runs local PII detection on text from allowed windows. Catches credit card numbers, SSNs, emails, API keys. All processing happens on your machine. Nothing is sent anywhere.

## Install

```bash
# TODO: Homebrew tap
brew install --cask cloakshot
```

Or build from source:

```bash
git clone https://github.com/TheGreatAndrew/CloakShot.git
cd CloakShot
swift build
```

## Usage

CloakShot runs as a menu bar app.

1. Launch CloakShot
2. Click the menu bar icon
3. Toggle Shield ON
4. Add apps to your allowlist (apps the AI CAN see)
5. Add folders to your allowlist (folders the AI CAN read)

Default: everything is blocked. You allow what you want.

## MCP Integration

CloakShot ships an MCP server so AI desktop agents can use it directly. Add CloakShot as an MCP server in your AI agent's config:

```json
{
  "mcpServers": {
    "cloakshot": {
      "command": "/path/to/cloakshot-mcp"
    }
  }
}
```

Available tools:
- `cloakshot_screenshot` - take a privacy-filtered screenshot
- `cloakshot_read_file` - read a file through the folder allowlist
- `cloakshot_list_directory` - list a directory through the folder allowlist
- `cloakshot_check_command` - check if a shell command touches blocked paths
- `cloakshot_status` - current shield status

## App rules

CloakShot includes per-app rules that give you finer control. Instead of allowing or blocking an entire app, you can allow specific zones.

Example: allow Slack's chat area but block the sidebar (which shows all your channels and DMs).

Rules are simple YAML files in `Resources/AppRules/`. Contributing a new rule doesn't require knowing Swift.

```yaml
# Resources/AppRules/slack.yaml
app_name: Slack
bundle_id: com.tinyspeck.slackmacgap
default: block
zones:
  - name: message_area
    action: allow
    region: center
  - name: sidebar
    action: block
    region: left
```

## Requirements

- macOS 14+ (Sonoma)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

The easiest way to contribute is adding app rules. Each app rule is one YAML file. If you use an app that's not covered, add a rule for it.

## Privacy

- All processing happens locally on your machine
- No data is sent anywhere
- No telemetry, no analytics, no tracking
- Screenshots are processed in memory and never saved to disk

## License

AGPL-3.0. See [LICENSE](LICENSE).
