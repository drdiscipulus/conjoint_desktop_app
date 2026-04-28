test_that("N-level fractional generation keeps known profile counts stable", {
  skip_if_not(exists("get_n_level_fractional"))

  cases <- tibble::tribble(
    ~attributes, ~criterion, ~profiles,
    "3,3,3,3", "main_effects", 9L,
    "3,3,3,3", "two-way", 27L,
    "4,4,4,4", "main_effects", 16L,
    "4,4,4,4", "two-way", 64L
  )

  for (i in seq_len(nrow(cases))) {
    result <- get_n_level_fractional(
      attributes = cases$attributes[[i]],
      criterion = cases$criterion[[i]]
    )

    expect_equal(
      nrow(result$table),
      cases$profiles[[i]],
      info = paste(cases$attributes[[i]], cases$criterion[[i]])
    )
  }
})

test_that("N-level fractional generation identifies effectively full designs", {
  skip_if_not(exists("get_n_level_fractional"))

  result <- get_n_level_fractional(
    attributes = "3,3,4,4",
    criterion = "main_effects"
  )

  metadata <- n_level_design_metadata(
    requested_design_type = "Fractional",
    attributes = "3,3,4,4",
    design_table = result$table
  )

  expect_equal(nrow(result$table), 144L)
  expect_false(metadata$reduction_achieved)
  expect_true(metadata$effectively_full_factorial)
})
