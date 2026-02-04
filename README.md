# PromptPulse

A macOS menubar app for monitoring Claude Code CLI sessions.

## Features

- **Live Process Monitoring**: View active Claude Code processes with CPU and memory usage
- **Session History**: Browse all Claude sessions organized by project
- **Message Viewer**: Read full conversation history with token stats and cost estimates
- **User Prompts Filter**: Focus on just user inputs with drill-down to see Claude's work
- **Keyboard Navigation**: Full keyboard support (arrows, return, escape)
- **Resizable Window**: Standard macOS window with drag-to-resize
- **Status Indicator**: Color-coded menubar icon (green/yellow/orange/red) based on system load
- **Settings**: Customizable font size, theme, and display options

## Requirements

- macOS 15.0+
- [Tuist](https://tuist.io) for project generation
- Xcode 16.0+ with Swift 6.0

## Building

```bash
# Install mise (if not already installed)
curl https://mise.run | sh

# Install Tuist via mise
mise install tuist

# Generate Xcode project
mise exec -- tuist generate --no-open

# Build debug
tuist xcodebuild build -scheme PromptPulse

# Build release
tuist xcodebuild build -scheme PromptPulse -configuration Release

# Run tests
tuist xcodebuild test -scheme PromptPulseTests

# Open in Xcode
tuist generate
```

### Build Output

After building, the app bundle is located at:
```
Derived/Build/Products/Debug/PromptPulse.app
```

To install, drag the app to `/Applications` or run directly from the build folder.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘,` | Open Settings |
| `⌘R` | Refresh |
| `↑/↓` | Navigate items |
| `Return` | Activate/drill-down |
| `Escape` | Go back |
| `U` | Toggle user prompts filter (in message view) |

## CI/CD

[![CI](https://github.com/thieso2/PromptPulse/actions/workflows/ci.yml/badge.svg)](https://github.com/thieso2/PromptPulse/actions/workflows/ci.yml)

### Continuous Integration

Every push and PR triggers:
- Debug build
- Test suite

### Releases

Create a release by tagging:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The release workflow will build, sign (if configured), notarize, and publish to GitHub Releases.

See [docs/SIGNING.md](docs/SIGNING.md) for code signing setup.

## Architecture

```
PromptPulse/
├── Project.swift              # Tuist project configuration
├── PromptPulse/               # SwiftUI macOS app
│   ├── App/                   # AppDelegate, main entry point
│   ├── Views/                 # SwiftUI views
│   ├── State/                 # AppState, AppSettings
│   └── Resources/             # Assets, icons
└── PromptPulseLib/            # Swift package with domain logic
    ├── PromptWatchKit/        # Main facade, public API
    ├── PromptWatchData/       # Data layer (parsers, repositories)
    ├── PromptWatchDomain/     # Domain models, business logic
    └── PromptWatchPlatform/   # Platform-specific code (macOS process monitoring)
```

## License

MIT
