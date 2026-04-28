n_level_attribute_counts <- function(attributes) {
  counts <- as.integer(strsplit(attributes, ",", fixed = TRUE)[[1]])
  stats::setNames(counts, paste0("att_", seq_along(counts)))
}

n_level_design_metadata <- function(requested_design_type, attributes, design_table) {
  level_counts <- as.integer(n_level_attribute_counts(attributes))
  full_factorial_size <- prod(level_counts)
  generated_n_profiles <- nrow(design_table)
  reduction_achieved <- generated_n_profiles < full_factorial_size
  effectively_full <- requested_design_type == "Fractional" && !reduction_achieved

  tibble::tibble(
    requested_design_type = requested_design_type,
    actual_design_type = dplyr::case_when(
      requested_design_type == "Full" ~ "Full factorial",
      effectively_full ~ "Full factorial",
      TRUE ~ "Fractional"
    ),
    levels_per_attribute = paste(level_counts, collapse = " x "),
    full_factorial_size = full_factorial_size,
    generated_n_profiles = generated_n_profiles,
    reduction_achieved = reduction_achieved,
    effectively_full_factorial = effectively_full
  )
}

n_level_interaction_coverage <- function(design_table, level_counts = NULL) {
  attribute_columns <- names(design_table)[grepl("^att_\\d+$", names(design_table))]

  if (length(attribute_columns) < 2) {
    stop("At least two attributes are required for interaction coverage.", call. = FALSE)
  }

  if (is.null(level_counts)) {
    level_counts <- vapply(
      design_table[attribute_columns],
      function(column) length(unique(column)),
      integer(1)
    )
  } else {
    level_counts <- level_counts[attribute_columns]
  }

  pairs <- utils::combn(attribute_columns, 2, simplify = FALSE)

  rows <- lapply(pairs, function(pair) {
    first <- pair[[1]]
    second <- pair[[2]]
    first_levels <- seq_len(level_counts[[first]])
    second_levels <- seq_len(level_counts[[second]])

    counts <- table(
      factor(design_table[[first]], levels = first_levels),
      factor(design_table[[second]], levels = second_levels)
    )

    cell_counts <- as.integer(counts)
    observed <- sum(cell_counts > 0)
    possible <- length(first_levels) * length(second_levels)
    balanced <- observed == possible && length(unique(cell_counts)) == 1
    status <- dplyr::case_when(
      observed < possible ~ "not supported",
      balanced ~ "works",
      TRUE ~ "partial"
    )

    tibble::tibble(
      interaction = paste(prettify_attribute_label(pair), collapse = ":"),
      status = status,
      observed_combinations = paste0(observed, " / ", possible),
      minimum_profiles = possible,
      min_cell_count = min(cell_counts),
      max_cell_count = max(cell_counts),
      interpretation = dplyr::case_when(
        status == "works" ~ "all level combinations are observed and balanced",
        status == "partial" ~ "all level combinations are observed, but the pair is unbalanced",
        TRUE ~ "some level combinations are missing; do not interpret this interaction separately"
      )
    )
  })

  dplyr::bind_rows(rows)
}
