#!/usr/bin/env Rscript

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

script_path <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1] %||% "scripts/run_app.R")
root <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)
setwd(root)

if (!requireNamespace("shiny", quietly = TRUE)) {
  stop("Package 'shiny' is required to run the app.", call. = FALSE)
}

shiny::runApp(root, launch.browser = TRUE)
