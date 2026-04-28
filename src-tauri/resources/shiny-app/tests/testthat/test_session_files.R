suppressPackageStartupMessages({
  library(testthat)
})

project_file <- function(...) {
  testthat::test_path("..", "..", ...)
}

source(project_file("R", "session_files.R"))

test_that("session directories are token-scoped and cleaned up", {
  root <- tempfile("conjoint_sessions_")
  session <- list(token = "../unsafe token")

  path <- create_session_dir(session, root = root)
  expect_true(dir.exists(path))
  expect_true(startsWith(normalizePath(path, mustWork = TRUE), normalizePath(root, mustWork = TRUE)))
  expect_false(grepl("\\.\\.", basename(path), fixed = TRUE))

  writeLines("x", file.path(path, "tmp.txt"))
  expect_true(file.exists(file.path(path, "tmp.txt")))
  expect_true(cleanup_session_dir(path, root = root))
  expect_false(dir.exists(path))
})

test_that("session file paths cannot escape session directory", {
  root <- tempfile("conjoint_sessions_")
  path <- create_session_dir(list(token = "abc"), root = root)

  expect_match(session_file_path(path, "results.xlsx"), "results\\.xlsx$")
  expect_equal(basename(session_file_path(path, "../results.xlsx")), "results.xlsx")

  cleanup_session_dir(path, root = root)
})
