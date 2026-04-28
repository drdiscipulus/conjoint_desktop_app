create_session_dir <- function(session, root = file.path(tempdir(), "conjoint_trt_app")) {
  dir.create(root, recursive = TRUE, showWarnings = FALSE)

  token <- session$token
  if (!is.character(token) || length(token) != 1L || is.na(token) || token == "") {
    token <- paste0("session_", as.integer(Sys.time()), "_", sample.int(1e6, 1))
  }
  token <- gsub("[^A-Za-z0-9_-]", "_", token)

  path <- file.path(root, token)
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  normalizePath(path, mustWork = TRUE)
}

cleanup_session_dir <- function(path, root = file.path(tempdir(), "conjoint_trt_app")) {
  if (!is.character(path) || length(path) != 1L || is.na(path)) {
    return(invisible(FALSE))
  }
  if (!dir.exists(path)) {
    return(invisible(TRUE))
  }

  normalized_path <- normalizePath(path, mustWork = TRUE)
  normalized_root <- normalizePath(root, mustWork = FALSE)
  if (!startsWith(normalized_path, normalized_root)) {
    stop("Refusing to clean a path outside the app session temp root.", call. = FALSE)
  }

  unlink(normalized_path, recursive = TRUE, force = TRUE)
  invisible(TRUE)
}

session_file_path <- function(session_dir, filename) {
  filename <- basename(filename)
  path <- normalizePath(file.path(session_dir, filename), mustWork = FALSE)
  normalized_session_dir <- normalizePath(session_dir, mustWork = TRUE)

  if (!startsWith(path, normalized_session_dir)) {
    stop("Refusing to create a file outside the current session directory.", call. = FALSE)
  }

  path
}
