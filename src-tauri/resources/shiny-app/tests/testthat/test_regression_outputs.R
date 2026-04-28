suppressPackageStartupMessages({
  library(testthat)
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

project_file <- function(...) {
  testthat::test_path("..", "..", ...)
}

source(project_file("R", "upload_validation.R"))
source(project_file("functions_reliability.R"))

prepare_demo_data_for_test <- function(path = "demo_data.csv") {
  dat <- vroom::vroom(path, na = c("", "NA"), show_col_types = FALSE)
  dat <- column_checker(dat)
  expect_false(inherits(dat, "try-error"))

  att_num <- attribute_checker(dat)
  expect_false(inherits(att_num, "try-error"))
  expect_gte(att_num, 2)

  dat <- class_checker(dat)
  expect_false(inherits(dat, "try-error"))

  round_test <- try(round_checker(dat), silent = TRUE)
  expect_false(inherits(round_test, "try-error"))
  expect_true(round_test)

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

make_reliability_table_for_test <- function(dat) {
  cor_res <- rel_cor(dat)
  icc_res <- rel_icc(dat)
  tibble(profile = unique(dat$profile), r = round(cor_res, 2)) |>
    left_join(icc_res, by = "profile")
}

test_that("demo data reliability workflow matches baseline fixture", {
  baseline <- readRDS(project_file("tests", "fixtures", "baseline_reliability.rds"))
  dat <- prepare_demo_data_for_test(project_file("demo_data.csv"))

  expect_equal(nrow(dat), baseline$demo_data_shape$rows)
  expect_equal(ncol(dat), baseline$demo_data_shape$columns)
  expect_equal(names(dat), baseline$demo_data_shape$names)
  expect_equal(sort(unique(dat$profile)), baseline$demo_data_shape$profiles)
  expect_equal(length(unique(dat$respondent)), baseline$demo_data_shape$respondents)

  rel <- make_reliability_table_for_test(dat)
  expect_equal(names(rel), names(baseline$reliability_table))
  expect_equal(dim(rel), dim(baseline$reliability_table))
  expect_equal(rel, baseline$reliability_table, tolerance = 1e-8)

  rel_text <- paste0(
    "The mean test-retest reliability is: r = ",
    round(mean(rel$r), 2),
    "; ICC(3,k) = ",
    round(mean(rel$ICC), 2)
  )
  expect_equal(rel_text, baseline$reliability_mean_text)
})

test_that("demo data model outputs match baseline fixture", {
  baseline <- readRDS(project_file("tests", "fixtures", "baseline_reliability.rds"))
  dat <- prepare_demo_data_for_test(project_file("demo_data.csv"))

  slope <- slope_difference(dat)
  expect_equal(names(slope), names(baseline$slope_difference_table))
  expect_equal(dim(slope), dim(baseline$slope_difference_table))
  expect_equal(slope, baseline$slope_difference_table, tolerance = 1e-8)

  pooled <- pooled_regression(dat)
  expect_equal(names(pooled$dat), names(baseline$pooled_regression_table))
  expect_equal(dim(pooled$dat), dim(baseline$pooled_regression_table))
  expect_equal(pooled$dat, baseline$pooled_regression_table, tolerance = 1e-8)
  expect_equal(pooled$fit, baseline$pooled_regression_fit)
})
