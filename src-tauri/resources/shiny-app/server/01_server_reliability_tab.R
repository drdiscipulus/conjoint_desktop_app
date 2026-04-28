# Create a session-specific directory for generated files
session_dir <- create_session_dir(session)
session$onSessionEnded(function() {
  cleanup_session_dir(session_dir)
})

# Set reactive values to handle input data, check status, and compute status
# dat: makes the read dataset available and editable between functions
# check and compute: are both used as triggers/blocks
rv <- reactiveValues(
  dat = NULL,
  check = NULL,
  compute = NULL,
  reset = FALSE,
  upload_error = NULL,
  check_error = NULL,
  dropped_profiles = FALSE,
  inspect = NULL
)
shinyjs::disable("check_data")
shinyjs::disable("compute")
shinyjs::disable("reset")
shinyjs::disable("show_table")
shinyjs::disable("show_class")
shinyjs::disable("download_results_xlsx")
shinyjs::disable("download_results_csv")


# Download csv demo data set
output$download_csv <- downloadHandler(
  filename = function() {
    # Set file name
    paste0("demo_data.csv")
  },
  content = function(file) {
    # Read file from disk and write it to user
    write.csv(read.csv("demo_data.csv"), row.names = FALSE, file)
  }
)


# Download xlsx demo data set
output$download_xlsx <- downloadHandler(
  filename = function() {
    # Set file name
    paste0("demo_data.xlsx")
  },
  content = function(file) {
    # Read file from disk and write it to user
    openxlsx::write.xlsx(openxlsx::read.xlsx("demo_data.xlsx"), file)
  }
)


# Download computed reliability results as an Excel workbook
output$download_results_xlsx <- downloadHandler(
  filename = function() {
    "conjoint_reliability_results.xlsx"
  },
  content = function(file) {
    ensure_analysis_ready(rv)
    internal_file <- session_file_path(session_dir, "results.xlsx")
    write_reliability_results_xlsx(
      path = internal_file,
      reliability_table = rel_table(),
      reliability_mean = rel_string(),
      slope_difference_table = slope_difference_res(),
      pooled_regression_table = pooled_reg_data()$dat,
      pooled_regression_fit = pooled_reg_data()$fit
    )
    file.copy(internal_file, file, overwrite = TRUE)
  }
)


# Download computed reliability results as CSV files in one zip archive
output$download_results_csv <- downloadHandler(
  filename = function() {
    "conjoint_reliability_results_csv.zip"
  },
  content = function(file) {
    ensure_analysis_ready(rv)
    internal_file <- session_file_path(session_dir, "results_csv.zip")
    write_reliability_results_csv_zip(
      path = internal_file,
      reliability_table = rel_table(),
      reliability_mean = rel_string(),
      slope_difference_table = slope_difference_res(),
      pooled_regression_table = pooled_reg_data()$dat,
      pooled_regression_fit = pooled_reg_data()$fit
    )
    file.copy(internal_file, file, overwrite = TRUE)
  }
)


# Upload a .csv or .xlsx file
# This function tries to read a supplied .csv or .xlsx file
# Throws a warning or error if something is wrong with the file
observeEvent(input$upload_data, {
  # Set check button to null when new data is uploaded
  rv$check <- NULL
  # Set compute button to null when new data is uploaded
  rv$compute <- NULL
  # Set data to null when new data is uploaded
  rv$dat <- NULL
  rv$check_error <- NULL
  rv$dropped_profiles <- FALSE
  rv$inspect <- NULL
  shinyjs::disable("check_data")
  shinyjs::disable("compute")
  shinyjs::disable("reset")
  shinyjs::disable("show_table")
  shinyjs::disable("show_class")

  # If an uploaded file exists
  if (!is.null(input$upload_data)) {
    upload_res <- file_upload(input$upload_data)
    shinyjs::disable("download_results_xlsx")
    shinyjs::disable("download_results_csv")

    if (inherits(upload_res, "try-error")) {
      rv$upload_error <- conditionMessage(attr(upload_res, "condition"))
      rv$dat <- NULL
    } else {
      rv$upload_error <- NULL
      rv$dat <- upload_res
      shinyjs::enable("check_data")
      shinyjs::enable("reset")
      shinyjs::enable("show_table")
      shinyjs::enable("show_class")
    }
  }
})


# Show compact workflow states under their corresponding sidebar steps
output$upload_status <- renderUI({
  if (!is.null(rv$upload_error)) {
    return(tags$div(class = "status-badge status-error", icon("exclamation-triangle"), rv$upload_error))
  }
  if (!is.null(rv$dat) || !is.null(input$upload_data)) {
    return(tags$div(class = "status-badge status-uploaded", icon("file-alt"), "File uploaded"))
  }
  NULL
})

output$check_status <- renderUI({
  if (!is.null(rv$check_error)) {
    return(tags$div(class = "status-badge status-error", icon("exclamation-triangle"), rv$check_error))
  }
  if (!is.null(rv$check) && rv$check == "okay") {
    if (isTRUE(rv$dropped_profiles)) {
      return(tags$div(class = "status-badge status-checked", icon("check"), "Data validated; non-replicated profiles removed"))
    }
    return(tags$div(class = "status-badge status-checked", icon("check"), "Data validated"))
  }
  NULL
})

output$workflow_status <- renderUI({
  if (!is.null(rv$compute) && rv$compute == "go") {
    return(tags$div(class = "status-badge status-complete", icon("check"), "Analysis complete"))
  }
  NULL
})

output$results_status <- renderUI({
  if (!is.null(rv$compute) && rv$compute == "go") {
    return(tags$div(class = "status-badge status-complete", icon("download"), "Downloads ready"))
  }
  NULL
})


# Show uploaded data inline when the table inspect button is pressed
observeEvent(input$show_table, {
  req(rv$dat)
  rv$inspect <- "table"
})


# Show variable classes/types inline when the type inspect button is pressed
observeEvent(input$show_class, {
  req(rv$dat)
  rv$inspect <- "types"
})


# Evaluate the uploaded data against the reliability workflow requirements
observeEvent(input$check_data, {
  if (is.null(input$upload_data)) {
    rv$check_error <- "Upload a file first"
    return(NULL)
  } else if (!file.exists(input$upload_data$datapath)) {
    rv$check_error <- "Upload the file again"
    return(NULL)
  } else if (is.null(rv$dat)) {
    rv$check_error <- rv$upload_error %||% "No file could be read"
    return(NULL)
  }

  validation <- try(validate_reliability_dataset(rv$dat), silent = TRUE)
  if (inherits(validation, "try-error")) {
    rv$dat <- NULL
    rv$check <- NULL
    rv$check_error <- conditionMessage(attr(validation, "condition"))
    rv$dropped_profiles <- FALSE
    shinyjs::disable("compute")
    return(NULL)
  }

  rv$dat <- validation$data
  rv$check <- "okay"
  rv$check_error <- NULL
  rv$dropped_profiles <- isTRUE(validation$dropped_profiles)
  shinyjs::enable("compute")
})


# Observe if the compute button is pressed
observeEvent(input$compute, {
  # Check if the check went well
  if (is.null(rv$check)) {
    rv$check_error <- "Validate the uploaded data first"
    return(NULL)
  } else {
    rv$compute <- "go"
    shinyjs::enable("download_results_xlsx")
    shinyjs::enable("download_results_csv")
  }
})


# Function to get the iccs per profile as a table
icc_table <- reactive({
  # Check data availability and status
  req(rv$dat, rv$check, rv$compute)

  # If compute is go
  if (rv$compute == "go") {
    # Call icc function
    res <- rel_icc(rv$dat)

    # Return icc table
    return(res)
  }
}) |> bindEvent(input$compute)


# Create a table with test-retest reliabilities per profile
rel_table <- reactive({
  # Check data availability and status
  req(rv$dat, rv$check, rv$compute)

  # If compute is go
  if (rv$compute == "go") {
    # Call correlation function
    cor_res <- rel_cor(rv$dat)

    # Get results from icc_table
    icc_res <- icc_table()

    # Create a data frame with correlation data
    cor_res <- tibble(profile = unique(rv$dat$profile), r = round(cor_res, 2))

    # Join correation and icc data
    res <- left_join(cor_res, icc_res, by = "profile")

    # Return reliability table
    return(res)
  }
}) |> bindEvent(input$compute)


# Create a string with mean reliabilities to be shown under the reliability table
rel_string <- reactive({
  # Check data availability and status
  req(rv$dat, rv$check, rv$compute)

  # If compute is go
  if (rv$compute == "go") {
    # Get the reliability table and compute column means
    cor_mean <- round(mean(rel_table()$r), 2)
    icc_mean <- round(mean(rel_table()$ICC), 2)

    # Set up the mean string
    res_text <- paste0("The mean test-retest reliability is: r = ", cor_mean, "; ICC(3,k) = ", icc_mean)

    # Return the mean string
    return(res_text)
  }
}) |> bindEvent(input$compute)


# Create footer note for reliability table
output$reliability_note <- renderText({
  # Check data availability and status
  req(rv$dat, rv$check, rv$compute)

  # If compute is go
  if (rv$compute == "go") {
    # Set up the mean string
    res_text <- paste0("Note: Profiles = Respective profile number;
                       r = Pearson's r;
                       ICC(3k) = Intraclass correlation coefficient 3k;
                       ICC(3k) lb = 95% CI lower bound of the ICC(3k);
                       ICC(3k) ub = 95% CI upper bound of the ICC(3k).")

    # Return the mean string
    return(res_text)
  }
}) |> bindEvent(input$compute)


# Render the reliability table with reactable
output$reliability_table <- renderReactable({
  # Check data availability and status
  req(rv$dat, rv$check, rv$compute)

  # If compute is go
  if (rv$compute == "go") {
    
    # Create reactable
    reactable(rel_table(),
      highlight = TRUE,
      striped = TRUE,
      bordered = TRUE,
      compact = TRUE,
      # Table theming
      theme = app_reactable_theme(),
      # Edit columns
      columns = list(
        profile = colDef(name = "Profiles", minWidth = 85, align = "center"),
        r = colDef(minWidth = 70),
        ICC = colDef(name = "ICC(3k)", minWidth = 90),
        icc_upper = colDef(name = "ICC(3k) ub", minWidth = 120),
        icc_lower = colDef(name = "ICC(3k) lb", minWidth = 120)
      ),
      style = list(minWidth = 485)
    )
  }
}) |> bindEvent(input$compute)


# Render the mean reliabilities string as text output
output$reliability_mean <- renderText({
  # Check data availability and status
  req(rv$dat, rv$check, rv$compute)

  # If compute is go
  if (rv$compute == "go") {
    # Output string as text
    rel_string()
  }
}) |> bindEvent(input$compute)


# Call the function to compute slope difference tests
slope_difference_res <- reactive({
  # Check data availability and status
  req(rv$dat, rv$check, rv$compute)

  # If compute is go
  if (rv$compute == "go") {
    # Get slope differences
    res <- slope_difference(rv$dat)
  }
}) |> bindEvent(input$compute)


# Render slope difference table as a reactable
output$slope_diff_table <- renderReactable({
  # Check data availability and status
  req(rv$dat, rv$check, rv$compute)

  # If compute is go
  if (rv$compute == "go") {
    
    # Setup the reactable
    reactable(slope_difference_res(),
      highlight = TRUE,
      striped = TRUE,
      bordered = TRUE,
      compact = TRUE,
      # table theming
      theme = app_reactable_theme(),
      # Change some columns
      columns = list(
        iv = colDef(name = "IV", minWidth = 105, cell = function(value) prettify_attribute_label(value)),
        beta_i = colDef(name = "Beta 1", minWidth = 75),
        se_i = colDef(name = "SE 1", minWidth = 70),
        p_i = colDef(name = "p-val 1", minWidth = 80),
        beta_r = colDef(name = "Beta 2", minWidth = 75),
        se_r = colDef(name = "SE 2", minWidth = 70),
        p_r = colDef(name = "p-val 2", minWidth = 80),
        beta_diff = colDef(name = "Beta Diff", minWidth = 90),
        joint_se = colDef(name = "Joint SE", minWidth = 90),
        test_statistic = colDef(name = "Test Statistic", minWidth = 125),
        stat_diff = colDef(name = "Difference", minWidth = 105)
      ),
      style = list(minWidth = 965)
    )
  }
}) |> bindEvent(input$compute)


# Create footer note for reliability table
output$slope_note <- renderText({
  # Check data availability and status
  req(rv$dat, rv$check, rv$compute)

  # If compute is go
  if (rv$compute == "go") {
    # Set up the mean string
    res_text <- paste0("Note: 1 designates the first round of responses and 2 the replication round;
                       IV = Independent variables, these are the attributes;
                       Beta = Unstandardized regression coefficient;
                       SE = Standard error;
                       p-val = Exact p-value rounded to the 4th decimal;
                       Beta Diff = Beta difference between round 1 and 2;
                       Joint SE = Standard error of the difference;
                       Test Statistic = Corresponding test statistic;
                       Difference = Whether the beta difference is significant (Yes) or not (No).")

    # Return the mean string
    return(res_text)
  }
}) |> bindEvent(input$compute)


# Call function to compute a pooled regression model
pooled_reg_data <- reactive({
  # Check data availability and status
  req(rv$dat, rv$check, rv$compute)

  # If compute is go
  if (rv$compute == "go") {
    # Compute pooled regression model
    res <- pooled_regression(rv$dat)
  }
}) |> bindEvent(input$compute)


# Render the pooled regression table as a reactable
output$pooled_reg_table <- renderReactable({
  # Check data availability and status
  req(rv$dat, rv$check, rv$compute)

  # If compute is go
  if (rv$compute == "go") {
    
    custom_width <- ncol(pooled_reg_data()$dat) * 100 + 2
    
    # Set up the reactable
    reactable(pooled_reg_data()$dat,
      highlight = TRUE,
      striped = TRUE,
      bordered = TRUE,
      compact = TRUE,
      # table theming
      theme = app_reactable_theme(),
      defaultColDef = colDef(
        align = "center",
        minWidth = 105
      ),
      columns = list(
        Coefficient = colDef(cell = function(value) prettify_attribute_label(value))
      ),
      style = list(minWidth = custom_width)
    )
  }
}) |> bindEvent(input$compute)


# Render the model fit of the pooled regression model as a text output
output$regression_fit <- renderText({
  # Check data availability and status
  req(rv$dat, rv$check, rv$compute)

  # If compute is go
  if (rv$compute == "go") {
    # Output model fit as text
    pooled_reg_data()$fit
  }
}) |> bindEvent(input$compute)


# Create footer note for reliability table
output$regression_note <- renderText({
  # Check data availability and status
  req(rv$dat, rv$check, rv$compute)

  # If compute is go
  if (rv$compute == "go") {
    # Set up the mean string
    res_text <- paste0("Note: Coefficient = Variable names/the attributes;
                       Beta = Unstandardized regression coefficient;
                       SE = Two-way cluster robust standard errors;
                       t-ratio = Corresponding test statistic;
                       p-val = Exact p-value rounded to the 4th decimal.")

    # Return the mean string
    return(res_text)
  }
}) |> bindEvent(input$compute)


# Create a deviation plot with plotly and render and output it
output$deviation_plot <- renderPlotly({
  # Check data availability and status
  req(rv$dat, rv$check, rv$compute)

  # If compute is go
  if (rv$compute == "go") {
    # Compute response deviations between round 1 and 2
    df_dev <- compute_deviation(dat = rv$dat)

    # Pivot the deviation data from wide to long
    df_dev <- wide_to_long(dat = df_dev)

    # Create the deviation plot
    deviation_plot(
      dat = df_dev,
      num_profiles = length(unique(rv$dat$profile)),
      plot_name = "deviation_plot"
    )
  }
}) |> bindEvent(input$compute)


# Create an icc summary plot and render it as a plotly plot
output$icc_plot <- renderPlotly({
  # Check data availability and status
  req(rv$dat, rv$check, rv$compute)

  # If compute is go
  if (rv$compute == "go") {
    # Get icc table from function
    icc_res <- icc_table()

    # Create icc effect plot with that data
    icc_res <- icc_effect_plot(icc_res)

    # Convert ggplot plot to plotly
    ggplotly(icc_res, tooltip = c("x", "y")) |>
      layout(
        showlegend = FALSE,
        margin = list(l = 70, r = 25, t = 70, b = 90),
        paper_bgcolor = "white",
        plot_bgcolor = "white"
      ) |>
      app_plotly_config(filename = "icc_summary_plot")
  }
}) |> bindEvent(input$compute)


# Create a slope difference plot and render it as a potly plot
output$slope_plot <- renderPlotly({
  # Check data availability and status
  req(rv$dat, rv$check, rv$compute)

  # If compute is go
  if (rv$compute == "go") {
    # Get slope difference table from function
    slope_res <- slope_difference_res()

    # Create slope difference plot with that data
    slope_res <- slope_effect_plot(slope_res)

    # Convert ggplot plot to plotly
    ggplotly(slope_res, tooltip = c("x", "y")) |>
      layout(
        showlegend = FALSE,
        margin = list(l = 110, r = 35, t = 70, b = 70),
        paper_bgcolor = "white",
        plot_bgcolor = "white"
      ) |>
      app_plotly_config(filename = "slope_difference_plot")
  }
}) |> bindEvent(input$compute)


# Reset status and delete uploaded data
observeEvent(input$reset, {
  if (!is.null(input$upload_data) && file.exists(input$upload_data$datapath)) {
    file.remove(input$upload_data$datapath)
  }

  cleanup_session_dir(session_dir)
  dir.create(session_dir, recursive = TRUE, showWarnings = FALSE)

  shinyjs::reset("upload_data")
  rv$dat <- NULL
  rv$check <- NULL
  rv$compute <- NULL
  rv$reset <- FALSE
  rv$upload_error <- NULL
  rv$check_error <- NULL
  rv$dropped_profiles <- FALSE
  rv$inspect <- NULL
  shinyjs::disable("check_data")
  shinyjs::disable("compute")
  shinyjs::disable("reset")
  shinyjs::disable("show_table")
  shinyjs::disable("show_class")
  shinyjs::disable("download_results_xlsx")
  shinyjs::disable("download_results_csv")
})


# Render top row ui
output$inspect_row <- renderUI({
  req(rv$inspect, rv$dat)

  if (rv$inspect == "table") {
    return(
      div(
        class = "result-panel inspect-panel",
        div(
          class = "inspect-panel-header",
          h3("Inspect uploaded data set"),
          actionButton("close_inspect", "Close", class = "btn-info btn-sm", icon = icon("times"))
        ),
        p("Use the empty boxes to search columns for values."),
        reactableOutput("inspect_table_inline")
      )
    )
  }

  div(
    class = "result-panel inspect-panel",
    div(
      class = "inspect-panel-header",
      h3("Inspect data classes and types"),
      actionButton("close_inspect", "Close", class = "btn-info btn-sm", icon = icon("times"))
    ),
    reactableOutput("inspect_types_inline")
  )
})

output$inspect_table_inline <- renderReactable({
  req(rv$dat, rv$inspect == "table")
  reactable(rv$dat,
    highlight = TRUE,
    striped = TRUE,
    bordered = TRUE,
    compact = TRUE,
    defaultPageSize = 10,
    filterable = TRUE,
    columns = attribute_column_defs(rv$dat),
    theme = app_reactable_theme()
  )
})

output$inspect_types_inline <- renderReactable({
  req(rv$dat, rv$inspect == "types")
  reactable(class_type_overview(rv$dat),
    highlight = TRUE,
    striped = TRUE,
    bordered = TRUE,
    compact = TRUE,
    defaultPageSize = 10,
    columns = list(
      Variable = colDef(cell = function(value) prettify_attribute_label(value))
    ),
    theme = app_reactable_theme()
  )
})

observeEvent(input$close_inspect, {
  rv$inspect <- NULL
})


table_note_panel <- function(output_id) {
  tags$details(
    class = "table-notes",
    tags$summary("Table notes"),
    textOutput(output_id)
  )
}


# Render top row ui
output$top_row <- renderUI({
  if (is.null(rv$compute) || rv$compute != "go") {
    uploaded <- !is.null(rv$dat)
    validated <- !is.null(rv$check) && rv$check == "okay"
    
    title <- if (!uploaded) {
      "Upload Data To Begin"
    } else if (!validated) {
      "File Uploaded"
    } else {
      "Ready To Run Analysis"
    }
    
    detail <- if (!uploaded) {
      "Upload a CSV or XLSX file, then validate its structure before running the analysis."
    } else if (!validated) {
      "Validate the uploaded file to check required columns, numeric fields, and round/profile requirements."
    } else {
      "The file passed validation. Run the analysis to generate tables, downloads, and plots."
    }
    
    return(
      div(
        class = "result-placeholder result-placeholder-state",
        h3(title),
        p(detail)
      )
    )
  }
  
  div(
    class = "result-panel",
    # Define tabs
    tabsetPanel(
      # First tab
      tabPanel(
        # Show reliabilities
        "Reliabilities",
        reactableOutput("reliability_table") %>% withSpinner(type = 6, color = "#009260"),
        tags$div(class = "result-summary", textOutput("reliability_mean")),
        table_note_panel("reliability_note")
      ),
      # Second panel
      tabPanel(
        # Show slope difference tests
        "Slope Difference",
        reactableOutput("slope_diff_table") %>% withSpinner(type = 6, color = "#009260"),
        table_note_panel("slope_note")
      ),
      # Third panel
      tabPanel(
        # Show pooled regression results
        "Pooled Regression",
        reactableOutput("pooled_reg_table") %>% withSpinner(type = 6, color = "#009260"),
        tags$div(class = "result-summary", textOutput("regression_fit")),
        table_note_panel("regression_note")
      )
    )
  )
})


# Render bottom row
output$bottom_row <- renderUI({
  if (is.null(rv$compute) || rv$compute != "go") {
    return(
      div(
        class = "result-placeholder result-placeholder-secondary",
        h3("Plots"),
        p("Deviation, ICC summary, and slope-difference plots appear here after the analysis runs.")
      )
    )
  }
  
  div(
    class = "result-panel result-panel-plots",
    tabsetPanel(
      # First tab
      tabPanel(
        # Show deviation plot
        "Deviation Plot",
        plotlyOutput("deviation_plot") %>% withSpinner(type = 6, color = "#009260")
      ),
      # Second panel
      tabPanel(
        # Show icc summary plot
        "ICC Summary Plot",
        plotlyOutput("icc_plot") %>% withSpinner(type = 6, color = "#009260"),
      ),
      # Third panel
      tabPanel(
        # Show slope difference plot
        "Slope Difference Plot",
        plotlyOutput("slope_plot") %>% withSpinner(type = 6, color = "#009260"),
      )
    )
  )
})
