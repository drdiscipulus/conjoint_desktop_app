# Conjoint Companion Desktop

Conjoint Companion is a free research tool for designing factorial conjoint experiments and assessing the test-retest reliability of metric conjoint data. It accompanies the workflow introduced by Schueler et al. (2024).

The desktop version runs locally on your computer. You do not need to install R, write code, or upload your research data to a server.

## What can I do with the app?

You can use Conjoint Companion to:

- generate full or fractional factorial designs for conjoint experiments;
- evaluate the test-retest reliability of conjoint ratings;
- inspect reliability statistics, regression results, and diagnostic plots; and
- save designs and results as CSV or Excel files.

The app is intended for researchers, instructors, and students working with metric conjoint experiments. For the methodological background and guidance on interpreting the results, please consult the accompanying article.

## Download and start

Download the version for your computer from the [Releases page](https://github.com/drdiscipulus/conjoint_desktop_app/releases). No installation of R or additional R packages is required.

### Windows

1. Download the file ending in `windows-x64.zip`.
2. Right-click the downloaded ZIP file and select **Extract All**.
3. Open the extracted folder.
4. Double-click `conjoint_companion_desktop.exe`.

Please extract the complete ZIP before starting the app. The Windows build is currently not code-signed, so Windows may display a SmartScreen warning. Only continue if you downloaded the file from this repository's official Releases page.

### macOS

The macOS version supports Apple Silicon Macs (M1 or newer).

1. Download the file ending in `macos-arm64.zip`.
2. Double-click the ZIP file to extract it.
3. Move **Conjoint Companion** to your Applications folder if desired.
4. Open the app.

The distributed macOS app is signed and notarized. If the macOS file is not listed on the Releases page, it is not yet available for that release.

## Your first analysis

If you would like to explore the app before using your own data, open **Test-Retest Reliability** and download one of the files under **Demo Data**. You can upload that file directly and follow the steps below.

### Generate a factorial design

1. Open **Factorial Designs** in the navigation bar.
2. Select **2-Level** if every attribute has two levels, or **N-Level** for another number of levels.
3. Enter the number of factors and levels and choose a full or fractional design.
4. Select **Generate design**.
5. Save the resulting design as CSV or Excel.

### Analyze test-retest reliability

1. Open **Test-Retest Reliability**.
2. Upload your CSV or Excel data file.
3. Select **Validate data** and review the validation summary.
4. Select **Run analysis**.
5. Review the results in the app or download them as CSV or Excel files.

Your data file must contain the following columns:

| Column | Meaning |
| --- | --- |
| `respondent` | Participant identifier |
| `round` | Measurement occasion, coded as `1` or `2` |
| `profile` | Conjoint profile identifier |
| `dv` | Dependent variable, such as a preference rating |
| `att_*` | At least two attribute columns whose names begin with `att_` |

The app pairs observations by participant and profile, so the order of rows does not affect the results. It also checks the data before analysis:

- Profiles observed in only one of the two rounds are excluded.
- A participant who is missing an observation for any retained profile is excluded from the complete analysis.
- Duplicate combinations of participant, round, and profile are rejected.
- Any exclusions are reported in the validation summary before the analysis is run.

## Privacy and offline use

The desktop app processes your data locally on your computer.

- Your uploaded research data are not sent to GitHub or to the hosted web app.
- An internet connection is not required after downloading the app.
- Temporary session files are removed when the app closes.
- Files you choose to export are saved in your normal Downloads folder.

If you prefer not to download the desktop version, the [web version](https://shiny.drdiscipulus.de/conjoint_app/) remains available. Data uploaded to the web version are processed on its server rather than solely on your computer.

## Troubleshooting and feedback

If the app does not start on Windows, first confirm that you extracted the complete ZIP rather than opening the executable inside the ZIP preview. On macOS, use the signed and notarized build provided on the Releases page.

For reproducible errors or installation problems, please [open a GitHub issue](https://github.com/drdiscipulus/conjoint_desktop_app/issues). Include your operating system, the app version, what you were trying to do, and the full error message if one was shown. This is academic companion software, and support is provided on a best-effort basis.

## Citation

If you use Conjoint Companion in research or teaching, please cite:

Schueler, J., Anderson, B. S., Murnieks, C. Y., Baum, M., & Kuesshauer, A. (2024). Test-Retest Reliability in Metric Conjoint Experiments: A New Workflow to Evaluate Confidence in Model Results. *Entrepreneurship Theory and Practice, 48*(2), 742–757. https://doi.org/10.1177/10422587231184071

Machine-readable citation metadata are available in [CITATION.cff](CITATION.cff).

## Technical documentation

The desktop application packages the Shiny app and its R environment in a Tauri shell. These documents are intended for contributors and maintainers:

- [Architecture](ARCHITECTURE.md)
- [Maintenance guide](docs/MAINTENANCE.md)
- [Release and packaging guide](docs/RELEASING.md)
- [Security and privacy notes](src-tauri/resources/shiny-app/docs/SECURITY_AND_PRIVACY.md)
- [Regression testing](src-tauri/resources/shiny-app/docs/REGRESSION_TESTING.md)

## License

Conjoint Companion Desktop is open-source software licensed under the [GNU General Public License v3.0](LICENSE).
