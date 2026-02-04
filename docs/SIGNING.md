# Code Signing & Notarization

This document explains how to set up code signing for PromptPulse releases.

## Overview

macOS Gatekeeper requires apps to be signed and notarized for a smooth user experience. Without signing, users see security warnings and must manually allow the app to run.

## Requirements

- **Apple Developer Program** membership ($99/year)
- **Developer ID Application** certificate
- **App-specific password** for notarization

## Setup Steps

### 1. Create Developer ID Certificate

1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/certificates/list)
2. Click **+** to create a new certificate
3. Select **Developer ID Application**
4. Follow the CSR creation process using Keychain Access
5. Download and install the certificate

### 2. Export Certificate as .p12

```bash
# In Keychain Access:
# 1. Find "Developer ID Application: Your Name (TEAM_ID)"
# 2. Right-click → Export
# 3. Save as .p12 with a strong password
```

### 3. Create App-Specific Password

1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Sign In → Security → App-Specific Passwords
3. Generate a new password for "PromptPulse CI"

### 4. Configure GitHub Secrets

Add these secrets to your GitHub repository (Settings → Secrets → Actions):

| Secret | Description | How to get |
|--------|-------------|------------|
| `APPLE_CERTIFICATE_BASE64` | Base64-encoded .p12 certificate | `base64 -i certificate.p12` |
| `APPLE_CERTIFICATE_PASSWORD` | Password used when exporting .p12 | Your chosen password |
| `KEYCHAIN_PASSWORD` | Any random password for CI keychain | Generate random string |
| `APPLE_DEVELOPER_ID` | Your name as shown in certificate | "Your Name (TEAM_ID)" |
| `APPLE_ID` | Your Apple ID email | your@email.com |
| `APPLE_TEAM_ID` | 10-character Team ID | Find in Developer Portal |
| `APPLE_APP_PASSWORD` | App-specific password | From step 3 |

### 5. Encode Certificate

```bash
# Encode the .p12 file to base64
base64 -i DeveloperIDApplication.p12 | pbcopy

# Paste into APPLE_CERTIFICATE_BASE64 secret
```

## Release Process

### Creating a Release

```bash
# Tag a new version
git tag v1.0.0
git push origin v1.0.0
```

The release workflow will automatically:
1. Build the app in Release configuration
2. Sign with Developer ID certificate
3. Submit for notarization
4. Staple the notarization ticket
5. Create a GitHub release with the signed .zip

### Version Naming

- `v1.0.0` - Stable release
- `v1.0.0-beta.1` - Beta release (marked as pre-release)
- `v1.0.0-alpha.1` - Alpha release (marked as pre-release)

## Local Signing (Development)

For local development, you can sign manually:

```bash
# Build release
tuist xcodebuild build -scheme PromptPulse -configuration Release

# Find the app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "PromptPulse.app" -type d | head -1)

# Sign with Developer ID
codesign --force --deep --sign "Developer ID Application: Your Name (TEAM_ID)" "$APP_PATH"

# Verify signature
codesign --verify --verbose "$APP_PATH"
spctl --assess --verbose "$APP_PATH"
```

## Notarization (Local)

```bash
# Create ZIP
ditto -c -k --keepParent "$APP_PATH" PromptPulse.zip

# Submit for notarization
xcrun notarytool submit PromptPulse.zip \
  --apple-id "your@email.com" \
  --team-id "TEAM_ID" \
  --password "app-specific-password" \
  --wait

# Staple ticket to app
xcrun stapler staple "$APP_PATH"
```

## Unsigned Releases

If you don't have an Apple Developer account, the CI will still create unsigned releases. Users will need to:

1. Download the app
2. Try to open it (will be blocked)
3. Go to System Settings → Privacy & Security
4. Click "Open Anyway" for PromptPulse

Or right-click the app and select "Open" from the context menu.

## Troubleshooting

### "Developer ID Application" certificate not found

Ensure the certificate is installed in the CI keychain and the `APPLE_DEVELOPER_ID` matches exactly.

### Notarization fails

- Check that the app-specific password is correct
- Ensure the Team ID matches your certificate
- The app must not contain any unsigned code or frameworks

### Stapling fails

The app must be notarized successfully before stapling. Check notarization status:

```bash
xcrun notarytool history --apple-id "your@email.com" --team-id "TEAM_ID"
```
