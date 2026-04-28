# Conjoint Companion Desktop

Conjoint Companion Desktop is the offline, portable version of the Shiny companion app for:

> Schueler, J., Anderson, B. S., Murnieks, C. Y., Baum, M., & Kuesshauer, A. (2024). Test-Retest Reliability in Metric Conjoint Experiments: A New Workflow to Evaluate Confidence in Model Results. *Entrepreneurship Theory and Practice, 48*(2), 742-757. https://doi.org/10.1177/10422587231184071

The desktop app bundles the Shiny interface, an R runtime, and the required R packages so researchers can run the companion app locally without installing R or sending data to a server.

## Download

Download the latest portable build from the [GitHub Releases page](https://github.com/drdiscipulus/conjoint_desktop_app/releases/latest).

Expected release assets:

- Windows x64: `Conjoint-Companion-vX.Y.Z-windows-x64.zip`
- macOS Apple Silicon: `Conjoint-Companion-vX.Y.Z-macos-arm64.tar.gz`
- Checksums: `SHA256SUMS.txt`

Windows and macOS builds should be treated as release-ready only after they have been smoke-tested on their native platform.

## What The App Does

- Generate full and fractional factorial designs for conjoint experiments.
- Run the test-retest reliability workflow described in the article.
- Export generated designs, result tables, and report-ready output files.
- Run entirely offline after download.

The web version remains available at https://shiny.drdiscipulus.de/conjoint_app/.

## Install And Run

### Windows

1. Download the Windows ZIP file from the latest release.
2. Extract the ZIP file completely.
3. Run `conjoint_companion_desktop.exe`.

Do not run the executable from inside the ZIP preview window; extract it first.

### macOS

1. Download the macOS archive from the latest release.
2. Extract the archive.
3. Move the app to `Applications` if desired.
4. Open the app.

If macOS shows a first-run security warning for an unsigned app, right-click the app and choose `Open`.

## Quick Start

### Factorial Design Generator

1. Open the app and go to the design generator.
2. Choose the number of factors, levels, and design type.
3. Generate the design.
4. Download the design as CSV or Excel.

### Reliability Analysis

Upload a CSV or Excel file with these columns:

- `respondent`: participant identifier
- `round`: test/retest round, using rounds `1` and `2`
- `profile`: profile identifier within the conjoint design
- `dv`: dependent variable or conjoint preference rating
- `att_*`: two or more attribute columns

The app validates the upload, runs the reliability workflow, and offers downloadable result tables. Demo data are included in the app.

## Privacy

The desktop app is designed for offline use.

- Uploaded data are processed locally on your computer.
- No analysis data are sent to the web server or to GitHub.
- Temporary session files are cleaned up when the app closes.
- Only files you explicitly download are saved.

## Project Status And Support

This repository is publication companion software. It is maintained occasionally, mainly for documentation updates, reproducible bugs, installation problems, and compatibility fixes.

Questions are welcome through GitHub issues, but responses are best effort and the repository is not actively monitored as a support channel.

## For Maintainers

- Architecture overview: [ARCHITECTURE.md](ARCHITECTURE.md)
- Release checklist: [docs/RELEASING.md](docs/RELEASING.md)
- Maintenance notes: [docs/MAINTENANCE.md](docs/MAINTENANCE.md)
- Changelog: [CHANGELOG.md](CHANGELOG.md)

Common commands:

```sh
npm ci
npm run check:shiny
npm run release:portable
```

The release script expects a native build environment for the target platform and a staged R runtime.

## Citation

If you use this app in research or teaching, please cite the article:

Schueler, J., Anderson, B. S., Murnieks, C. Y., Baum, M., & Kuesshauer, A. (2024). Test-Retest Reliability in Metric Conjoint Experiments: A New Workflow to Evaluate Confidence in Model Results. *Entrepreneurship Theory and Practice, 48*(2), 742-757. https://doi.org/10.1177/10422587231184071

Machine-readable citation metadata are available in [CITATION.cff](CITATION.cff).

## License

This project is licensed under the GNU General Public License v3.0 only. See [LICENSE](LICENSE).
