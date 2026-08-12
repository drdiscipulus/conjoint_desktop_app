# Other Helpers

## Upload function
file_upload <- function(input) {
  res <- try({
    upload_info <- validate_upload_file(input)
    filepath <- upload_info$datapath

    if (upload_info$extension == "csv") {
      dat <- vroom::vroom(filepath, na = c("", "NA"), show_col_types = FALSE)
    } else if (upload_info$extension == "xlsx") {
      sheet_names <- openxlsx::getSheetNames(filepath)
      if (length(sheet_names) != 1L) {
        stop("Excel uploads must contain exactly one worksheet.", call. = FALSE)
      }
      dat <- openxlsx::read.xlsx(filepath, na.strings = c("", "NA"))
    } else {
      stop("Only .csv and .xlsx files are accepted.", call. = FALSE)
    }

    validate_upload_dimensions(dat)
    dat
  }, silent = TRUE)

  # Return
  return(res)
}


## Select required columns and make them lower case
column_checker <- function(dat) {
  # Try to select all required columns
  res <- try(
    dat |>
      select(respondent, round, profile, dv, starts_with("att_")) |>
      rename_with(tolower),
    silent = TRUE
  )

  # Return
  return(res)
}


## Number of attributes checker
attribute_checker <- function(dat) {
  res <- try(
    dat |>
      select(starts_with("att_")) |>
      ncol(),
    silent = TRUE
  )

  # Return
  return(res)
}


## Data type checker and coercion
class_checker <- function(dat) {
  res <- try(
    dat |>
      mutate_at(c("round", "profile", "dv"), as.numeric) |>
      mutate(across(starts_with("att_"), as.numeric)),
    silent = TRUE
  )

  # Return
  return(res)
}


## Round variable checker
round_checker <- function(dat) {
  # Get number of unique values
  unique_values <- unique(dat$round)

  # Check if length is two
  if (length(unique_values) == 2) {
    # Check if it is 1 and 2
    required_values <- c(1, 2)
    check <- unique_values %in% required_values

    # Check if all true, if not return FALSE
    if (all(check)) {
      res <- TRUE
    } else {
      res <- FALSE
    }
  } else {
    res <- FALSE
  }
}


# Function to get type and class info on data
class_type_overview <- function(dat) {
  # Get information
  var_names <- colnames(dat)
  class_info <- sapply(dat, class)
  type_info <- sapply(dat, typeof)

  # Create table
  res <- tibble(
    Variable = var_names,
    Class = class_info,
    Type = type_info
  )

  # Return table
  return(res)
}


# Test-Retest Reliability

## Pearson's R

# The input is an explicitly respondent-paired wide data set produced by
# validate_reliability_dataset(). Returning the profile key prevents callers
# from accidentally matching results by row position.
rel_cor <- function(pairs) {
  pairs |>
    group_by(profile) |>
    summarise(r = cor(dv_round_1, dv_round_2), .groups = "drop")
}


## ICC(3,k)

# This function takes a data set as an input, splits it into the initial and
# replication responses, calculates the ICC(3,k) for each profile by calling an
# additional helper function, and returns a data frame with ICC(3,k) and its
# 95% confidence interval.
rel_icc <- function(pairs) {
  pairs |>
    group_by(profile) |>
    group_split(.keep = TRUE) |>
    map_dfr(icc_3k)
}


# Function to compute the ICC(3,k)
icc_3k <- function(pairs) {
  # Get all profile names/numbers
  profile <- unique(pairs$profile)
  # Create temporary data set
  tmp <- tibble(initial = pairs$dv_round_1, replication = pairs$dv_round_2)
  # Compute ICCs and extract ICC(3,k) and its 95% confidence interval
  icc <- ICC(tmp,
    missing = TRUE,
    alpha = .05,
    lmer = FALSE,
    check.keys = FALSE
  )$results |>
    filter(type == "ICC3k") |>
    select(ICC, "lower bound", "upper bound") |>
    rename(icc_lower = "lower bound", icc_upper = "upper bound") |>
    mutate_all(round, 2) |>
    mutate(ICC = if_else(ICC < 0, 0, ICC)) |>
    mutate(icc_lower = if_else(icc_lower < 0, 0, icc_lower)) |>
    remove_rownames()
  # Create table
  res <- cbind(profile, icc)
  # Return result
  return(res)
}


## Slope Difference Tests

# This function takes a data set as an input, splits it into initial and
# replication responses, fits two linear models with robust standard errors and
# then calls an additional function to perform a slope difference test an each
# coefficient. This additional function takes a variable name, two beta
# coefficients and standard errors as inputs to conduct perform a
# slope difference test.
slope_difference <- function(dat) {
  # First round of responses
  initial.df <- dat |>
    filter(round == 1)
  # Second round of responses
  replication.df <- dat |>
    filter(round == 2)
  # Create regression formula
  reg_form <- initial.df |>
    select(-c(respondent, round, profile, dv)) |>
    select(starts_with("att_")) |>
    colnames() |>
    paste0(collapse = " + ")
  reg_form <- formula(paste0("dv ~ ", reg_form))

  # Fit a linear regression model on both rounds of responses
  m1.model <- lm(reg_form, data = initial.df)
  m2.model <- lm(reg_form, data = replication.df)

  # Calculate and capture clustered standard errors
  m1.tidy <- model_parameters(
    m1.model,
    vcov = "vcovCL",
    vcov_args = list(type = "HC1", cluster = initial.df$respondent)
  )
  m2.tidy <- model_parameters(
    m2.model,
    vcov = "vcovCL",
    vcov_args = list(type = "HC1", cluster = replication.df$respondent)
  )
  # Drop intercept to tidy the dataframe
  m1.tidy <- filter(m1.tidy, Parameter != "(Intercept)")
  m2.tidy <- filter(m2.tidy, Parameter != "(Intercept)")

  # Transform data frame rows into a list of single row data frames
  m1.list <- m1.tidy |>
    group_by(Parameter) |>
    group_split()
  m2.list <- m2.tidy |>
    group_by(Parameter) |>
    group_split()

  # Apply the slope difference test function to the lists of single row data frames
  res <- map2_dfr(
    m1.list, m2.list,
    ~ get_difference(
      name = .x$Parameter,
      b1 = .x$Coefficient,
      se1 = .x$SE,
      b2 = .y$Coefficient,
      se2 = .y$SE
    )
  )


  # Create result table
  res_table <- tibble(
    iv = m1.tidy$Parameter,
    beta_i = round(m1.tidy$Coefficient, 2),
    se_i = round(m1.tidy$SE, 2),
    p_i = round(m1.tidy$p, 4),
    beta_r = round(m2.tidy$Coefficient, 2),
    se_r = round(m2.tidy$SE, 2),
    p_r = round(m2.tidy$p, 4),
    beta_diff = res$Beta_diff,
    joint_se = res$Joint_se,
    test_statistic = res$Test_statistic,
    stat_diff = res$Stat_diff
  )

  # Return table
  return(res_table)
}


# Function to compute the slope difference test on a single predictor
get_difference <- function(name, b1, se1, b2, se2) {
  # Compute the difference between both beta coefficients
  b <- b1 - b2
  # Compute the corresponding standard error
  se <- sqrt((se1^2) + (se2^2))
  # Multiply the standard error by two to obtain at least the 95% CI
  test <- se * 2
  # Check if the absolute beta difference is at least two SEs away from zero
  if (abs(b) >= test) {
    # If true, then both slopes are significantly different from another
    res <- "Yes"
  } else {
    # If false, both slopes are not significantly different from another
    res <- "No"
  }

  # Create table
  res <- tibble(
    Coefficient = name,
    Beta_diff = b,
    Joint_se = se,
    Test_statistic = abs(b) - (2 * se),
    Stat_diff = res
  )

  # Round all values to two digits
  res <- mutate(res, across(where(is.double), ~ round(.x, 2)))

  # Return table
  return(res)
}

# Regression

# Function to compute a pooled regression model with both rounds of data
# and uses two-way clustered standard errors - round and respondent
pooled_regression <- function(dat) {
  # Convert the grouping variables to a factor
  multi.df <- dat |>
    mutate(
      round = as_factor(round),
      respondent = as_factor(respondent)
    )

  # Create regression formula
  reg_form <- multi.df |>
    select(-c(respondent, round, profile, dv)) |>
    select(starts_with("att_")) |>
    colnames() |>
    paste0(collapse = " + ")
  reg_form <- formula(paste0("dv ~ ", reg_form))

  # Fit a linear regression model
  m3_model <- lm(reg_form, data = multi.df)

  # Obtain and show two-way clustered standard errors (by respondent and round)
  res <- coeftest(m3_model, vcov = vcovCL, cluster = ~ respondent + round)

  # Tidy result
  param <- tidy(res)

  # Change labels
  param <- param |>
    mutate(estimate = round(estimate, 2)) |>
    mutate(std.error = round(std.error, 2)) |>
    mutate(statistic = round(statistic, 2)) |>
    mutate(p.value = round(p.value, 4)) |>
    rename(Coefficient = term) |>
    rename(Beta = estimate) |>
    rename(`t-ratio` = statistic) |>
    rename(`p-value` = p.value) |>
    rename(SE = std.error)

  # Extract model fit
  fit <- glance(m3_model)

  # Model fit string
  fit_txt <- paste0(
    "Model Fit: R-Squared = ", round(fit$r.squared, 2),
    "; R-Squared (adjusted) = ", round(fit$adj.r.squared, 2),
    "; Sigma = ", round(fit$sigma, 2), "; ", fit$nobs,
    " Observations, nested in ", length(unique(multi.df$respondent)), " Respondents."
  )

  # Add fit and observations to results
  res <- list(dat = param, fit = fit_txt)

  # Return result list
  return(res)
}


# Plots

## Deviation Plots

### Response Deviations

# Paired observations are already keyed by respondent and profile. Keeping the
# real profile identifier avoids relabeling partial replications as 1, 2, ... .
compute_deviation <- function(pairs) {
  pairs |>
    transmute(
      respondent,
      profile = paste0("Profile ", profile),
      deviation = dv_round_2 - dv_round_1
    )
}


### Create Deviation Plot

# This function requires a data set, the number of profiles and the
# height of the plot, and its name, as inputs and creates a box plot with
# jittered observations.
deviation_plot <- function(dat, num_profiles, plot_name) {
  # Profile names as factor with ordered levels to preserve order
  dat$profile <- factor(dat$profile, levels = unique(dat$profile))
  plot_font <- list(family = "Arial", color = "#17211d", size = 13)
  axis_title_font <- list(family = "Arial", color = "#17211d", size = 15)

  # Create box plot with jittered points. This better matches the discrete
  # response deviations than a smoothed density plot.
  p <- plot_ly(dat,
    x = ~profile,
    y = ~deviation,
    color = ~profile,
    type = "box",
    colors = viridis_pal(option = "C", direction = -1)(num_profiles),
    boxpoints = "all",
    jitter = 0.42,
    pointpos = 0,
    marker = list(size = 5, opacity = 0.46, line = list(width = 0)),
    line = list(color = "#17211d", width = 1),
    fillcolor = "rgba(0, 146, 96, 0.16)",
    hovertemplate = paste(
      "<b>%{x}</b>",
      "<br>Deviation: %{y}",
      "<extra></extra>"
    )
  ) |>
    layout(
      font = plot_font,
      paper_bgcolor = "white",
      plot_bgcolor = "white",
      margin = list(l = 70, r = 25, t = 30, b = 80),
      showlegend = FALSE,
      yaxis = list(
        title = list(text = "Replication minus initial response", font = axis_title_font),
        gridcolor = "#d8dfdc",
        zerolinecolor = "#7f8990",
        zerolinewidth = 1.5
      ),
      xaxis = list(
        title = list(text = "Profile", font = axis_title_font),
        categoryarray = levels(dat$profile),
        categoryorder = "array",
        tickangle = -35,
        gridcolor = "#ffffff",
        zerolinecolor = "#ffffff"
      )
    ) |>
    app_plotly_config(filename = plot_name)
  # Return plot
  return(p)
}


## ICC effect plot

# This function creates an icc effect plot
icc_effect_plot <- function(dat) {
  
  # Create x-axis tick labels
  dat <- dat |>
    mutate(profile = paste0("Profile ", profile))

  # Create the plot
  plot <- ggplot(
    data = dat,
    aes(
      x = profile,
      y = ICC,
      ymin = icc_lower,
      ymax = icc_upper
    )
  ) +
    geom_hline(yintercept = c(0.5, 0.75), color = "#d8dfdc", linewidth = 0.35) +
    geom_pointrange(color = "#009260", linewidth = 0.55, fatten = 2) +
    geom_text(aes(label = ICC), family = "Arial", nudge_x = 0.28, size = 3.8, color = "#17211d") +
    labs(
      title = "ICC(3,k) by Profile",
      subtitle = "Vertical lines show 95% confidence intervals",
      x = NULL,
      y = "ICC(3,k)"
    ) +
    theme_minimal(base_family = "Arial", base_size = 12) +
    theme(
      plot.background = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA),
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_line(color = "#d8dfdc", linewidth = 0.35),
      plot.title = element_text(face = "bold", size = 15, color = "#17211d"),
      plot.subtitle = element_text(size = 11, color = "#5f6b66"),
      axis.title.y = element_text(size = 12, color = "#17211d"),
      axis.text.x = element_text(size = 10, color = "#17211d", angle = 35, hjust = 1),
      axis.text.y = element_text(size = 10, color = "#17211d")
    )

  # Return plot
  return(plot)
}


## Slope difference effect plot

# This function creates a slope difference effect plot
slope_effect_plot <- function(dat) {
  dat <- dat |>
    mutate(
      iv = prettify_attribute_label(iv),
      direction = if_else(test_statistic >= 0, "Different", "Not different"),
      label_hjust = if_else(test_statistic >= 0, -0.15, 1.15)
    )

  # Create the plot
  plot <- ggplot(data = dat, aes(x = reorder(iv, test_statistic), y = test_statistic, fill = direction)) +
    geom_col(width = 0.62) +
    geom_text(aes(label = test_statistic, hjust = label_hjust), family = "Arial", size = 3.6, color = "#17211d") +
    coord_flip() +
    geom_hline(yintercept = 0, linewidth = 0.6, color = "#17211d") +
    scale_fill_manual(values = c("Different" = "#009260", "Not different" = "#b8c4bf")) +
    labs(
      title = "Slope Difference Test",
      subtitle = "Values at or above zero indicate a statistically meaningful slope difference",
      y = "Test Statistic",
      x = NULL
    ) +
    theme_minimal(base_family = "Arial", base_size = 12) +
    theme(
      plot.background = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA),
      panel.grid.major.y = element_blank(),
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_line(color = "#d8dfdc", linewidth = 0.35),
      legend.position = "none",
      plot.title = element_text(face = "bold", size = 15, color = "#17211d"),
      plot.subtitle = element_text(size = 11, color = "#5f6b66"),
      axis.title.x = element_text(size = 12, color = "#17211d"),
      axis.text.x = element_text(size = 10, color = "#17211d"),
      axis.text.y = element_text(size = 10, color = "#17211d")
    ) +
    expand_limits(
      y = c(
        min(dat$test_statistic, na.rm = TRUE) - 0.15,
        max(dat$test_statistic, na.rm = TRUE) + 0.15
      )
    )

  # Return plot
  return(plot)
}
