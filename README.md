# Conjoint Companion Desktop App

This repository contains the source code and release tooling for the desktop
version of the companion app for the paper. It is intended for researchers who
want to use the publication workflow locally and offline, without installing R
or uploading research data to a server.

- Paper: https://doi.org/10.1177/10422587231184071
- Live web app: https://shiny.drdiscipulus.de/conjoint_app/
- Shiny app source code: https://github.com/drdiscipulus/conjoint_shiny_app
- Desktop downloads: https://github.com/drdiscipulus/conjoint_desktop_app/releases

The repository is the source and release channel for the desktop app. Portable
releases include the Shiny application, a compatible R runtime, and the required
R packages.

## What The App Does

The app supports two conjoint-related workflows:

1. Generate full and fractional factorial designs for conjoint experiments.
2. Run the test-retest reliability workflow described in the accompanying paper:
   *Test-Retest Reliability in Metric Conjoint Experiments: A New Workflow to
   Evaluate Confidence in Model Results*.

The desktop version provides the same core workflows as the hosted web app, but
runs the analysis on your own computer and saves exported files to your normal
Downloads folder.

## How The App Is Built

- `src-tauri/src/main.rs` contains the Tauri 2 desktop shell. It selects an
  available localhost port, starts the bundled R process, waits for Shiny, and
  opens the app in a desktop window.
- `src-tauri/resources/shiny-app/` contains the desktop application's
  authoritative Shiny source, including its UI, server logic, statistical
  helpers, demo data, and tests.
- `src-tauri/resources/desktop/run_shiny.R` launches the embedded Shiny app on
  `127.0.0.1` for the current desktop session.
- `scripts/` contains runtime staging, validation, packaging, signing, and
  portable-release tooling.
- `src/` and `index.html` provide the small loading interface shown while the
  local Shiny process starts.

Release builds use R 4.5.3 and restore the locked R package library before
packaging it with the app. The desktop build does not download or import the
Shiny application from another repository at runtime.

## Download And Start

Download the current archive for your platform from the
[Releases page](https://github.com/drdiscipulus/conjoint_desktop_app/releases).
You do not need to install R, R packages, Node.js, or Rust to use a release.

### Windows x64

1. Download `Conjoint-Companion-vX.Y.Z-windows-x64.zip`.
2. Right-click the archive and select **Extract All**.
3. Open the extracted folder and double-click
   `conjoint_companion_desktop.exe`.

Extract the complete archive before starting the app. The Windows build is
currently unsigned, so Windows may show a SmartScreen warning. Only continue if
you obtained the archive from this repository's official Releases page.

### macOS Apple Silicon

1. Download `Conjoint-Companion-vX.Y.Z-macos-arm64.zip`.
2. Double-click the archive to extract it.
3. Move **Conjoint Companion** to Applications if desired, then open it.

The macOS build supports Apple Silicon Macs and is signed and notarized with an
Apple Developer ID. If a platform archive is not listed for a release, that
platform is not available for that release. Published checksums are provided in
`SHA256SUMS.txt`.

## Build And Run Locally

Building from source requires Node.js `^20.19.0` or `>=22.12.0`, npm, a Rust
toolchain compatible with Tauri 2, R 4.5.3, and the native build tools for your
platform.

```sh
npm ci
npm run prepare:runtime
npm run tauri:dev
```

Runtime staging restores the R packages recorded in the embedded app's
`renv.lock` file and therefore requires internet access. Platform-specific
release commands and signing requirements are documented in
[`docs/RELEASING.md`](docs/RELEASING.md).

## Input Format

Reliability uploads must be `.csv` or `.xlsx` files containing exactly one
table. The required columns are:

- `respondent`
- `round`
- `profile`
- `dv`
- at least two attribute columns whose names begin with `att_`

The `round`, `profile`, `dv`, and `att_` columns must be numeric or cleanly
coercible to numeric. The `round` column must contain exactly rounds `1` and
`2`.

Current upload limits:

- maximum file size: 5 MB
- maximum rows: 25,000
- maximum columns: 250

Observations are paired by respondent and profile, not by row position.
Profiles found in only one round are excluded, and respondents with incomplete
observations across the retained profiles are excluded from both rounds. The
validation summary reports these exclusions before analysis; duplicate
respondent-round-profile combinations are rejected.

## Outputs

The factorial-design workflows can export generated designs as CSV or XLSX
files.

After a successful reliability analysis, the app can export:

- an XLSX workbook containing the `Reliability table`, `Slope Difference`, and
  `Pooled Regression` sheets;
- a ZIP archive containing the same three result tables as separate CSV files.

Plots can be downloaded from the Plotly toolbar. Desktop downloads are routed
to the user's normal Downloads folder.

## Privacy And Data Handling

The desktop app binds its Shiny process only to `127.0.0.1` and processes data
locally on your computer. Uploaded data are not sent to GitHub, the hosted web
app, or another remote service.

Uploaded data and generated result files are handled in a session-specific
temporary directory. Session files are removed when the session ends, and the
local R process is stopped when the desktop app closes. After downloading the
release, the app can be used without an internet connection.

## Maintenance

This repository is maintained occasionally and conservatively as publication
companion software, not as an actively developed product. The statistical
workflow should remain stable unless a specific bug is identified.

Contributors can run the full source checks with:

```sh
npm ci
npm run check
```

Architecture, maintenance, and release details are available in
[`ARCHITECTURE.md`](ARCHITECTURE.md),
[`docs/MAINTENANCE.md`](docs/MAINTENANCE.md), and
[`docs/RELEASING.md`](docs/RELEASING.md). Reproducible problems can be reported
through [GitHub Issues](https://github.com/drdiscipulus/conjoint_desktop_app/issues);
support is provided on a best-effort basis.

## Citation

If you use the app, source code, or workflow in research or teaching, please
cite the article:

Schueler, J., Anderson, B. S., Murnieks, C. Y., Baum, M., & Kuesshauer, A.
(2024). Test-Retest Reliability in Metric Conjoint Experiments: A New Workflow
to Evaluate Confidence in Model Results. *Entrepreneurship Theory and Practice,
48*(2), 742-757. https://doi.org/10.1177/10422587231184071

Machine-readable citation metadata are available in
[`CITATION.cff`](CITATION.cff).

## License

This project is licensed under the GNU General Public License v3.0. See
[`LICENSE`](LICENSE).

Conjoint Companion Desktop by Jens Schueler.
