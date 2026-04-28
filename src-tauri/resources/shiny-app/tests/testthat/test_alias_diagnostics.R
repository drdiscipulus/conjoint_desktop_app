test_that("two-way alias diagnostics classify Resolution III confounding", {
  design <- FrF2::FrF2(
    nfactors = 5,
    resolution = 3,
    factor.names = paste0("att_", 1:5),
    randomize = FALSE
  )

  aliases <- summarize_two_way_aliases(design)

  expect_named(
    aliases,
    c("two_way_interaction", "status", "confounded_with", "interpretation")
  )
  expect_equal(nrow(aliases), choose(5, 2))
  expect_true(any(aliases$status == "confounded"))
  expect_true(any(grepl("^Attribute 1:", aliases$two_way_interaction)))
})

test_that("two-way alias diagnostics classify Resolution V two-way interactions as working", {
  design <- FrF2::FrF2(
    nfactors = 6,
    resolution = 5,
    factor.names = paste0("att_", 1:6),
    randomize = FALSE
  )

  aliases <- summarize_two_way_aliases(design)

  expect_equal(nrow(aliases), choose(6, 2))
  expect_true(all(aliases$status == "works"))
  expect_false(any(aliases$interpretation == "do not interpret separately"))
})
