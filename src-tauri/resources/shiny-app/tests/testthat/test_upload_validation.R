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
