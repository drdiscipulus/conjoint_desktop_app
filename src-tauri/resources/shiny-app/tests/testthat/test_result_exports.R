suppressPackageStartupMessages({
  library(testthat)
  library(tidyverse)
  library(openxlsx)
})

project_file <- function(...) {
  testthat::test_path("..", "..", ...)
}

source(project_file("R", "result_exports.R"))
source(project_file("functions_reliability.R"))

test_that("downloads are rejected before analysis is ready", {
  expect_error(ensure_analysis_ready(list(dat = NULL, check = NULL, compute = NULL)), "successful analysis")
  expect_no_error(ensure_analysis_ready(list(dat = data.frame(x = 1), check = "okay", compute = "go")))
})

test_that("result Excel export writes a non-empty workbook", {
  baseline <- readRDS(project_file("tests", "fixtures", "baseline_reliability.rds"))
  path <- tempfile(fileext = ".xlsx")

  write_reliability_results_xlsx(
    path = path,
    reliability_table = baseline$reliability_table,
    reliability_mean = baseline$reliability_mean_text,
    slope_difference_table = baseline$slope_difference_table,
    pooled_regression_table = baseline$pooled_regression_table,
    pooled_regression_fit = baseline$pooled_regression_fit
  )

  expect_true(file_exists_nonempty(path))
  expect_equal(openxlsx::getSheetNames(path), result_export_sheet_names)
})

test_that("result CSV export writes a zip with the three result tables", {
  baseline <- readRDS(project_file("tests", "fixtures", "baseline_reliability.rds"))
  path <- tempfile(fileext = ".zip")

  write_reliability_results_csv_zip(
    path = path,
    reliability_table = baseline$reliability_table,
    reliability_mean = baseline$reliability_mean_text,
    slope_difference_table = baseline$slope_difference_table,
    pooled_regression_table = baseline$pooled_regression_table,
    pooled_regression_fit = baseline$pooled_regression_fit
  )

  expect_true(file_exists_nonempty(path))
  expect_equal(
    utils::unzip(path, list = TRUE)$Name,
    result_export_csv_files
  )
})
