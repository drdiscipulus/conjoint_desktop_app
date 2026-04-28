#!/usr/bin/env Rscript

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

script_path <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1] %||% "scripts/generate_baseline.R")
root <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)
setwd(root)

required_packages <- c(
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

missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0) {
  stop("Missing required package(s): ", paste(missing_packages, collapse = ", "), call. = FALSE)
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
source("functions_reliability.R")

prepare_reliability_demo_data <- function(path = "demo_data.csv") {
  dat <- vroom::vroom(path, na = c("", "NA"), show_col_types = FALSE)
  dat <- column_checker(dat)
  if (inherits(dat, "try-error")) stop("Required variables are missing.", call. = FALSE)

  att_num <- attribute_checker(dat)
  if (inherits(att_num, "try-error") || att_num < 2) {
    stop("At least two attributes are required.", call. = FALSE)
  }

  dat <- class_checker(dat)
  if (inherits(dat, "try-error")) stop("Required variables must be numeric.", call. = FALSE)

  round_test <- try(round_checker(dat), silent = TRUE)
  if (inherits(round_test, "try-error") || isFALSE(round_test)) {
    stop('Variable "round" is not correctly specified.', call. = FALSE)
  }

  initial_profiles <- dat |>
    filter(round == 1) |>
    pull(profile) |>
    unique()
  replication_profiles <- dat |>
    filter(round == 2) |>
    pull(profile) |>
    unique()

  if (!identical(initial_profiles, replication_profiles)) {
    dat <- dat |>
      filter(profile %in% replication_profiles)
  }

  dat
}

make_reliability_table <- function(dat) {
  cor_res <- rel_cor(dat)
  icc_res <- rel_icc(dat)
  tibble(profile = unique(dat$profile), r = round(cor_res, 2)) |>
    left_join(icc_res, by = "profile")
}

make_baseline <- function() {
  dat <- prepare_reliability_demo_data("demo_data.csv")
  rel <- make_reliability_table(dat)
  slope <- slope_difference(dat)
  pooled <- pooled_regression(dat)

  list(
    generated_at = as.character(Sys.time()),
    demo_data_shape = list(
      rows = nrow(dat),
      columns = ncol(dat),
      names = names(dat),
      profiles = sort(unique(dat$profile)),
      respondents = length(unique(dat$respondent))
    ),
    reliability_table = rel,
    reliability_mean_text = paste0(
      "The mean test-retest reliability is: r = ",
      round(mean(rel$r), 2),
      "; ICC(3,k) = ",
      round(mean(rel$ICC), 2)
    ),
    slope_difference_table = slope,
    pooled_regression_table = pooled$dat,
    pooled_regression_fit = pooled$fit
  )
}

dir.create(file.path(root, "tests", "fixtures"), recursive = TRUE, showWarnings = FALSE)
baseline <- make_baseline()

saveRDS(baseline, file.path(root, "tests", "fixtures", "baseline_reliability.rds"))
readr::write_csv(baseline$reliability_table, file.path(root, "tests", "fixtures", "baseline_reliability_table.csv"))
readr::write_csv(baseline$slope_difference_table, file.path(root, "tests", "fixtures", "baseline_slope_difference_table.csv"))
readr::write_csv(baseline$pooled_regression_table, file.path(root, "tests", "fixtures", "baseline_pooled_regression_table.csv"))

message("Baseline fixtures written to tests/fixtures/.")
