shinyjs::disable("download_n_level_csv")
shinyjs::disable("download_n_level_xlsx")

observe({
  if (identical(input$design_n, "Full")) {
    shinyjs::disable("effects_n")
  } else {
    shinyjs::enable("effects_n")
  }
})

n_level_error <- reactiveVal(NULL)

set_n_level_failure <- function(message) {
  n_level_error(message)
  shinyjs::disable("download_n_level_csv")
  shinyjs::disable("download_n_level_xlsx")
  NULL
}

output$n_level_status <- renderUI({
  if (!is.null(n_level_error())) {
    return(tags$div(class = "status-badge status-error", icon("exclamation-triangle"), n_level_error()))
  }
  if (input$generate_n > 0 && !is.null(get_n_level_factorial()$table)) {
    return(tags$div(class = "status-badge status-complete", icon("check"), "Design generated"))
  }
  NULL
})

# Try to get factorial design when button is pressed
get_n_level_factorial <- reactive({
  # Get separators
  separator <- unlist(str_match_all(input$attributes_n, "[:punct:]"))

  # Get number of attributes
  attributes <- unlist(strsplit(input$attributes_n, ","))

  # If attributes are numeric
  attributes_numeric <- unlist(str_match_all(attributes, "[:digit:]"))

  # Throw an error if separators are not all commas
  if (length(separator) != sum(str_count(separator, ","))) {
    res <- set_n_level_failure("Use commas as separators, for example 3,3,3.")
    # Throw error if not all attributes are numeric
  } else if (length(attributes) != length(attributes_numeric)) {
    res <- set_n_level_failure("All attributes must be numeric level counts.")
    # Throw errors if there are less than 2 or more than 7 attributes
  } else if (length(attributes) < 2) {
    res <- set_n_level_failure("Use at least 2 attributes.")
  } else if (length(attributes) > 7) {
    res <- set_n_level_failure("Use no more than 7 attributes.")
    # No more than 4 levels and less than 2 levels allowed
  } else if (max(attributes) > 4) {
    res <- set_n_level_failure("Use no more than 4 levels per attribute.")
  } else if (min(attributes) < 2) {
    res <- set_n_level_failure("Use at least 2 levels per attribute.")
  } else if (input$design_n == "Fractional") {
    # Try to obtain result
    res <- try(get_n_level_fractional(
      attributes = input$attributes_n,
      criterion = input$effects_n
    ), silent = TRUE)

    if (inherits(res, "try-error")) {
      res <- set_n_level_failure("No solution could be found for these settings.")
    } else {
      n_level_error(NULL)
      shinyjs::enable("download_n_level_csv")
      shinyjs::enable("download_n_level_xlsx")
      res
    }
  } else if (input$design_n == "Full") {
    # Try to obtain result
    res <- try(get_n_level_full(
      attributes = input$attributes_n
    ), silent = TRUE)

    if (inherits(res, "try-error")) {
      res <- set_n_level_failure("No solution could be found for these settings.")
    } else {
      n_level_error(NULL)
      shinyjs::enable("download_n_level_csv")
      shinyjs::enable("download_n_level_xlsx")
      res
    }
  }
}) |> bindEvent(input$generate_n)


output$download_n_level_csv <- downloadHandler(
  filename = function() {
    "n_level_factorial_design.csv"
  },
  content = function(file) {
    req(get_n_level_factorial()$table)
    readr::write_csv(get_n_level_factorial()$table, file)
  }
)


output$download_n_level_xlsx <- downloadHandler(
  filename = function() {
    "n_level_factorial_design.xlsx"
  },
  content = function(file) {
    req(get_n_level_factorial()$table)
    openxlsx::write.xlsx(get_n_level_factorial()$table, file, overwrite = TRUE)
  }
)

n_level_coverage_data <- reactive({
  req(get_n_level_factorial()$table)
  n_level_interaction_coverage(
    get_n_level_factorial()$table,
    n_level_attribute_counts(input$attributes_n)
  )
}) |> bindEvent(input$generate_n)


n_level_design_metadata_data <- reactive({
  req(get_n_level_factorial()$table)
  n_level_design_metadata(
    requested_design_type = input$design_n,
    attributes = input$attributes_n,
    design_table = get_n_level_factorial()$table
  )
}) |> bindEvent(input$generate_n)


output$n_level_design_summary <- renderUI({
  req(n_level_design_metadata_data())
  metadata <- n_level_design_metadata_data()
  reduction_label <- if (metadata$reduction_achieved) "Yes" else "No"

  div(
    class = "result-summary",
    div(
      class = "result-meta-strip",
      div(class = "result-meta-item", span("Levels"), strong(metadata$levels_per_attribute)),
      div(class = "result-meta-item", span("Full Size"), strong(metadata$full_factorial_size)),
      div(class = "result-meta-item", span("Generated"), strong(metadata$generated_n_profiles)),
      div(class = "result-meta-item", span("Reduction"), strong(reduction_label))
    ),
    if (metadata$effectively_full_factorial) {
      tags$div(
        class = "inline-callout inline-callout-warning",
        icon("exclamation-triangle"),
        tags$span(
          paste0(
            "Fractional design was selected, but ",
            metadata$levels_per_attribute,
            " = ",
            metadata$full_factorial_size,
            " possible profiles and the generated design also contains ",
            metadata$generated_n_profiles,
            " profiles. No profile reduction was achieved under the current N-level design constraints."
          )
        )
      )
    } else if (metadata$reduction_achieved) {
      NULL
    }
  )
}) |> bindEvent(input$generate_n)


output$n_level_coverage_summary <- renderText({
  req(n_level_coverage_data())
  req(n_level_design_metadata_data())
  coverage <- n_level_coverage_data()
  metadata <- n_level_design_metadata_data()
  profile_count <- nrow(get_n_level_factorial()$table)
  lower_bound <- max(coverage$minimum_profiles)
  works <- sum(coverage$status == "works")
  total <- nrow(coverage)

  paste0(
    "This table checks whether each pair of attributes covers all possible level combinations and whether those combinations are balanced. It does not describe classical fractional-factorial aliasing. ",
    if (metadata$effectively_full_factorial || input$design_n == "Full") {
      "Because the generated design is full factorial, all two-way level combinations are observed and balanced by construction. "
    } else {
      ""
    },
    works, " of ", total,
    " attribute pairs are fully observed and balanced. The design has ",
    profile_count, " profiles. The largest two-way level combination contains ",
    lower_bound,
    " cells. At least ", lower_bound,
    " profiles are needed to observe each of those cells once. A balanced design across all attribute pairs may require more profiles."
  )
}) |> bindEvent(input$generate_n)


output$n_level_coverage_table <- renderReactable({
  req(n_level_coverage_data())

  reactable(n_level_coverage_data(),
    highlight = TRUE,
    striped = TRUE,
    bordered = TRUE,
    compact = TRUE,
    defaultPageSize = 10,
    theme = app_reactable_theme(),
    defaultColDef = colDef(
      align = "left",
      minWidth = 0
    ),
    columns = list(
      interaction = colDef(
        name = "Interaction",
        minWidth = 0,
        class = "coverage-col-interaction",
        headerClass = "coverage-col-interaction"
      ),
      status = colDef(
        name = "Status",
        minWidth = 0,
        class = "coverage-col-status",
        headerClass = "coverage-col-status",
        cell = function(value) {
          tags$span(
            class = paste("coverage-status", paste0("coverage-status-", gsub(" ", "-", value, fixed = TRUE))),
            value
          )
        }
      ),
      observed_combinations = colDef(
        name = "Observed",
        minWidth = 0,
        class = "coverage-col-metric",
        headerClass = "coverage-col-metric",
        align = "center"
      ),
      minimum_profiles = colDef(
        name = "Lower Bound",
        minWidth = 0,
        class = "coverage-col-metric",
        headerClass = "coverage-col-metric",
        align = "center"
      ),
      min_cell_count = colDef(
        name = "Min Count",
        minWidth = 0,
        class = "coverage-col-metric",
        headerClass = "coverage-col-metric",
        align = "center"
      ),
      max_cell_count = colDef(
        name = "Max Count",
        minWidth = 0,
        class = "coverage-col-metric",
        headerClass = "coverage-col-metric",
        align = "center"
      ),
      interpretation = colDef(
        name = "Interpretation",
        minWidth = 0,
        class = "coverage-col-interpretation",
        headerClass = "coverage-col-interpretation"
      )
    )
  )
}) |> bindEvent(input$generate_n)


# render table for n-level fractional
output$n_level_table <- renderReactable({
  
  # Proceed if not null
  req(get_n_level_factorial()$table)

  custom_width <- 95 + ((ncol(get_n_level_factorial()$table) - 1) * 120) + 2
  
  reactable(get_n_level_factorial()$table,
    highlight = TRUE,
    striped = TRUE,
    bordered = TRUE,
    compact = TRUE,
    defaultPageSize = 16,
    # Table theming
    theme = app_reactable_theme(),
    defaultColDef = colDef(
      align = "center",
      minWidth = 80,
    ),
    columns = attribute_column_defs(get_n_level_factorial()$table),
    style = list(maxWidth = custom_width)
  )
}) |> bindEvent(input$generate_n)


# Render the ui
output$n_level <- renderUI({
  if (input$generate_n == 0) {
    return(factorial_placeholder(
      "Generate An N-Level Design",
      "Enter level counts such as 3,3,4,4, then generate a mixed-level design to inspect profiles and pairwise coverage."
    ))
  }
  
  if (is.null(get_n_level_factorial()$table)) {
    return(factorial_placeholder(
      "No Design Generated",
      "Adjust the design settings and generate again.",
      n_level_error()
    ))
  }
  
  div(
    class = "result-panel factorial-result-panel",
    # Define tabs
    tabsetPanel(
      # First tab
      tabPanel(
        # Show factorial design
        "Factorial Design",
        uiOutput("n_level_design_summary"),
        reactableOutput("n_level_table") %>% withSpinner(type = 6, color = "#009260")
      ),
      tabPanel(
        "Interaction Coverage",
        div(
          class = "n-level-coverage-panel",
          div(class = "result-summary", textOutput("n_level_coverage_summary")),
          reactableOutput("n_level_coverage_table") %>% withSpinner(type = 6, color = "#009260")
        )
      )
    )
  )
}) |> bindEvent(input$generate_n)
