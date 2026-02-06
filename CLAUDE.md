# Project Instructions

## Releases

Always create a GitHub Release when bumping the version. The workflow is:
1. Bump `CFBundleShortVersionString` in `Project.swift`
2. Commit and push to `main`
3. Tag with `v<version>` and push the tag — this triggers the Release workflow which builds, signs, notarizes, creates the GH release, updates the Sparkle appcast, and updates the Homebrew tap
