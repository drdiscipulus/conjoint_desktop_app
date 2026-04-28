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
npm run check:shiny
npm run release:portable
```

The Shiny app has additional notes under `src-tauri/resources/shiny-app/docs/`.

## Runtime And Artifacts

The bundled runtime and release archives are generated files. They are ignored by git and should not be committed:

- `src-tauri/resources/runtime/`
- `src-tauri/target/`
- `dist/`
- `release-artifacts/`

Attach portable builds to GitHub Releases instead.

## Refreshing The Shiny Snapshot

`scripts/sync_shiny_app.mjs` refreshes the embedded Shiny app from a sibling checkout by default:

```sh
npm run prepare:shiny
```

Set `CONJOINT_SHINY_SOURCE` to point at another source checkout when needed.

The sync script preserves desktop-owned dependency files such as `renv.lock`.
