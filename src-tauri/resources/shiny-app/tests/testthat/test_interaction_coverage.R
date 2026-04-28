test_that("n-level interaction coverage detects balanced full coverage", {
  design <- tibble::tibble(
    Profiles = 1:9,
    att_1 = rep(1:3, each = 3),
    att_2 = rep(1:3, times = 3)
  )

  coverage <- n_level_interaction_coverage(
    design,
    c(att_1 = 3, att_2 = 3)
  )

  expect_equal(coverage$status, "works")
  expect_equal(coverage$observed_combinations, "9 / 9")
  expect_equal(coverage$minimum_profiles, 9)
  expect_equal(coverage$min_cell_count, 1)
  expect_equal(coverage$max_cell_count, 1)
})

test_that("n-level interaction coverage detects unbalanced full coverage", {
  design <- tibble::tibble(
    Profiles = 1:5,
    att_1 = c(1, 1, 2, 2, 2),
    att_2 = c(1, 2, 1, 2, 2)
  )

  coverage <- n_level_interaction_coverage(
    design,
    c(att_1 = 2, att_2 = 2)
  )

  expect_equal(coverage$status, "partial")
  expect_equal(coverage$observed_combinations, "4 / 4")
  expect_equal(coverage$min_cell_count, 1)
  expect_equal(coverage$max_cell_count, 2)
})

test_that("n-level interaction coverage detects missing combinations", {
  design <- tibble::tibble(
    Profiles = 1:3,
    att_1 = c(1, 1, 2),
    att_2 = c(1, 2, 1)
  )

  coverage <- n_level_interaction_coverage(
    design,
    c(att_1 = 2, att_2 = 2)
  )

  expect_equal(coverage$status, "not supported")
  expect_equal(coverage$observed_combinations, "3 / 4")
  expect_equal(coverage$min_cell_count, 0)
})

test_that("n-level design metadata detects effectively full fractional designs", {
  design <- tibble::tibble(
    Profiles = 1:9,
    att_1 = rep(1:3, each = 3),
    att_2 = rep(1:3, times = 3)
  )

  metadata <- n_level_design_metadata(
    requested_design_type = "Fractional",
    attributes = "3,3",
    design_table = design
  )

  expect_equal(metadata$requested_design_type, "Fractional")
  expect_equal(metadata$actual_design_type, "Full factorial")
  expect_equal(metadata$full_factorial_size, 9)
  expect_equal(metadata$generated_n_profiles, 9)
  expect_false(metadata$reduction_achieved)
  expect_true(metadata$effectively_full_factorial)
})

test_that("n-level design metadata detects profile reduction", {
  design <- tibble::tibble(
    Profiles = 1:4,
    att_1 = c(1, 1, 2, 2),
    att_2 = c(1, 2, 1, 2),
    att_3 = c(1, 2, 2, 1)
  )

  metadata <- n_level_design_metadata(
    requested_design_type = "Fractional",
    attributes = "2,2,2",
    design_table = design
  )

  expect_equal(metadata$actual_design_type, "Fractional")
  expect_equal(metadata$full_factorial_size, 8)
  expect_equal(metadata$generated_n_profiles, 4)
  expect_true(metadata$reduction_achieved)
  expect_false(metadata$effectively_full_factorial)
})
