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

format_validation_values <- function(values, limit = 10L) {
  values <- sort(unique(values))
  shown <- utils::head(values, limit)
  suffix <- if (length(values) > limit) ", ..." else ""
  paste0(paste(shown, collapse = ", "), suffix)
}

prepare_reliability_data <- function(dat) {
  duplicate_keys <- dat |>
    dplyr::count(respondent, round, profile, name = "observations") |>
    dplyr::filter(observations > 1L)
  if (nrow(duplicate_keys) > 0L) {
    stop(
      paste0(
        "Each respondent, round, and profile combination must occur exactly once. ",
        "The upload contains ", nrow(duplicate_keys), " duplicated combination(s)."
      ),
      call. = FALSE
    )
  }

  initial_profiles <- sort(unique(dat$profile[dat$round == 1]))
  replication_profiles <- sort(unique(dat$profile[dat$round == 2]))
  analyzed_profiles <- intersect(initial_profiles, replication_profiles)
  excluded_profiles <- setdiff(union(initial_profiles, replication_profiles), analyzed_profiles)

  if (length(analyzed_profiles) == 0L) {
    stop("Rounds 1 and 2 do not contain any common profiles.", call. = FALSE)
  }

  attribute_names <- names(dat)[startsWith(names(dat), "att_")]
  inconsistent_profiles <- dat |>
    dplyr::filter(profile %in% analyzed_profiles) |>
    dplyr::distinct(profile, dplyr::across(dplyr::all_of(attribute_names))) |>
    dplyr::count(profile, name = "designs") |>
    dplyr::filter(designs > 1L) |>
    dplyr::pull(profile)
  if (length(inconsistent_profiles) > 0L) {
    stop(
      paste0(
        "Attribute values must define each profile consistently. Check profile(s): ",
        format_validation_values(inconsistent_profiles), "."
      ),
      call. = FALSE
    )
  }

  input_respondents <- sort(unique(dat$respondent))
  common_data <- dat |>
    dplyr::filter(profile %in% analyzed_profiles)
  expected_rows <- length(analyzed_profiles) * 2L
  retained_respondents <- common_data |>
    dplyr::count(respondent, name = "observations") |>
    dplyr::filter(observations == expected_rows) |>
    dplyr::pull(respondent) |>
    sort()
  excluded_respondents <- setdiff(input_respondents, retained_respondents)

  if (length(retained_respondents) < 2L) {
    stop(
      "Fewer than two respondents have complete observations for every replicated profile in both rounds.",
      call. = FALSE
    )
  }

  clean_data <- common_data |>
    dplyr::filter(respondent %in% retained_respondents) |>
    dplyr::arrange(respondent, profile, round)

  pairs <- clean_data |>
    dplyr::select(respondent, profile, round, dv) |>
    tidyr::pivot_wider(
      names_from = round,
      values_from = dv,
      names_prefix = "dv_round_"
    ) |>
    dplyr::arrange(profile, respondent)

  undefined_profiles <- pairs |>
    dplyr::group_by(profile) |>
    dplyr::summarise(
      initial_sd = stats::sd(dv_round_1),
      replication_sd = stats::sd(dv_round_2),
      .groups = "drop"
    ) |>
    dplyr::filter(
      !is.finite(initial_sd) | initial_sd == 0 |
        !is.finite(replication_sd) | replication_sd == 0
    ) |>
    dplyr::pull(profile)
  if (length(undefined_profiles) > 0L) {
    stop(
      paste0(
        "Reliability is undefined because the dependent variable has no variation in profile(s): ",
        format_validation_values(undefined_profiles), "."
      ),
      call. = FALSE
    )
  }

  report <- list(
    input_rows = nrow(dat),
    retained_rows = nrow(clean_data),
    input_respondent_count = length(input_respondents),
    retained_respondent_count = length(retained_respondents),
    excluded_respondents = excluded_respondents,
    input_profiles = sort(union(initial_profiles, replication_profiles)),
    analyzed_profiles = analyzed_profiles,
    excluded_profiles = excluded_profiles
  )

  list(data = clean_data, pairs = pairs, report = report)
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
  if (any(is.na(dat$respondent)) || any(trimws(as.character(dat$respondent)) == "")) {
    stop('Variable "respondent" contains missing or empty identifiers.', call. = FALSE)
  }

  round_test <- try(round_checker(dat), silent = TRUE)
  if (inherits(round_test, "try-error") || isFALSE(round_test)) {
    stop('Variable "round" must contain exactly rounds 1 and 2.', call. = FALSE)
  }

  prepare_reliability_data(dat)
}
