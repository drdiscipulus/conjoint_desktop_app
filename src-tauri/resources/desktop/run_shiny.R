#!/usr/bin/env Rscript

app_dir <- Sys.getenv("CONJOINT_SHINY_APP_DIR", unset = "")
host <- Sys.getenv("CONJOINT_SHINY_HOST", unset = "127.0.0.1")
port <- as.integer(Sys.getenv("CONJOINT_SHINY_PORT", unset = "0"))
library_dir <- Sys.getenv("CONJOINT_R_LIBRARY", unset = "")

if (!nzchar(app_dir) || !dir.exists(app_dir)) {
  stop("CONJOINT_SHINY_APP_DIR does not point to an existing Shiny app directory.", call. = FALSE)
}
if (is.na(port) || port <= 0L) {
  stop("CONJOINT_SHINY_PORT must be a positive integer.", call. = FALSE)
}
if (nzchar(library_dir) && dir.exists(library_dir)) {
  .libPaths(c(normalizePath(library_dir, mustWork = TRUE), .libPaths()))
}

setwd(normalizePath(app_dir, mustWork = TRUE))
options(
  shiny.launch.browser = FALSE,
  shiny.host = host,
  shiny.port = port
)

shiny::runApp(appDir = getwd(), host = host, port = port, launch.browser = FALSE)
