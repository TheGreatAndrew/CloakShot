# Contributing to CloakShot

## Adding app rules (no Swift needed)

The easiest way to contribute. Each app is a YAML file in `Resources/AppRules/`.

1. Copy an existing rule file
2. Find the app's bundle ID: `osascript -e 'id of app "AppName"'`
3. Define which zones to allow/block
4. Test with the app open
5. Open a PR

## Code contributions

```bash
git clone https://github.com/TheGreatAndrew/CloakShot.git
cd CloakShot
swift build
swift test
```

### Project structure

```
Sources/
  CloakShot/           # Menu bar app, settings UI
  CloakShotMCP/        # MCP server for AI agent integration
  ScreenShield/        # Window allowlist (ScreenCaptureKit)
  FileShield/          # Folder allowlist
  TextRedactor/        # OCR + PII detection
  Shared/              # Common types, config, app rules engine
Tests/
Resources/
  AppRules/            # Per-app zone configs (YAML)
```

### Guidelines

- macOS 14+ (Sonoma)
- Prefer Apple frameworks over third-party dependencies
- All processing must stay local. No network calls for privacy features.
- Run `swift test` before opening a PR

## Reporting bugs

Open an issue. Include your macOS version and which AI tool you're using.
