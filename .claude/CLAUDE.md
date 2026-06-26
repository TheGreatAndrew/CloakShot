# CloakShot

Desktop privacy shield for AI agents. Controls what AI tools can see on your computer.

## What it does

1. **Screen shield** - window allowlist. AI only sees approved apps via ScreenCaptureKit.
2. **File shield** - folder allowlist. AI can only read approved directories.
3. **Text redaction** - local PII detection as safety net on OCR text.

## Tech stack

- macOS native (Swift, SwiftUI)
- Menu bar app
- ScreenCaptureKit for window capture control
- Apple Vision for OCR
- Local PII detection for text redaction
- Yams for YAML parsing

## Project structure

```
Sources/
  CloakShot/           # Menu bar app, settings UI
  CloakShotMCP/        # MCP server for AI agent integration
  ScreenShield/        # Window allowlist (ScreenCaptureKit)
  FileShield/          # Folder allowlist, path checking
  TextRedactor/        # OCR + PII detection + image redaction
  Shared/              # Config, AppRule engine, PII patterns, constants
Tests/
  ScreenShieldTests/
  FileShieldTests/
  TextRedactorTests/
Resources/
  AppRules/            # Per-app zone configs (YAML, one file per app)
```

## Build

```bash
swift build
swift test
```

## Rules

- Never use emdash in code, comments, docs, or commit messages
- Never mention any specific AI company name in the codebase. Keep everything generic ("AI agents", "AI tools", "desktop agents").
- All processing must stay local. No network calls for privacy features. No telemetry.
- Prefer Apple frameworks over third-party dependencies
- macOS 14+ (Sonoma)
- AGPL-3.0
- App rules are YAML files in Resources/AppRules/. One file per app.
- Do not store screenshots to disk. Process in memory only.
- Use `os.log` for debug logging

## App rules format

```yaml
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
    width_ratio: 0.25
```

## Contributing

- Run `swift test` before any PR
- Adding an app rule is the easiest contribution (just a YAML file)
- Find bundle IDs with: `osascript -e 'id of app "AppName"'`
