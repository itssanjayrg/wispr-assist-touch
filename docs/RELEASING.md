# Releasing

Releases are built, signed, notarized and published by `.github/workflows/release.yml` when a `v*` tag is pushed.

## One-time setup
1. Join the Apple Developer Program and create a **Developer ID Application** certificate.
2. Export it from Keychain Access as a `.p12`, then `base64 -i cert.p12 | pbcopy`.
3. Create an **app-specific password** at appleid.apple.com for notarization.
4. Add these repository secrets:

| Secret | Value |
|---|---|
| `DEVELOPER_ID_CERT_P12_BASE64` | base64 of the exported `.p12` |
| `DEVELOPER_ID_CERT_PASSWORD` | the `.p12` export password |
| `DEVELOPER_ID_IDENTITY` | e.g. `Developer ID Application: Your Name (TEAMID)` |
| `APPLE_ID` | your Apple ID email |
| `APPLE_TEAM_ID` | your 10-character team ID |
| `APPLE_APP_PASSWORD` | the app-specific password |

## Cutting a release
1. Move the **Unreleased** entries in `CHANGELOG.md` under a new version heading.
2. `git tag v1.0.0 && git push origin v1.0.0`.
3. The workflow publishes `WisprAssist-<version>.dmg` and its `.sha256` to GitHub Releases.
4. Update the Homebrew cask (`packaging/homebrew/wispr-assist.rb`) in your tap with the new version and sha256.

The workflow has not yet been run end to end; expect to fix small details on the first tag.
