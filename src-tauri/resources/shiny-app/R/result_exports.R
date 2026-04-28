ensure_analysis_ready <- function(rv) {
  if (is.null(rv$dat) || is.null(rv$check) || is.null(rv$compute) || rv$compute != "go") {
    stop("Run a successful analysis before downloading results.", call. = FALSE)
  }
  invisible(TRUE)
}

result_export_sheet_names <- c("Reliability table", "Slope Difference", "Pooled Regression")
result_export_csv_files <- c(
  "01_reliability_table.csv",
  "02_slope_difference.csv",
  "03_pooled_regression.csv"
)

write_reliability_results_xlsx <- function(path,
                                           reliability_table,
                                           reliability_mean,
                                           slope_difference_table,
                                           pooled_regression_table,
                                           pooled_regression_fit) {
  workbook <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(workbook, result_export_sheet_names[[1]])
  openxlsx::writeData(workbook, result_export_sheet_names[[1]], reliability_table)
  openxlsx::writeData(workbook, result_export_sheet_names[[1]], reliability_mean, startRow = nrow(reliability_table) + 3)

  openxlsx::addWorksheet(workbook, result_export_sheet_names[[2]])
  openxlsx::writeData(workbook, result_export_sheet_names[[2]], slope_difference_table)

  openxlsx::addWorksheet(workbook, result_export_sheet_names[[3]])
  openxlsx::writeData(workbook, result_export_sheet_names[[3]], pooled_regression_table)
  openxlsx::writeData(workbook, result_export_sheet_names[[3]], pooled_regression_fit, startRow = nrow(pooled_regression_table) + 3)

  openxlsx::saveWorkbook(workbook, path, overwrite = TRUE)
  invisible(path)
}

write_reliability_results_csv_zip <- function(path,
                                              reliability_table,
                                              reliability_mean,
                                              slope_difference_table,
                                              pooled_regression_table,
                                              pooled_regression_fit) {
  export_dir <- tempfile("conjoint_results_csv_")
  dir.create(export_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(export_dir, recursive = TRUE, force = TRUE), add = TRUE)

  reliability_path <- file.path(export_dir, result_export_csv_files[[1]])
  slope_path <- file.path(export_dir, result_export_csv_files[[2]])
  pooled_path <- file.path(export_dir, result_export_csv_files[[3]])

  readr::write_csv(reliability_table, reliability_path)
  readr::write_csv(slope_difference_table, slope_path)
  readr::write_csv(pooled_regression_table, pooled_path)

  old_wd <- getwd()
  on.exit(setwd(old_wd), add = TRUE)
  setwd(export_dir)
  utils::zip(
    zipfile = path,
    files = result_export_csv_files,
    flags = "-q"
  )

  invisible(path)
}

file_exists_nonempty <- function(path) {
  file.exists(path) && isTRUE(file.info(path)$size > 0)
}
