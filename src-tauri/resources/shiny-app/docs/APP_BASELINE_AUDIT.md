# App Baseline Audit

Baseline audit date: 2026-04-26

Status: historical snapshot. This document intentionally describes the app as it
existed before the modernization pass. Some package names, UI behavior, and
helper names mentioned here have since changed; use `README.md`,
`docs/MAINTENANCE.md`, `docs/SECURITY_AND_PRIVACY.md`, and
`docs/REGRESSION_TESTING.md` for current maintenance guidance.

This document records the current state of the Shiny companion app before
modernization, refactoring, security hardening, or UI changes. It is intended as
the checkpoint required by `01_SHINY_COMPANION_APP_MODERNIZATION_AUDIT.md`.

## Repository map

Top-level files and directories:

- `app.R` - main Shiny entry point; loads packages, sources helper files, defines
  `ui`, `server`, and `shinyApp()`.
- `functions_reliability.R` - upload parsing, input checks, reliability
  calculations, regression calculations, and plot construction for the
  test-retest workflow.
- `functions_factorial.R` - factorial design generation helpers for two-level
  and n-level designs, plus correlation table preparation.
- `custom_corr_plot.R` - customized correlation matrix helper adapted around
  DoE design objects.
- `ui/` - tab definitions sourced from `app.R`.
- `server/` - server logic sourced from `app.R`.
- `www/index.png` - image displayed in the navbar.
- `demo_data.csv` and `demo_data.xlsx` - bundled example input files.
- `README.md` and `README.html` - current project documentation.
- `test.Rmd` - exploratory R Markdown code for factorial/correlation plotting.
- `conjoint_app.Rproj` - RStudio project file.

Directories/files not currently present:

- No `R/` package-style function directory.
- No `tests/` or `tests/testthat/`.
- No `docs/` before this audit.
- No `scripts/` directory.
- No `DESCRIPTION`.
- No `renv.lock`.
- No `Dockerfile`.
- No `global.R`, `ui.R`, or `server.R`.
- No `data/`, `inst/`, or deployment configuration discovered.

## App entry points

The app entry point is `app.R`.

- Packages are loaded at `app.R:11-28`.
- Helper files are sourced at `app.R:29-31`.
- `options(shiny.useragg = FALSE)` is set at `app.R:32`.
- A Bootstrap 5 `bslib` theme is defined at `app.R:35`.
- UI is defined with `fluidPage()` and `navbarPage()` beginning around
  `app.R:46`.
- UI tab files are sourced inside the navbar menus from `ui/`.
- Server logic is defined at `app.R:117`.
- Server files are sourced inside the `server <- function(input, output, session)`
  body from `server/`.
- `shinyApp(ui = ui, server = server)` is called at `app.R:129`.

Current local run path is the default Shiny/RStudio app flow, or equivalent:

```r
shiny::runApp()
```

There is no dedicated `scripts/run_app.R` yet.

## Package inventory

Packages loaded directly by `app.R`:

- `shiny`
- `shinyjs`
- `shinycssloaders`
- `shinyalert`
- `bslib`
- `tidyverse`
- `reactable`
- `FrF2`
- `DoE.base`
- `broom`
- `psych`
- `sandwich`
- `lmtest`
- `parameters`
- `plotly`
- `viridis`
- `vroom`
- `openxlsx`

Packages used with namespace-qualified calls or in helper code:

- `tools` via `tools::file_ext()` in `functions_reliability.R`.
- `prismatic` via `prismatic::best_contrast()` in server plot code.

Packages referenced in exploratory `test.Rmd`:

- `DoE.base`
- `ggcorrplot`
- `plotly`

Dependency management status:

- No `renv.lock`.
- No `DESCRIPTION`.
- Package versions are not pinned in the repository.

## Upload pipeline

Upload UI is defined in `ui/02_ui_reliability_tab.R`.

- `fileInput("upload_data", ".csv or .xlsx", ...)` accepts:
  - `text/csv`
  - `text/comma-separated-values,text/plain`
  - `.csv`
  - `.xlsx`
- Multiple file upload is disabled.
- No explicit upload size limit is set in app code; Shiny's default upload limit
  applies unless configured outside the repo.

Upload server flow is in `server/01_server_reliability_tab.R`.

- `observeEvent(input$upload_data, ...)` begins around line 36.
- On new upload, `rv$check`, `rv$compute`, and `rv$dat` are reset.
- Uploaded files are read by `file_upload(input$upload_data)`.

Parsing is implemented in `functions_reliability.R`.

- `file_upload()` extracts `input_file$name`, extension, and Shiny `datapath`.
- If extension is `csv`, it calls `vroom::vroom(filepath, na = c("", "NA"))`.
- If extension is `xlsx`, it calls
  `openxlsx::read.xlsx(filepath, na.strings = c("", "NA"))`.
- Other extensions return `NULL`.
- Browser-provided filename extension is currently the main format selector.
- There is no separate server-side MIME/content sniffing.
- XLSX sheet/formula expectations are not explicitly checked.

Expected uploaded data shape, inferred from `demo_data.csv` and validation code:

- Required columns:
  - `respondent`
  - `round`
  - `profile`
  - `dv`
  - one or more columns beginning with `att_`
- Demo data has columns:
  - `respondent`, `round`, `profile`, `att_1`, `att_2`, `att_3`, `att_4`,
    `att_5`, `dv`
- Demo CSV contains 1200 data rows.

## Analysis pipeline

Validation and analysis are mixed between server reactives and helper functions.

Input checks in `functions_reliability.R`:

- `column_checker()` selects required columns and lowercases names.
- `attribute_checker()` counts columns beginning with `att_`.
- `class_checker()` coerces `round`, `profile`, `dv`, and `att_` columns to
  numeric.
- `round_checker()` checks that `round` has exactly values `1` and `2`.

Additional validation in `server/01_server_reliability_tab.R`:

- `observeEvent(input$check_data, ...)` handles validation around line 128.
- Data must be uploaded and readable.
- Required columns must exist.
- At least two attributes must be present.
- Required numeric columns must coerce to numeric.
- Round must contain exactly rounds 1 and 2.
- If round 2 contains fewer profiles than round 1, non-replicated round 1
  profiles are removed.

Reliability functions in `functions_reliability.R`:

- `rel_cor()` computes Pearson correlations per profile across round 1 and
  round 2.
- `rel_icc()` computes ICC data per profile.
- `icc_3k()` computes ICC(3,k) and confidence bounds using `psych::ICC()`,
  rounds values, and floors negative ICC values/bounds to zero.
- `slope_difference()` fits separate round 1 and round 2 linear models, obtains
  cluster-robust standard errors via `parameters::model_parameters()`, and
  computes coefficient difference checks.
- `get_difference()` computes beta difference, joint standard error, test
  statistic, and significance label.
- `pooled_regression()` fits a pooled regression with two-way clustered standard
  errors via `lmtest::coeftest()` and `sandwich::vcovCL()`.
- `compute_deviation()`, `wide_to_long()`, `violin_plot()`,
  `icc_effect_plot()`, and `slope_effect_plot()` prepare result plots.

Factorial design functions in `functions_factorial.R`:

- `get_two_level_full()`
- `get_two_level_fractional()`
- `get_n_level_full()`
- `get_n_level_fractional()`
- `get_cor_table()`

Factorial server logic:

- `server/01_server_factorial_two_level_tab.R` handles two-level designs.
- `server/02_server_factorial_n_level_tab.R` handles n-level and mixed-level
  designs.

## Output/download pipeline

Current server-side download handlers:

- `output$download_csv` in `server/01_server_reliability_tab.R` writes bundled
  `demo_data.csv` to the user.
- `output$download_xlsx` in `server/01_server_reliability_tab.R` reads bundled
  `demo_data.xlsx` and writes it to the user.

Current result display outputs:

- Reliability table via `reactable`.
- Mean reliability text.
- Slope difference table via `reactable`.
- Pooled regression table and fit text.
- Violin plot via `plotly`.
- ICC summary plot via `plotly`.
- Slope difference plot via `plotly`.

Current result export status:

- No server-side Excel result export was found.
- No server-side PNG result export was found.
- Plotly modebar image export is configured client-side for plots.
- Generated result files are not currently written to app-managed session
  folders.

## UI inventory

Global UI structure:

- `fluidPage()` wraps the app.
- `navbarPage()` provides navigation.
- Navbar title is `"Conjoint Studies"` with `www/index.png` positioned at top
  right.
- Bootstrap 5 theme is defined through `bslib::bs_theme()`.
- Several inline `tags$style()` rules customize navbar, columns, modals, tabs,
  and sliders.

Tabs and menus:

- `About`
  - `ui/01_ui_general_about_tab.R`
  - `ui/01_ui_factorial_about_tab.R`
  - `ui/01_ui_reliability_about_tab.R`
- `Factorial Designs`
  - `ui/02_ui_factorial_two_level_tab.R`
  - `ui/03_ui_factorial_n_level_tab.R`
- `Test-Retest Reliability`
  - `ui/02_ui_reliability_tab.R`

Reliability UI:

- Uses `sidebarLayout()` with a narrow `sidebarPanel()`.
- Main workflow controls are upload, check, compute, reset, inspect table,
  inspect types, and demo-data downloads.
- Result areas are generated dynamically with `uiOutput("top_row")` and
  `uiOutput("bottom_row")`.
- Output panels use `wellPanel()` and `tabsetPanel()`.
- User feedback primarily uses `shinyalert()` popups.

Factorial UI:

- Two-level design tab allows number of attributes, full/fractional design, and
  resolution selection.
- N-level tab allows comma-separated attribute level counts, design type, and
  resolution selection.
- Results are displayed as reactable tables and correlation heatmaps.

## Temp file and persistence inventory

Observed persistence behavior:

- Shiny stores uploaded files at `input$upload_data$datapath` in Shiny-managed
  temporary upload locations.
- The app reads uploaded files directly from `datapath`.
- There is no app-created per-session work directory.
- There is no explicit cleanup on session end.
- There is no `session$onSessionEnded()` cleanup handler.
- There is no `onStop()` cleanup handler for app-created resources.
- Reset calls `file.remove(input$upload_data$datapath)` if the path exists.
- Demo data is permanently stored in repository root as `demo_data.csv` and
  `demo_data.xlsx`.
- No generated result Excel files or PNG files were found in the current server
  flow.

Risk-sensitive file/path calls found:

- `downloadHandler()` for demo CSV/XLSX.
- `openxlsx::read.xlsx()` for uploaded/demo XLSX.
- `openxlsx::write.xlsx()` for demo XLSX download.
- `vroom::vroom()` for uploaded CSV.
- `file.remove()` on Shiny upload `datapath` during reset.

No app code paths were found for:

- `eval()`
- `parse()`
- `system()`
- `shell()`
- `file.rename()`
- `file.copy()`
- `unlink()`
- server-side `png()`
- `ggsave()`

The audit task file itself contains example snippets with some of these calls;
those are documentation examples, not active app code.

## Current test coverage

No automated test suite is present.

- No `tests/` directory.
- No `testthat` tests.
- No `shinytest2` tests.
- No Playwright/E2E tests.
- `test.Rmd` appears to be exploratory analysis/plotting code, not a repeatable
  test harness.

Existing fixtures/examples:

- `demo_data.csv`
- `demo_data.xlsx`

These are suitable candidates for baseline regression tests after baseline
outputs are generated.

## Current risks

Functional/statistical risks:

- No regression tests protect the current statistical outputs.
- Analysis and Shiny reactive code are tightly coupled in the reliability server
  file.
- Some validation failures are represented by `try-error`/`NULL`, which makes
  downstream behavior harder to test precisely.
- Input validation mutates `rv$dat`, including dropping non-replicated profiles,
  without a separately persisted validation report.

Reproducibility risks:

- No dependency lockfile.
- No package metadata file.
- No scripted local run/check command.
- `bslib::font_google("Roboto Mono")` may require network access or font
  availability depending on runtime behavior.

Upload/security/privacy risks:

- No explicit app-level upload size limit.
- File extension is currently the main format selector.
- No independent content validation before parser selection.
- XLSX sheet count, formulas, and workbook structure are not checked.
- No configured maximum row/column limits.
- No app-owned session directory for generated outputs.
- No explicit cleanup on session end.
- Reset removes the Shiny upload `datapath`, but does not address future
  generated files or session-scoped artifacts.
- No security/privacy documentation exists yet.

Download/output risks:

- Result exports are not implemented server-side.
- Future result downloads need to be generated in and served from a session
  directory.
- Download-before-analysis behavior is not currently covered by tests.

UI/UX risks:

- Bootstrap 5 is available through `bslib`, but the app still uses mostly older
  Shiny layout primitives plus inline CSS.
- Many workflow buttons use icons with little or no visible text.
- Errors are mostly popup alerts and may not leave a persistent validation
  status visible in the page.
- Method notes exist, but the upload/validation/result workflow could be clearer
  for researchers.

Maintenance risks:

- No package-style organization.
- No lint/check script.
- No structured error helpers.
- No session file management helpers.
- README is short and does not document installation, exact input schema,
  privacy behavior, testing, or deployment assumptions.

## Recommended next steps

Follow the sequence from `01_SHINY_COMPANION_APP_MODERNIZATION_AUDIT.md`:

1. Create a reproducible local run/check setup, preferably under `scripts/`.
2. Document or initialize dependency management without blindly upgrading
   package versions.
3. Generate baseline outputs from `demo_data.csv`/`demo_data.xlsx`.
4. Add regression tests for stable core outputs before refactoring analysis
   behavior.
5. Isolate upload parsing and validation into testable functions.
6. Add explicit upload limits and server-side content/schema validation.
7. Add session-specific temporary directories and cleanup on session end.
8. Ensure result downloads are generated in and served only from the session
   directory.
9. Modernize the UI with consistent `bslib`/Bootstrap 5 patterns while
   preserving methodological transparency.
10. Add privacy/security, regression-testing, UI modernization, and completion
    documentation.
