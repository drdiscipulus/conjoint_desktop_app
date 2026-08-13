desktop_download_dir <- function() {
  configured <- Sys.getenv("CONJOINT_DOWNLOAD_DIR", unset = "")
  candidates <- c(configured, file.path(path.expand("~"), "Downloads"))
  candidates <- candidates[nzchar(candidates)]

  for (candidate in candidates) {
    if (!dir.exists(candidate) && !dir.create(candidate, recursive = TRUE, showWarnings = FALSE)) {
      next
    }

    probe <- tempfile(".conjoint-companion-write-test-", tmpdir = candidate)
    if (file.create(probe, showWarnings = FALSE)) {
      unlink(probe, force = TRUE)
      return(normalizePath(candidate, mustWork = TRUE))
    }
  }

  stop("No writable download directory could be found.", call. = FALSE)
}

desktop_download_filename <- function(filename) {
  filename <- basename(filename)
  filename <- gsub("[^A-Za-z0-9._ ()-]", "_", filename)
  filename <- trimws(gsub("\\s+", " ", filename))
  filename <- gsub("^\\.+|\\.+$", "", filename)

  if (!nzchar(filename)) {
    "conjoint-companion-download"
  } else {
    filename
  }
}

desktop_download_path <- function(filename) {
  directory <- desktop_download_dir()
  filename <- desktop_download_filename(filename)
  candidate <- file.path(directory, filename)

  if (!file.exists(candidate)) {
    return(candidate)
  }

  extension <- tools::file_ext(filename)
  stem <- if (nzchar(extension)) {
    sub(paste0("\\.", extension, "$"), "", filename)
  } else {
    filename
  }

  for (index in seq_len(9999)) {
    next_name <- if (nzchar(extension)) {
      paste0(stem, " (", index, ").", extension)
    } else {
      paste0(stem, " (", index, ")")
    }
    candidate <- file.path(directory, next_name)
    if (!file.exists(candidate)) {
      return(candidate)
    }
  }

  stop("Could not create a unique download filename.", call. = FALSE)
}

desktop_save_download <- function(filename, writer) {
  path <- desktop_download_path(filename)
  writer(path)

  if (!file.exists(path)) {
    stop("Download writer did not create a file.", call. = FALSE)
  }

  showNotification(
    paste("Saved to", path),
    type = "message",
    duration = 8
  )
  invisible(path)
}

observeEvent(input$desktop_download_request, {
  request <- input$desktop_download_request
  req(is.list(request), nzchar(request$id))

  result <- try(
    switch(request$id,
      "download_two_level_csv" = desktop_save_download(
        "two_level_factorial_design.csv",
        function(path) {
          req(get_two_level_factorial()$table)
          readr::write_csv(get_two_level_factorial()$table, path)
        }
      ),
      "download_two_level_xlsx" = desktop_save_download(
        "two_level_factorial_design.xlsx",
        function(path) {
          req(get_two_level_factorial()$table)
          openxlsx::write.xlsx(get_two_level_factorial()$table, path, overwrite = TRUE)
        }
      ),
      "download_n_level_csv" = desktop_save_download(
        "n_level_factorial_design.csv",
        function(path) {
          req(get_n_level_factorial()$table)
          readr::write_csv(get_n_level_factorial()$table, path)
        }
      ),
      "download_n_level_xlsx" = desktop_save_download(
        "n_level_factorial_design.xlsx",
        function(path) {
          req(get_n_level_factorial()$table)
          openxlsx::write.xlsx(get_n_level_factorial()$table, path, overwrite = TRUE)
        }
      ),
      "download_csv" = desktop_save_download(
        "demo_data.csv",
        function(path) {
          copy_bundled_demo_file("demo_data.csv", path)
        }
      ),
      "download_xlsx" = desktop_save_download(
        "demo_data.xlsx",
        function(path) {
          copy_bundled_demo_file("demo_data.xlsx", path)
        }
      ),
      "download_results_xlsx" = desktop_save_download(
        "conjoint_reliability_results.xlsx",
        function(path) {
          ensure_analysis_ready(rv)
          write_reliability_results_xlsx(
            path = path,
            reliability_table = rel_table(),
            reliability_mean = rel_string(),
            slope_difference_table = slope_difference_res(),
            pooled_regression_table = pooled_reg_data()$dat,
            pooled_regression_fit = pooled_reg_data()$fit
          )
        }
      ),
      "download_results_csv" = desktop_save_download(
        "conjoint_reliability_results_csv.zip",
        function(path) {
          ensure_analysis_ready(rv)
          write_reliability_results_csv_zip(
            path = path,
            reliability_table = rel_table(),
            reliability_mean = rel_string(),
            slope_difference_table = slope_difference_res(),
            pooled_regression_table = pooled_reg_data()$dat,
            pooled_regression_fit = pooled_reg_data()$fit
          )
        }
      ),
      stop(paste("Unknown download button:", request$id), call. = FALSE)
    ),
    silent = TRUE
  )

  if (inherits(result, "try-error")) {
    showNotification(
      paste("Download failed:", conditionMessage(attr(result, "condition"))),
      type = "error",
      duration = 10
    )
  }
}, ignoreInit = TRUE)
