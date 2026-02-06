# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Generate Xcode project (required after changing Project.swift or package deps)
mise exec -- tuist generate --no-open

# Build debug
mise exec -- tuist xcodebuild build -scheme PromptPulse -configuration Debug

# Build release
mise exec -- tuist xcodebuild build -scheme PromptPulse -configuration Release

# Run all tests (uses PromptPulse scheme, not PromptPulseTests)
mise exec -- tuist xcodebuild test -scheme PromptPulse -configuration Debug

# Run a single test target from the SPM package
cd PromptPulseLib && swift test --filter PromptWatchDomainTests

# Run a specific test
cd PromptPulseLib && swift test --filter "CostCalculatorTests/testPerMessageCost"
```

## Architecture

macOS menubar app (Swift 6, SwiftUI, macOS 15+) monitoring Claude Code CLI sessions.

**PromptPulseLib** SPM package has 4 layers (bottom-up dependency order):

```
PromptWatchKit          ← public facade, re-exports domain types
  └─ PromptWatchData    ← parsers (JSONL), repositories (actor), discovery
      └─ PromptWatchPlatform  ← Darwin syscalls, process metrics
          └─ PromptWatchDomain  ← pure value types, CostCalculator, Pricing
```

**App target** (`PromptPulse/`) uses the Kit layer:
- `App/AppDelegate.swift` — menubar NSStatusItem, NSPanel, Sparkle updater
- `State/AppState.swift` — `@Observable @MainActor` main state, navigation, keyboard nav, auto-refresh
- `State/AppSettings.swift` — `@Observable` user preferences with `@AppStorage`
- `Views/SessionDetailView.swift` — largest view (~690 LOC), message list + prompt detail
- `Views/Formatters.swift` — shared formatting (tokens, duration, cost), markdown export

**Source auto-inclusion**: `PromptPulse/**/*.swift` glob in `Project.swift` — new files are picked up automatically.

## Key Patterns

- `@Observable` + `@MainActor` for state; `actor` for repositories
- All domain types are `Sendable` value types
- `Task.detached(priority: .userInitiated)` for background parsing
- `SessionParser` uses `JSONSerialization` fast path (not Codable) for performance
- `logMessage()` wraps `fputs`+`fflush`, gated by `#if DEBUG`
- `Pricing.forModel()` resolves Opus/Sonnet/Haiku pricing from model string

## Releases

Always create a GitHub Release when bumping the version:
1. Bump `CFBundleShortVersionString` in `Project.swift`
2. Commit and push to `main`
3. Tag with `v<version>` and push the tag

This triggers the Release workflow which builds, signs, notarizes, creates the GH release, signs with Sparkle EdDSA, updates `docs/appcast.xml`, and updates the Homebrew tap.

## Known Issues

- `ProjectDir Tests` has 2 failing tests (path encoding) — pre-existing, not related to app functionality
- Entitlements file warning about being copied into bundle — Tuist config issue, harmless
