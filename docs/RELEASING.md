# Releasing

Releases are manual and occasional. Build each platform on its native operating system, smoke-test the portable app, and upload the resulting archives to a GitHub Release.

## Prerequisites

- Node.js and npm
- Rust toolchain compatible with Tauri 2
- R 4.5.3 for the target platform
- Platform build tools required by Tauri
- A clean checkout of this repository

The release process stages a platform-specific R runtime and R package library. Do not commit `src-tauri/resources/runtime`, `src-tauri/target`, `dist`, or `release-artifacts`.

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
npm run release:portable
```

The portable export writes platform-specific files under:

```text
release-artifacts/<platform>/portable/
```

Expected release assets:

- `Conjoint-Companion-vX.Y.Z-windows-x64.zip`
- `Conjoint-Companion-vX.Y.Z-macos-arm64.tar.gz`
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
