# Releasing

Releases are built, tested, and published manually. CI checks source changes but never creates release artifacts and never receives signing credentials.

## Prerequisites

- Node.js `^20.19.0` or `>=22.12.0` and npm
- Rust toolchain compatible with Tauri 2
- R 4.5.3 for the target platform
- Platform build tools required by Tauri
- A clean checkout of this repository
- `cargo-audit`

Windows releases must be built on Windows x64. macOS releases must be built natively on Apple Silicon and require an Apple Developer ID Application certificate in the login keychain.

The release process stages a platform-specific R runtime and R package library. Do not commit `src-tauri/resources/runtime`, `src-tauri/bundle-runtime`, `src-tauri/target`, `dist`, or `release-artifacts`.

## Version Bump

Update the same version in:

- `package.json`
- `src-tauri/tauri.conf.json`
- `src-tauri/Cargo.toml`
- `CITATION.cff`, if the software release version should be cited
- `CHANGELOG.md`

Use a version such as `0.2.0` and a matching Git tag such as `v0.2.0`. Commit the version bump before running a release command; the preflight intentionally rejects a dirty worktree.

## Windows x64

From the repository root:

```sh
npm ci
npm run release:windows
```

This command runs the full checks, stages R 4.5.3 and the locked R library, smoke-tests the bundled runtime, builds the binary, and exports an unsigned portable ZIP under `release-artifacts/windows-x64`. The Windows archive is intentionally unsigned; state this in the GitHub release notes.

## macOS Apple Silicon

Set signing and notarization credentials only in the local shell environment:

```sh
export APPLE_SIGNING_IDENTITY="Developer ID Application: ..."
export APPLE_ID="..."
export APPLE_PASSWORD="..."
export APPLE_TEAM_ID="..."
npm ci
npm run release:macos
```

The command copies the complete CRAN `R.framework`, restores an ARM64 package library, rewrites absolute framework references to app-relative references, and builds an `.app` with hardened runtime. Tauri signs and notarizes it using the environment above. Verification checks Mach-O architectures and references, the embedded R runtime, `codesign`, Gatekeeper, and the stapled notarization ticket before creating the ZIP.

Release assets are written under:

```text
release-artifacts/<platform>/portable/
```

Expected release assets:

- `Conjoint-Companion-vX.Y.Z-windows-x64.zip`
- `Conjoint-Companion-vX.Y.Z-macos-arm64.zip`
- `SHA256SUMS.txt`

If both Windows and macOS are built separately, merge the checksum lines into one `SHA256SUMS.txt` before uploading the release assets.

## Smoke Test

Before publishing, extract each archive on a native machine without a separate R installation and verify:

- the app opens without requiring R installation
- the Shiny interface loads
- factorial design generation works
- demo reliability data can be uploaded
- XLSX/CSV/ZIP downloads are saved locally
- the app can be closed and the local R process exits
- the app still opens without internet access

On macOS, additionally verify that Gatekeeper opens the app normally and that no Mach-O dependency points to `/Library/Frameworks/R.framework`. On Windows, confirm that the unsigned status is expected and documented.

## Publish On GitHub

1. Confirm the native smoke tests and SHA-256 checksums.
2. Create and push the version tag from the tested commit.
3. Draft a GitHub Release for the tag.
4. Upload the Windows and macOS archives plus `SHA256SUMS.txt`.
5. Mention that support is best effort and the repository is not actively monitored.
6. Mark the release as latest after both platform assets have been smoke-tested.
