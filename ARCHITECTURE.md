# Architecture

Conjoint Companion Desktop wraps an R Shiny application in a small Tauri 2 desktop shell.

## Runtime Shape

- `src-tauri/src/main.rs` starts the desktop shell.
- The Tauri backend chooses a localhost port, launches the bundled R runtime, waits for Shiny to become available, and opens the Shiny UI in the desktop window.
- The Shiny app snapshot lives in `src-tauri/resources/shiny-app`.
- The desktop launch script lives in `src-tauri/resources/desktop/run_shiny.R`.
- Windows release builds bundle R under `src-tauri/resources/runtime/R`. macOS release builds stage `R.framework` under `src-tauri/bundle-runtime` and place it in the app's `Contents/Frameworks` directory.
- Both platforms bundle the restored R package library under `src-tauri/resources/runtime/R-library`.

The app binds to `127.0.0.1` and is intended to run fully offline after download.

## Data Flow

1. A researcher opens the desktop app.
2. Tauri launches the local Shiny process.
3. The researcher uploads data into the Shiny UI.
4. Shiny processes data in session-specific temporary directories.
5. Downloads are routed back through the desktop shell and saved in the user's normal Downloads directory.
6. Closing the desktop app stops the R child process.

Uploaded data are not sent to GitHub or to the hosted web app.

## Shiny Application Source

The Shiny application under `src-tauri/resources/shiny-app` is the authoritative source for the desktop application. Desktop builds never import code from a sibling checkout, so a given commit always packages the same application sources.

The statistical workflow is treated as a protected baseline. Changes to formulas, pairing rules, output definitions, or interpretation logic must be covered by regression tests.

Reliability data are paired by `respondent + profile`, never by row position. The analyzed profile set is the intersection of profiles found in rounds 1 and 2; respondents incomplete within that set are removed from both rounds before any reliability or regression calculation.

## Desktop Security Boundary

The Shiny process binds only to `127.0.0.1`. Tauri navigation and download handling accept only the exact localhost port started for the current session. External HTTP(S) pages do not receive desktop capabilities, and the loader page uses a restrictive content security policy.

## Release Artifacts

- `npm run release:windows` creates an unsigned Windows x64 portable ZIP.
- `npm run release:macos` creates a signed and notarized Apple Silicon `.app`, archives it as a ZIP, and verifies its framework references and signatures.

Both commands require a clean worktree, consistent versions, and R 4.5.3. They create an archive and `SHA256SUMS.txt` under `release-artifacts/<platform>`.

Release artifacts are intentionally ignored by git and should be attached to GitHub Releases.
