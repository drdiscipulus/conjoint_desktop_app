test_that("two-level fractional designs expose encoded correlations", {
  suppressPackageStartupMessages({
    library(tidyverse)
    library(FrF2)
    library(DoE.base)
  })

  project_file <- function(...) {
    normalizePath(file.path("..", "..", ...), mustWork = TRUE)
  }

  source(project_file("functions_factorial.R"))
  source(project_file("custom_corr_plot.R"))

  design <- get_two_level_fractional(attributes = 5, effects = "main_effects")
  correlations <- get_cor_table(design$design)

  expect_s3_class(correlations, "data.frame")
  expect_gt(nrow(correlations), 0)
  expect_true(all(c("rowname", "variables", "correlation") %in% names(correlations)))
  expect_true(any(!is.na(correlations$correlation)))
})

