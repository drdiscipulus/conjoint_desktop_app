# Conjoint App

This repository contains an R Shiny companion app for conjoint-study research.
It supports two workflows:

1. Generate full and fractional factorial designs.
2. Run the test-retest reliability workflow described in the accompanying
   academic paper: *Test-Retest Reliability in Metric Conjoint Experiments: A
   New Workflow to Evaluate Confidence in Model Results*.

The statistical workflow is treated as a protected baseline: modernization and
security work should not change formulas, output definitions, or interpretation
logic without an explicit regression-test-backed reason.

## Local Setup

Install the required R packages before running the app:

```r
install.packages(c(
  "shiny", "shinyjs", "shinycssloaders", "bslib",
  "tidyverse", "reactable", "FrF2", "DoE.base", "broom", "psych",
  "sandwich", "lmtest", "parameters", "plotly", "viridis", "vroom",
  "openxlsx", "prismatic", "testthat"
))
```

This project does not currently use `renv`; dependency versions are not pinned
yet.

## Run

```sh
Rscript scripts/run_app.R
```

## Check

```sh
Rscript scripts/check_app.R
```

The check script reports missing full-app packages and runs the available
regression/security tests when their dependencies are installed.

Optional browser-level smoke check:

```sh
Rscript scripts/ui_smoke_test.R
```

This script skips cleanly if the optional `shinytest2` package is not installed.

## Input Format

Reliability uploads must be `.csv` or `.xlsx` files with exactly one table. The
required columns are:

- `respondent`
- `round`
- `profile`
- `dv`
- at least two attribute columns named with the prefix `att_`

The `round`, `profile`, `dv`, and `att_` columns must be numeric or cleanly
coercible to numeric. The `round` column must contain exactly rounds `1` and
`2`.

Current upload limits:

- maximum file size: 5 MB
- maximum rows: 25,000
- maximum columns: 250

## Outputs

After a successful reliability analysis, the app can export:

- an XLSX workbook with reliability, slope-difference, and pooled-regression
  tables in three sheets: `Reliability table`, `Slope Difference`, and
  `Pooled Regression`,
- a ZIP archive with the same three result tables as separate CSV files.

Plots can be downloaded from the Plotly toolbar in the app.

The bundled `demo_data.csv` and `demo_data.xlsx` remain available as public
sample downloads.

## Privacy And Data Handling

Uploaded data and generated result files are processed in a session-specific
temporary directory. The app registers cleanup at session end and removes
session-generated files on reset. User-provided filenames are used only for
display/format checks, not for internal paths.

See `docs/SECURITY_AND_PRIVACY.md` for operational notes for internet-facing
deployment.

## Maintenance

See `docs/MAINTENANCE.md` for the current file structure, design-generation
boundaries, and safe-change checklist.

## Disclaimer

Please read the instructions and use the app at your own risk.

R Shiny app written by Jens Schüler.
