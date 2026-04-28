#!/usr/bin/env Rscript

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

script_path <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1] %||% "scripts/ui_smoke_test.R")
root <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)
setwd(root)

if (!requireNamespace("shinytest2", quietly = TRUE)) {
  message("Skipping browser smoke test: package 'shinytest2' is not installed.")
  quit(status = 0)
}

app <- shinytest2::AppDriver$new(
  app_dir = root,
  name = "conjoint_companion_smoke",
  seed = 100,
  load_timeout = 10000
)

app$expect_values(input = "attributes_2")

app$set_inputs(attributes_2 = 5, design_2 = "Fractional", effects_2 = "main_effects")
app$click("generate_2")
app$wait_for_value(output = "two_level_status", timeout = 10000)
app$expect_values(output = "two_level_status")

app$set_inputs(attributes_n = "3,3,3", design_n = "Fractional", effects_n = "main_effects")
app$click("generate_n")
app$wait_for_value(output = "n_level_status", timeout = 10000)
app$expect_values(output = "n_level_status")

message("Browser smoke test passed.")
