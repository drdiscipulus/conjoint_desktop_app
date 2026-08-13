# Function to generate two-level full fractional design
# Relies on the FrF2 package - consult this for further information
get_two_level_full <- function(attributes) {
  # Create an empty character vector for attribute names
  att_names <- vector(mode = "character", length = attributes)

  # Fill vector with names
  for (i in seq_along(att_names)) {
    att_names[[i]] <- paste0("att_", i)
  }

  # Try to find optimal solution
  res <- fac.design(
    nlevels = 2, nfactors = attributes, factor.names = att_names,
    replications = 1
  )

  # Store factorial design
  factorial_design <- res

  # Convert to data frame
  res <- as.data.frame(res)

  # Convert factor to numeric
  res <- res |>
    mutate_if(is.factor, as.character) |>
    mutate_if(is.character, as.numeric)

  # Change 1/2 values to 0/1
  res[res == 1] <- 0
  res[res == 2] <- 1

  # Create profile column
  profiles <- tibble(Profiles = 1:nrow(res))

  # Merge
  res <- cbind(profiles, res)

  # Create list
  res <- list(design = factorial_design, table = res)

  # Return
  return(res)
}


# Get two-level full factorial design
get_two_level_fractional <- function(attributes, effects) {
  # Create an empty character vector for attribute names
  att_names <- vector(mode = "character", length = attributes)

  # Fill vector with names
  for (i in seq_along(att_names)) {
    att_names[[i]] <- paste0("att_", i)
  }

  # Select resolution based on input
  resolution <- switch(effects,
    "main_effects" = 3,
    "two-way" = 4,
    "two-way-clear" = 5
  )

  # Try to find optimal solution
  res <- FrF2(
    nfactors = attributes,
    resolution = resolution,
    factor.names = att_names,
    replications = 1
  )

  # Store factorial design
  factorial_design <- res

  # Convert to data frame
  res <- as.data.frame(res)

  # Convert factor to numeric
  res <- res |>
    mutate_if(is.factor, as.character) |>
    mutate_if(is.character, as.numeric)

  # Change 1/2 values to 0/1
  res[res == -1] <- 0
  res[res == 1] <- 1

  # Create profile column
  profiles <- tibble(Profiles = 1:nrow(res))

  # Merge
  res <- cbind(profiles, res)

  # Create list
  res <- list(design = factorial_design, table = res)

  # Return
  return(res)
}


# Function to generate any kind of n- or mixed-level designs
get_n_level_full <- function(attributes) {
  # split single string into a string vector
  attributes <- parse_n_level_attributes(attributes)

  # Create empty character vector for attribute names
  att_names <- make_attribute_names(length(attributes))

  # Generate a full factorial design
  res <- fac.design(
    nlevels = attributes, factor.names = att_names,
    replications = 1
  )

  # Store factorial design
  factorial_design <- res

  # Convert to data frame
  res <- as.data.frame(res)

  # Convert factor to numeric
  res <- res |>
    mutate_if(is.factor, as.character) |>
    mutate_if(is.character, as.numeric)

  # Create profile column
  profiles <- tibble(Profiles = 1:nrow(res))

  # Merge
  res <- cbind(profiles, res)

  # Create list
  res <- list(design = factorial_design, table = res)

  # Return
  return(res)
}


parse_n_level_attributes <- function(attributes) {
  as.numeric(unlist(strsplit(attributes, ",")))
}


make_attribute_names <- function(n_attributes) {
  paste0("att_", seq_len(n_attributes))
}


format_n_level_design_result <- function(design) {
  design_table <- as.data.frame(design)

  design_table <- design_table |>
    mutate_if(is.factor, as.character) |>
    mutate_if(is.character, as.numeric)

  profiles <- tibble(Profiles = seq_len(nrow(design_table)))

  list(
    design = design,
    table = cbind(profiles, design_table)
  )
}


load_oa_catalogue_entry <- function(array_name) {
  array <- getAnywhere(array_name)$objs$"package:DoE.base"
  class(array) <- c("oa", "matrix")
  array
}


oa_candidate_names <- function(attributes, rgt3, prefilter_gr_below_four = FALSE, max_candidates = 100) {
  candidates <- show.oas(
    nlevels = attributes,
    regular = "all",
    GRgt3 = "all",
    Rgt3 = rgt3,
    show = 0,
    parents.only = FALSE,
    showGRs = TRUE,
    showmetrics = TRUE,
    digits = 2
  )

  if (prefilter_gr_below_four) {
    candidates <- candidates |>
      filter(GR < 4)
  }

  candidates |>
    arrange(nruns) |>
    slice_head(n = max_candidates) |>
    filter(lineage == "") |>
    pull(name)
}


find_minimum_resolution_oa <- function(attributes, att_names, candidate_names, minimum_resolution) {
  for (candidate_name in candidate_names) {
    array <- load_oa_catalogue_entry(candidate_name)
    design <- oa.design(array, nlevels = attributes, columns = "min3", factor.names = att_names)
    resolution <- GR(design, digits = 2)$GR

    if (resolution >= minimum_resolution) {
      return(design)
    }
  }

  NULL
}


resolution_five_candidate_names <- function(attributes, full_factorial_size, max_candidates = 100) {
  show.oas(
    nlevels = attributes,
    regular = "all",
    GRgt3 = "all",
    Rgt3 = TRUE,
    show = 0,
    parents.only = FALSE,
    showGRs = TRUE,
    showmetrics = TRUE,
    digits = 2
  ) |>
    filter(lineage == "", GR >= 5, nruns < full_factorial_size) |>
    arrange(nruns) |>
    slice_head(n = max_candidates) |>
    pull(name)
}


# Function to generate any kind of n- or mixed-level designs
get_n_level_fractional <- function(attributes, criterion, type = NULL) {
  # split single string into a string vector
  attributes <- parse_n_level_attributes(attributes)

  # Create empty character vector for attribute names
  att_names <- make_attribute_names(length(attributes))

  if (criterion == "main_effects") {
    design <- oa.design(nlevels = attributes, columns = "min3", factor.names = att_names)
    res <- format_n_level_design_result(design)
  }

  if (criterion == "two-way") {
    candidate_names <- oa_candidate_names(
      attributes = attributes,
      rgt3 = FALSE,
      prefilter_gr_below_four = TRUE
    )
    design <- find_minimum_resolution_oa(attributes, att_names, candidate_names, 4)

    # Look up resolution 4 arrays if res is null
    if (is.null(design)) {
      candidate_names <- oa_candidate_names(
        attributes = attributes,
        rgt3 = TRUE,
        prefilter_gr_below_four = FALSE
      )
      design <- find_minimum_resolution_oa(attributes, att_names, candidate_names, 4)
    }

    if (is.null(design)) {
      stop("No array exists.", call. = FALSE)
    }

    res <- format_n_level_design_result(design)
  }

  if (criterion == "two-way-clear") {
    candidate_names <- resolution_five_candidate_names(
      attributes = attributes,
      full_factorial_size = prod(attributes)
    )
    design <- find_minimum_resolution_oa(attributes, att_names, candidate_names, 5)

    if (is.null(design)) {
      design <- fac.design(
        nlevels = attributes,
        factor.names = att_names,
        replications = 1
      )
    }

    res <- format_n_level_design_result(design)
  }
  # Return
  return(res)
}


get_encoded_correlation_matrix <- function(data) {
  if (!"design" %in% class(data)) {
    data <- data2design(data)
  }

  data <- change.contr(data, contrasts = "contr.XuWu")
  data <- data[, names(factor.names(data))]
  model_data <- model.matrix(~ .^2, data)
  model_data <- model_data[, colnames(model_data) != "(Intercept)", drop = FALSE]

  if (ncol(model_data) < 2) {
    stop("At least two encoded effects are required for a correlation heatmap.", call. = FALSE)
  }

  cor_dat <- abs(cor(model_data))
  diag(cor_dat) <- NA
  cor_dat
}


# Function to obtain attribute correlations
get_cor_table <- function(data) {
  cor_dat <- try(custom_corr_plot(data, main.only = FALSE, three = FALSE), silent = TRUE)

  if (inherits(cor_dat, "try-error") || is.null(cor_dat)) {
    cor_dat <- get_encoded_correlation_matrix(data)
  }

  cor_dat <- as.data.frame(cor_dat)
  cor_dat <- rownames_to_column(cor_dat)
  cor_dat <- pivot_longer(cor_dat, cols = !rowname, names_to = "variables", values_to = "correlation")
  cor_dat <- cor_dat |>
    mutate(correlation = round(correlation, 1))

  return(cor_dat)
}
