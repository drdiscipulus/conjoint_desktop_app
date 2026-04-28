test_that("full two-level designs expose encoded correlations", {
  skip_if_not(exists("get_two_level_full"))
  skip_if_not(exists("get_cor_table"))

  result <- get_two_level_full(attributes = 4)
  correlations <- get_cor_table(result$design)
  effect_count <- 4 + choose(4, 2)

  expect_s3_class(correlations, "data.frame")
  expect_equal(nrow(correlations), effect_count * effect_count)
  expect_equal(length(unique(correlations$rowname)), effect_count)
  expect_equal(length(unique(correlations$variables)), effect_count)

  off_diagonal <- correlations |>
    dplyr::filter(rowname != variables)

  expect_true(all(off_diagonal$correlation == 0))
})

test_that("fractional two-level designs still expose encoded correlations", {
  skip_if_not(exists("get_two_level_fractional"))
  skip_if_not(exists("get_cor_table"))

  result <- get_two_level_fractional(attributes = 5, effects = "two-way-clear")
  correlations <- get_cor_table(result$design)

  expect_s3_class(correlations, "data.frame")
  expect_gt(nrow(correlations), 0)
  expect_named(correlations, c("rowname", "variables", "correlation"))
})
