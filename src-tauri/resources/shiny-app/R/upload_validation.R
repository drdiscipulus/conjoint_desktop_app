APP_MAX_UPLOAD_SIZE <- 5 * 1024^2
APP_MAX_UPLOAD_ROWS <- 25000L
APP_MAX_UPLOAD_COLUMNS <- 250L
APP_ALLOWED_UPLOAD_EXTENSIONS <- c("csv", "xlsx")

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

sanitize_display_filename <- function(filename) {
  if (!is.character(filename) || length(filename) != 1L || is.na(filename) || filename == "") {
    return("uploaded_file")
  }

  filename <- basename(filename)
  filename <- gsub("[^A-Za-z0-9._ -]", "_", filename)
  filename <- gsub("\\s+", " ", filename)
  filename <- trimws(filename)

  if (filename == "" || filename %in% c(".", "..")) {
    "uploaded_file"
  } else {
    filename
  }
}

upload_extension <- function(filename) {
  tolower(tools::file_ext(filename))
}

safe_file_size <- function(input_file) {
  if (!is.null(input_file$size) && !is.na(input_file$size)) {
    return(as.numeric(input_file$size))
  }
  if (!is.null(input_file$datapath) && file.exists(input_file$datapath)) {
    return(as.numeric(file.info(input_file$datapath)$size))
  }
  NA_real_
}

validate_upload_file <- function(input_file,
                                 max_size = APP_MAX_UPLOAD_SIZE,
                                 allowed_extensions = APP_ALLOWED_UPLOAD_EXTENSIONS) {
  if (is.null(input_file) || nrow(input_file) != 1L) {
    stop("Please upload exactly one CSV or XLSX file.", call. = FALSE)
  }

  display_name <- sanitize_display_filename(input_file$name)
  extension <- upload_extension(display_name)
  if (!extension %in% allowed_extensions) {
    stop("Only .csv and .xlsx files are accepted.", call. = FALSE)
  }

  if (is.null(input_file$datapath) || !file.exists(input_file$datapath)) {
    stop("The uploaded file is no longer available. Please upload it again.", call. = FALSE)
  }

  size <- safe_file_size(input_file)
  if (is.na(size)) {
    stop("The uploaded file size could not be checked.", call. = FALSE)
  }
  if (size > max_size) {
    stop("The uploaded file is larger than the 5 MB limit.", call. = FALSE)
  }
  if (size <= 0) {
    stop("The uploaded file is empty.", call. = FALSE)
  }

  list(
    display_name = display_name,
    extension = extension,
    datapath = input_file$datapath,
    size = size
  )
}

validate_upload_dimensions <- function(dat,
                                       max_rows = APP_MAX_UPLOAD_ROWS,
                                       max_columns = APP_MAX_UPLOAD_COLUMNS) {
  if (!is.data.frame(dat)) {
    stop("The uploaded file could not be read as tabular data.", call. = FALSE)
  }
  if (nrow(dat) == 0L) {
    stop("The uploaded data file contains no rows.", call. = FALSE)
  }
  if (nrow(dat) > max_rows) {
    stop("The uploaded data has more than 25,000 rows.", call. = FALSE)
  }
  if (ncol(dat) == 0L) {
    stop("The uploaded data file contains no columns.", call. = FALSE)
  }
  if (ncol(dat) > max_columns) {
    stop("The uploaded data has too many columns.", call. = FALSE)
  }

  invisible(TRUE)
}

validate_reliability_dataset <- function(dat) {
  dat <- column_checker(dat)
  if (inherits(dat, "try-error")) {
    stop("Required variables are missing.", call. = FALSE)
  }

  att_num <- attribute_checker(dat)
  if (inherits(att_num, "try-error")) {
    stop("Number of attributes cannot be determined.", call. = FALSE)
  }
  if (att_num < 2) {
    stop("At least two attributes are required.", call. = FALSE)
  }

  dat <- suppressWarnings(class_checker(dat))
  if (inherits(dat, "try-error")) {
    stop("Required variables must be numeric or coercible to numeric.", call. = FALSE)
  }
  numeric_required <- c("round", "profile", "dv", names(dat)[startsWith(names(dat), "att_")])
  if (any(vapply(dat[numeric_required], function(x) any(is.na(x)), logical(1)))) {
    stop("Required numeric variables contain invalid or missing numeric values.", call. = FALSE)
  }

  round_test <- try(round_checker(dat), silent = TRUE)
  if (inherits(round_test, "try-error") || isFALSE(round_test)) {
    stop('Variable "round" must contain exactly rounds 1 and 2.', call. = FALSE)
  }

  initial_profiles <- dat |>
    dplyr::filter(round == 1) |>
    dplyr::pull(profile) |>
    unique()
  replication_profiles <- dat |>
    dplyr::filter(round == 2) |>
    dplyr::pull(profile) |>
    unique()

  dropped_profiles <- FALSE
  if (!identical(initial_profiles, replication_profiles)) {
    dat <- dat |>
      dplyr::filter(profile %in% replication_profiles)
    dropped_profiles <- TRUE
  }

  list(data = dat, dropped_profiles = dropped_profiles)
}
