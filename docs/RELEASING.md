# Releasing

Releases are manual and occasional. Build each platform on its native operating system, smoke-test the portable app, and upload the resulting archives to a GitHub Release.

## Prerequisites

- Node.js and npm
- Rust toolchain compatible with Tauri 2
- R 4.5.3 for the target platform
- Platform build tools required by Tauri
- For macOS: Xcode command line tools, a paid Apple Developer account, and a `Developer ID Application` certificate
- A clean checkout of this repository

The release process stages a platform-specific R runtime and R package library. Do not commit `src-tauri/resources/runtime`, `src-tauri/target`, `dist`, or `release-artifacts`.

On macOS, install the native libraries needed to restore and sign the bundled R package library:

```sh
brew install pkg-config gettext openssl@3 harfbuzz fribidi gcc libtiff jpeg-turbo webp
```

## Version Bump

Update the same version in:

- `package.json`
- `src-tauri/tauri.conf.json`
- `src-tauri/Cargo.toml`
- `CITATION.cff`, if the software release version should be cited
- `CHANGELOG.md`

Use a version such as `0.1.0` and a matching Git tag such as `v0.1.0`.

## Build And Check

From the repository root:

```sh
npm ci
npm run check:shiny
```

On Windows:

```sh
npm run release:portable:windows
```

On macOS, configure signing and notarization before building. The release scripts also load `.env.release.local` from the repository root. That file is ignored by git; use `.env.release.local.example` as a template.

Use either App Store Connect API credentials:

```sh
export APPLE_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export APPLE_API_ISSUER="..."
export APPLE_API_KEY="..."
export APPLE_API_KEY_PATH="/path/to/AuthKey_XXXXXXXXXX.p8"
npm run release:portable:macos
```

Or Apple ID notarization credentials:

```sh
export APPLE_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export APPLE_ID="you@example.com"
export APPLE_PASSWORD="app-specific-password"
export APPLE_TEAM_ID="TEAMID"
npm run release:portable:macos
```

The macOS release script signs the app bundle and all embedded native R runtime/package binaries before submitting to Apple notarization. This is required because the portable app includes many `.dylib`, `.so`, and helper executable files inside the bundled R runtime.

The portable export writes platform-specific files under:

```text
release-artifacts/<platform>/portable/
```

Expected release assets:

- `Conjoint-Companion-vX.Y.Z-windows-x64.zip`
- `Conjoint-Companion-vX.Y.Z-macos-arm64.zip`
- `SHA256SUMS.txt`

If both Windows and macOS are built separately, merge the checksum lines into one `SHA256SUMS.txt` before uploading the release assets.

## Smoke Test

Before publishing, extract the archive on a normal machine and verify:

- the app opens without requiring R installation
- the Shiny interface loads
- factorial design generation works
- demo reliability data can be uploaded
- XLSX/CSV/ZIP downloads are saved locally
- the app can be closed and the local R process exits
- the app still opens without internet access

## Publish On GitHub

1. Commit the release changes.
2. Create and push the version tag.
3. Draft a GitHub Release for the tag.
4. Upload the Windows and macOS archives plus `SHA256SUMS.txt`.
5. Mention that support is best effort and the repository is not actively monitored.
6. Mark the release as latest after both platform assets have been smoke-tested.
