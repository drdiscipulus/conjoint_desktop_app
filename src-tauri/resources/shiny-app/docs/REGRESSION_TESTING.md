# Regression Testing

The reliability workflow is protected by baseline fixtures generated from
`demo_data.csv`.

## Generate Baseline Fixtures

Run this only when intentionally updating the protected baseline:

```sh
Rscript scripts/generate_baseline.R
```

The script writes compact fixtures to `tests/fixtures/`:

- `baseline_reliability.rds`
- `baseline_reliability_table.csv`
- `baseline_slope_difference_table.csv`
- `baseline_pooled_regression_table.csv`

## Run Checks

```sh
Rscript scripts/check_app.R
```

The regression tests compare:

- cleaned demo-data dimensions and columns,
- reliability table dimensions, columns, and numeric values,
- reliability mean text,
- slope-difference table,
- pooled-regression table,
- pooled-regression model-fit text.

Numeric comparisons use a small tolerance so harmless floating-point
representation differences do not fail tests.

## Updating The Baseline

Do not update baseline fixtures as part of routine refactoring. Regenerate them
only when a statistical/output change is intentional and documented.
