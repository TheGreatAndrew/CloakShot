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
- Local PII detection model for text redaction

## Project structure

```
Sources/
  CloakShot/           # Menu bar app, settings UI
  CloakShotMCP/        # MCP server for AI agent integration
  ScreenShield/        # Window allowlist
  FileShield/          # Folder allowlist
  TextRedactor/        # OCR + PII detection
  Shared/              # Common types, config, app rules engine
Tests/
Resources/
  AppRules/            # Per-app zone configs (YAML)
```

## Build

```bash
swift build
swift test
```

## Contributing

- App rules are YAML files, easy to add without knowing Swift
- All processing must stay local, no network calls for privacy features
- macOS 14+ (Sonoma)
- AGPL-3.0
