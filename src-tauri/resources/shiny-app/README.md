# Embedded Shiny App Snapshot

This directory contains the Shiny app snapshot bundled into Conjoint Companion Desktop.

It is not the primary public documentation for the desktop repository. Start with the repository-level [README.md](../../../README.md) for downloads, citation, privacy notes, and release information.

## Desktop-Specific Notes

- The desktop build preserves `renv.lock` and restores a bundled package library during runtime staging.
- The app is launched locally by the Tauri shell through `src-tauri/resources/desktop/run_shiny.R`.
- Changes to statistical formulas, result definitions, and interpretation logic should be backed by regression tests.

## Useful Commands

From the repository root:

```sh
npm run check:shiny
Rscript src-tauri/resources/shiny-app/scripts/check_app.R
```
