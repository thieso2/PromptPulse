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

## Requirements

- macOS 15.0+
- [Tuist](https://tuist.io) for project generation

## Building

```bash
# Generate Xcode project
tuist generate --no-open

# Build debug
tuist xcodebuild build -scheme PromptPulse

# Build release
tuist xcodebuild build -scheme PromptPulse -configuration Release
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘,` | Open Settings |
| `⌘R` | Refresh |
| `↑/↓` | Navigate items |
| `Return` | Activate/drill-down |
| `Escape` | Go back |

## Architecture

- **PromptPulse/**: SwiftUI macOS app
- **swift/**: Swift package with domain logic
  - `PromptWatchKit`: Main facade
  - `PromptWatchData`: Data layer (parsers, repositories)
  - `PromptWatchDomain`: Domain models
  - `PromptWatchPlatform`: Platform-specific code (macOS process monitoring)

## License

MIT
