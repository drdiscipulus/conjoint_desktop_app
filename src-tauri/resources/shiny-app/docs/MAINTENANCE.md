# Maintenance Notes

Conjoint Companion is intentionally kept as a plain Shiny app rather than an R package. The app is tied to the publication workflow, so maintenance should prioritize stability over new abstractions or feature expansion.

## Entry Points

- `app.R` loads packages, sources helpers, defines the navbar UI, and sources tab-specific server files.
- `scripts/run_app.R` starts the app locally.
- `scripts/check_app.R` checks required packages, sources core helpers, and runs the test suite.

## Folder Structure

- `ui/`: tab UI definitions.
- `server/`: tab server logic.
- `R/`: focused helpers used by the app.
- `functions_factorial.R`: factorial design generation and correlation-matrix preparation.
- `functions_reliability.R`: reliability workflow computations and plot helpers.
- `custom_corr_plot.R`: adapted DoE correlation helper for the two-level heatmap.
- `tests/testthat/`: regression and helper tests.
- `docs/`: user-facing and maintainer-facing documentation.
- `dev/`: exploratory scripts and reports; not required at runtime.

## Helper Files

- `R/upload_validation.R`: upload type, size, row, schema, and numeric validation.
- `R/session_files.R`: session-specific temporary folders and cleanup.
- `R/result_exports.R`: Excel and CSV result export helpers.
- `R/ui_labels.R`: display labels for `att_1`, `att_2`, and interaction names.
- `R/ui_components.R`: shared UI components, reactable theme, and Plotly export config.
- `R/alias_diagnostics.R`: two-level interaction estimability diagnostics.
- `R/interaction_coverage.R`: N-level pairwise coverage and design metadata diagnostics.

## Design Logic

Two-level factorial designs:

- Full designs use `DoE.base::fac.design()`.
- Fractional designs use `FrF2::FrF2()`.
- Resolution III, IV, and V are meaningful here.
- The interaction estimability table reports whether two-way interactions work separately or are confounded with main/two-way effects.

N-level and mixed-level factorial designs:

- Full designs use `DoE.base::fac.design()`.
- Fractional designs use `DoE.base::oa.design()` and related orthogonal-array catalogue tools.
- Classical two-level Resolution III/IV/V language should not be introduced here.
- The app reports full factorial size, generated profile count, whether reduction was achieved, and pairwise coverage/balance.

## Reliability Workflow

The statistical workflow should remain stable unless a test proves an existing bug. Key outputs are covered by regression fixtures in `tests/fixtures/`.

Result exports are intentionally server-generated from session data:

- Excel workbook: reliability table, slope difference, pooled regression.
- CSV zip: same tables as separate CSV files plus model-fit text.

## Source-Based Structure

The app intentionally uses sourced files instead of Shiny modules or an R package. This keeps deployment simple on a private Shiny server and avoids changing the publication-tied runtime shape. Treat the source order in `app.R` and `scripts/check_app.R` as part of the app contract.

If a future change makes the server files difficult to maintain, prefer splitting one tab into smaller sourced files before converting the whole project to modules or a package.

## Plot Helpers

- `deviation_plot()` creates the response-deviation box-plus-jitter plot.
- `icc_effect_plot()` and `slope_effect_plot()` return ggplot objects converted to Plotly in the server.
- Plotly export settings should be changed in `R/ui_components.R` via `app_plotly_config()` where possible.

## Browser Smoke Tests

`scripts/ui_smoke_test.R` provides an optional browser-level smoke test with `shinytest2`. It is not part of the default check pipeline because `shinytest2` is a heavier optional dependency. Run it manually after UI-focused changes when `shinytest2` is installed.

## Safe Maintenance Pattern

1. Make small, behavior-preserving changes.
2. Run `Rscript scripts/check_app.R`.
3. If statistical output changes, update fixtures only intentionally and document why.
4. Avoid changing formulas, model definitions, or output table structures without adding tests first.
5. Treat files in `dev/` as exploratory, not production dependencies.
