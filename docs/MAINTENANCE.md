# Maintenance

This repository is the desktop/local distribution of Conjoint Companion. It is maintained occasionally as publication companion software, not as an actively developed product.

## Safe Change Policy

Treat the statistical workflow as a protected baseline. Changes to formulas, result definitions, upload validation, or interpretation logic should include regression tests or a clear methodological reason.

Low-risk maintenance usually includes:

- documentation updates
- packaging and release fixes
- dependency compatibility updates
- installation troubleshooting improvements
- small UI text fixes that do not alter methods

## Useful Checks

```sh
npm ci
npm run check
```

`npm run check` covers the frontend build, R tests, Rust formatting/tests/Clippy, `npm audit`, and RustSec. Install `cargo-audit` before running it locally.

The Shiny app has additional notes under `src-tauri/resources/shiny-app/docs/`.

## Runtime And Artifacts

The bundled runtime and release archives are generated files. They are ignored by git and should not be committed:

- `src-tauri/resources/runtime/`
- `src-tauri/bundle-runtime/`
- `src-tauri/target/`
- `dist/`
- `release-artifacts/`

Attach portable builds to GitHub Releases instead.

## Shiny Application Source

The embedded application under `src-tauri/resources/shiny-app` is maintained directly in this repository. Do not copy a sibling Shiny checkout into it during development or release builds. This keeps builds reproducible and prevents desktop-specific validation, download, and offline behavior from being overwritten.

Release builds use `npm run release:windows` on Windows x64 or `npm run release:macos` on Apple Silicon. See [RELEASING.md](RELEASING.md) for native signing and smoke-test requirements.
