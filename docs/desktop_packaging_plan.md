# Bundled-R Tauri Desktop Packaging Plan

## Summary

Build a new Tauri 2 desktop app in `conjoint_desktop_app` that preserves the Shiny app by bundling a copied Shiny snapshot, a pinned R 4.5.3 runtime, and a restored `renv` package library. The app will be portable-only, fully offline after install, and targeted first at Windows x64 plus macOS Apple Silicon arm64 for internal/test users.

Use the existing Tauri app only as lifecycle inspiration: dynamic localhost port, backend startup wait, and process cleanup. Do not copy its code, UI, styling, or architecture.

References checked:

- Tauri resources: <https://v2.tauri.app/develop/resources/>
- Tauri sidecars: <https://tauri.app/develop/sidecar/>
- R installation and package libraries: <https://cran.r-project.org/doc/manuals/r-release/R-admin.html>

## Key Changes

- Scaffold a fresh Tauri 2 app with a minimal static loader page, not React, unless later needed.
- Add a bundled resource layout:
  - `shiny-app/`: copied snapshot of `D:\coding_projects\conjoint_app`
  - `runtime/R/`: platform-specific bundled R 4.5.3 runtime
  - `runtime/R-library/`: platform-specific `renv`-restored package library
- Add `renv` only to the copied Shiny snapshot in the desktop repo; keep the original Shiny app untouched.
- Add a small desktop launch script for Shiny that:
  - sets working directory to bundled `shiny-app`
  - uses `127.0.0.1`
  - reads the chosen port from an environment variable
  - runs `shiny::runApp(..., launch.browser = FALSE)`
- Update the copied Shiny snapshot for offline safety only where required, especially replacing `font_google("Roboto Mono")` with a local/system font fallback.
- Implement Rust startup lifecycle:
  - resolve bundled resources
  - choose an available localhost port
  - start bundled `Rscript`
  - set `R_HOME`, `R_LIBS_USER`, and Shiny environment variables
  - wait for local Shiny readiness
  - navigate the Tauri window from loader page to the Shiny URL
  - kill the R child process on app exit
- Package portable artifacts only:
  - Windows: portable ZIP/folder containing the Tauri executable and bundled resources
  - macOS arm64: zipped `.app` bundle with bundled R framework/resources
- Updates are manual replacement of the portable package. No built-in updater in this first packaging plan.

## Build And Packaging Flow

- Add cross-platform Node build scripts, written from scratch:
  - sync the Shiny snapshot into desktop resources with an explicit exclude list for `.git`, `dev/`, `test-results/`, generated docs if not needed, and temporary files
  - restore/install R packages from `renv.lock` into a staging library
  - stage the platform R runtime and package library
  - export portable artifacts
- Windows build uses native Windows with R 4.5.3 x64.
- macOS build uses native Apple Silicon macOS with R 4.5.3 arm64.
- Do not attempt cross-compiling R/runtime/package bundles between OSes.

## Test Plan

- Run Shiny source checks before packaging: `Rscript scripts/check_app.R`.
- Run the same check against the copied Shiny snapshot using the staged package library.
- Verify the bundled R runtime can execute:
  - `Rscript --version`
  - package load smoke test for all app dependencies
  - Shiny launch script on a random local port
- Run Tauri checks:
  - frontend/static build
  - `cargo check`
  - Tauri production build on each native platform
- Smoke-test each portable artifact:
  - app opens to Shiny UI
  - no external internet needed
  - factorial design generation works
  - reliability CSV/XLSX upload works
  - demo downloads work
  - result XLSX and ZIP downloads work
  - closing the app stops the local R process

## Assumptions And Defaults

- Original Shiny app remains the source application and is not modified by the desktop packaging work.
- The first packaged runtime is pinned to R 4.5.3 because the current app already passes tests there.
- First release is internal/test, unsigned unless signing is requested later.
- First macOS target is Apple Silicon arm64 only.
- No remote Shiny fallback is included in the first bundled build.
- Localhost security for v1 is loopback binding plus random port; no Shiny auth layer is added unless later required.
