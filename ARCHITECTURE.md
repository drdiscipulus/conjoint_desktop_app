# Architecture

Conjoint Companion Desktop wraps an R Shiny application in a small Tauri 2 desktop shell.

## Runtime Shape

- `src-tauri/src/main.rs` starts the desktop shell.
- The Tauri backend chooses a localhost port, launches the bundled R runtime, waits for Shiny to become available, and opens the Shiny UI in the desktop window.
- The Shiny app snapshot lives in `src-tauri/resources/shiny-app`.
- The desktop launch script lives in `src-tauri/resources/desktop/run_shiny.R`.
- Release builds bundle a platform-specific R runtime and restored R package library under `src-tauri/resources/runtime`.

The app binds to `127.0.0.1` and is intended to run fully offline after download.

## Data Flow

1. A researcher opens the desktop app.
2. Tauri launches the local Shiny process.
3. The researcher uploads data into the Shiny UI.
4. Shiny processes data in session-specific temporary directories.
5. Downloads are routed back through the desktop shell and saved locally.
6. Closing the desktop app stops the R child process.

Uploaded data are not sent to GitHub or to the hosted web app.

## Source And Bundled Snapshot

The desktop repo contains a copied Shiny app snapshot. `scripts/sync_shiny_app.mjs` can refresh it from a sibling source checkout, preserving desktop-owned files such as `renv.lock`.

The statistical workflow is treated as a protected baseline. Changes to formulas, output definitions, or interpretation logic should be covered by regression tests.

## Release Artifacts

`npm run release:portable` builds the Tauri executable, stages the bundled runtime, exports a portable directory, and creates a release archive plus `SHA256SUMS.txt`.

Release artifacts are intentionally ignored by git and should be attached to GitHub Releases.
