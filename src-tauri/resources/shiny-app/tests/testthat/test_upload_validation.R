suppressPackageStartupMessages({
  library(testthat)
  library(tidyverse)
  library(vroom)
})

project_file <- function(...) {
  testthat::test_path("..", "..", ...)
}

source(project_file("R", "upload_validation.R"))
source(project_file("functions_reliability.R"))

make_upload <- function(name, path, size = file.info(path)$size) {
  data.frame(
    name = name,
    size = as.numeric(size),
    type = "",
    datapath = path,
    stringsAsFactors = FALSE
  )
}

test_that("unsafe upload display filenames are sanitized", {
  expect_equal(sanitize_display_filename("../secret/demo data.csv"), "demo data.csv")
  expect_equal(sanitize_display_filename("bad<>name.xlsx"), "bad__name.xlsx")
  expect_equal(sanitize_display_filename(".."), "uploaded_file")
})

test_that("upload metadata validation rejects unsafe formats and sizes", {
  csv_path <- tempfile(fileext = ".csv")
  writeLines("respondent,round,profile,dv,att_1,att_2\n1,1,1,1,0,1", csv_path)

  expect_error(validate_upload_file(make_upload("data.txt", csv_path)), "Only .csv and .xlsx")
  expect_error(validate_upload_file(make_upload("data.csv", csv_path, size = APP_MAX_UPLOAD_SIZE + 1)), "5 MB")
  expect_error(validate_upload_file(make_upload("data.csv", csv_path, size = 0)), "empty")
  expect_no_error(validate_upload_file(make_upload("data.csv", csv_path)))
})

test_that("upload dimension validation rejects empty and oversized data", {
  expect_error(validate_upload_dimensions(data.frame()), "no rows")

  oversized <- tibble(
    respondent = seq_len(APP_MAX_UPLOAD_ROWS + 1L),
    round = 1,
    profile = 1,
    dv = 1,
    att_1 = 0,
    att_2 = 1
  )
  expect_error(validate_upload_dimensions(oversized), "25,000 rows")
})

test_that("reliability schema validation rejects bad datasets", {
  missing_columns <- tibble(respondent = 1, round = 1, profile = 1, att_1 = 0, att_2 = 1)
  expect_error(validate_reliability_dataset(missing_columns), "Required variables")

  invalid_numeric <- tibble(
    respondent = c(1, 1),
    round = c(1, 2),
    profile = c(1, 1),
    dv = c("bad", "2"),
    att_1 = c(0, 0),
    att_2 = c(1, 1)
  )
  expect_error(validate_reliability_dataset(invalid_numeric), "invalid or missing numeric")

  invalid_round <- tibble(
    respondent = c(1, 1),
    round = c(1, 3),
    profile = c(1, 1),
    dv = c(1, 2),
    att_1 = c(0, 0),
    att_2 = c(1, 1)
  )
  expect_error(validate_reliability_dataset(invalid_round), "rounds 1 and 2")
})

make_pairing_data <- function(respondents = 1:3, profiles = c(1, 3)) {
  tidyr::expand_grid(
    respondent = respondents,
    round = c(1, 2),
    profile = profiles
  ) |>
    mutate(
      dv = respondent * 10 + profile,
      att_1 = if_else(profile == profiles[[1]], 0, 1),
      att_2 = if_else(profile == profiles[[1]], 1, 0)
    )
}

test_that("reliability pairs are matched by respondent rather than row position", {
  dat <- make_pairing_data(profiles = 7) |>
    arrange(round, if_else(round == 1, respondent, -respondent))

  validation <- validate_reliability_dataset(dat)
  correlations <- rel_cor(validation$pairs)

  expect_equal(correlations$profile, 7)
  expect_equal(correlations$r, 1)
})

test_that("profiles missing from one round are reported and excluded", {
  dat <- make_pairing_data()
  dat <- dat |>
    filter(!(round == 2 & profile == 3))

  validation <- validate_reliability_dataset(dat)

  expect_equal(validation$report$analyzed_profiles, 1)
  expect_equal(validation$report$excluded_profiles, 3)
  expect_equal(sort(unique(validation$data$profile)), 1)
  expect_length(validation$report$excluded_respondents, 0)
})

test_that("an incomplete respondent is removed from every profile and round", {
  dat <- make_pairing_data() |>
    filter(!(respondent == 3 & round == 2 & profile == 3))

  validation <- validate_reliability_dataset(dat)

  expect_equal(validation$report$excluded_respondents, 3)
  expect_equal(validation$report$retained_respondent_count, 2)
  expect_equal(sort(unique(validation$data$respondent)), c(1, 2))
  expect_equal(nrow(validation$data), 8)
})

test_that("duplicate observations and missing respondent identifiers are rejected", {
  dat <- make_pairing_data()
  duplicated_dat <- bind_rows(dat, slice(dat, 1))
  expect_error(validate_reliability_dataset(duplicated_dat), "duplicated combination")

  missing_id <- dat
  missing_id$respondent[[1]] <- NA
  expect_error(validate_reliability_dataset(missing_id), "missing or empty identifiers")
})

test_that("invalid pairing outcomes are rejected with clear messages", {
  no_common_profiles <- make_pairing_data(profiles = 1) |>
    mutate(
      profile = if_else(round == 1, 1, 3),
      att_1 = if_else(round == 1, 0, 1),
      att_2 = if_else(round == 1, 1, 0)
    )
  expect_error(validate_reliability_dataset(no_common_profiles), "any common profiles")

  one_complete_respondent <- make_pairing_data() |>
    filter(respondent == 1 | !(round == 2 & profile == 3))
  expect_error(validate_reliability_dataset(one_complete_respondent), "Fewer than two respondents")

  zero_variance <- make_pairing_data() |>
    mutate(dv = if_else(profile == 1, 5, dv))
  expect_error(validate_reliability_dataset(zero_variance), "no variation")
})

test_that("profile definitions and deviation labels remain explicit", {
  inconsistent <- make_pairing_data()
  inconsistent$att_1[[1]] <- 99
  expect_error(validate_reliability_dataset(inconsistent), "consistently")

  validation <- validate_reliability_dataset(make_pairing_data())
  deviations <- compute_deviation(validation$pairs)
  expect_setequal(unique(deviations$profile), c("Profile 1", "Profile 3"))
})
