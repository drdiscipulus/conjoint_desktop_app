# Contributing

Conjoint Companion Desktop is publication companion software maintained occasionally.

Contributions are welcome when they keep the app stable and useful for researchers:

- reproducible bug fixes
- installation and release documentation fixes
- compatibility fixes for supported Windows/macOS builds
- regression tests for behavior that should remain stable

Large feature work is not expected by default. Please open an issue first before investing time in a substantial change.

## Bug Reports

Use the bug report template and include:

- operating system and app version
- steps to reproduce
- expected and observed behavior
- a minimal example file when the issue concerns uploads or results

Do not attach sensitive research data. Create a small anonymized example instead.

## Development Checks

Before proposing a change, run the checks that match the change:

```sh
npm ci
npm run check:shiny
```

For release-related changes, also run the native packaging flow on the relevant platform:

```sh
npm run release:portable
```
