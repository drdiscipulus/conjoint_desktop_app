#!/usr/bin/env Rscript

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

script_path <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1] %||% "scripts/check_app.R")
root <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)
setwd(root)

app_packages <- c(
  "shiny",
  "shinyjs",
  "shinycssloaders",
  "bslib",
  "tidyverse",
  "reactable",
  "FrF2",
  "DoE.base",
  "broom",
  "psych",
  "sandwich",
  "lmtest",
  "parameters",
  "plotly",
  "viridis",
  "vroom",
  "openxlsx",
  "prismatic"
)

test_packages <- c(
  "testthat",
  "tidyverse",
  "broom",
  "psych",
  "sandwich",
  "lmtest",
  "parameters",
  "plotly",
  "viridis",
  "vroom",
  "openxlsx"
)

missing_app_packages <- app_packages[!vapply(app_packages, requireNamespace, logical(1), quietly = TRUE)]
missing_test_packages <- test_packages[!vapply(test_packages, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_app_packages) > 0) {
  message(
    "Missing full-app package(s): ",
    paste(missing_app_packages, collapse = ", "),
    "\nThe app may not start until these are installed."
  )
}

if (length(missing_test_packages) > 0) {
  stop(
    "Missing test/check package(s): ",
    paste(missing_test_packages, collapse = ", "),
    "\nInstall them before running regression tests.",
    call. = FALSE
  )
}

suppressPackageStartupMessages({
  library(tidyverse)
  library(broom)
  library(psych)
  library(sandwich)
  library(lmtest)
  library(parameters)
  library(plotly)
  library(viridis)
  library(vroom)
  library(openxlsx)
})

source("R/upload_validation.R")
source("R/session_files.R")
source("R/result_exports.R")
source("R/ui_labels.R")
source("R/ui_components.R")
source("R/interaction_coverage.R")
source("functions_reliability.R")
if (all(c("FrF2", "DoE.base", "prismatic") %in% app_packages[!app_packages %in% missing_app_packages])) {
  suppressPackageStartupMessages({
    library(FrF2)
    library(DoE.base)
  })
  source("R/alias_diagnostics.R")
  source("functions_factorial.R")
}
source("custom_corr_plot.R")

message("Package and source checks passed.")

if (dir.exists(file.path(root, "tests", "testthat"))) {
  testthat::test_dir(file.path(root, "tests", "testthat"), reporter = "summary")
} else {
  message("No tests/testthat directory found yet; skipping automated tests.")
}
