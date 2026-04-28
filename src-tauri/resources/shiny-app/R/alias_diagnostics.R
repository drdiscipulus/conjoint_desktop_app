alias_effect_order <- function(effect) {
  stringr::str_count(effect, stringr::fixed(":")) + 1L
}

prettify_alias_effect <- function(effect) {
  prettify_effect_label(effect)
}

two_level_factor_matrix <- function(design) {
  factor_names <- names(DoE.base::factor.names(design))
  dat <- as.data.frame(design)[, factor_names, drop = FALSE]

  dat[] <- lapply(dat, function(column) {
    values <- as.numeric(as.character(column))
    levels <- sort(unique(values))

    if (length(levels) != 2) {
      stop("Alias diagnostics require two-level factors only.", call. = FALSE)
    }

    ifelse(values == levels[1], -1, 1)
  })

  dat
}

alias_effect_terms <- function(factor_names, max_order = 3) {
  terms <- character()

  for (order in seq_len(max_order)) {
    if (length(factor_names) >= order) {
      terms <- c(
        terms,
        utils::combn(factor_names, order, FUN = paste, collapse = ":")
      )
    }
  }

  terms
}

alias_model_matrix <- function(design, max_order = 3) {
  dat <- two_level_factor_matrix(design)
  terms <- alias_effect_terms(names(dat), max_order = max_order)

  matrix_data <- lapply(terms, function(term) {
    parts <- strsplit(term, ":", fixed = TRUE)[[1]]
    Reduce(`*`, dat[parts])
  })

  stats::setNames(as.data.frame(matrix_data), terms)
}

summarize_two_way_aliases <- function(design, max_order = 3, tolerance = 1e-8) {
  model_matrix <- alias_model_matrix(design, max_order = max_order)
  correlations <- suppressWarnings(stats::cor(model_matrix))
  effects <- colnames(correlations)
  two_way_effects <- effects[alias_effect_order(effects) == 2]

  rows <- lapply(two_way_effects, function(effect) {
    aliases <- effects[
      effects != effect &
        abs(abs(correlations[effect, effects]) - 1) < tolerance
    ]

    relevant_aliases <- aliases[alias_effect_order(aliases) <= 2]
    higher_order_aliases <- aliases[alias_effect_order(aliases) > 2]
    is_confounded <- length(relevant_aliases) > 0

    tibble::tibble(
      two_way_interaction = prettify_alias_effect(effect),
      status = if (is_confounded) "confounded" else "works",
      confounded_with = dplyr::case_when(
        is_confounded ~ paste(prettify_alias_effect(relevant_aliases), collapse = "; "),
        length(higher_order_aliases) > 0 ~ "higher-order interactions only",
        TRUE ~ NA_character_
      ),
      interpretation = dplyr::case_when(
        is_confounded ~ "do not interpret separately",
        length(higher_order_aliases) > 0 ~ "separately estimable as a two-way interaction if higher-order interactions are negligible",
        TRUE ~ "separately estimable as a two-way interaction"
      )
    )
  })

  dplyr::bind_rows(rows)
}
