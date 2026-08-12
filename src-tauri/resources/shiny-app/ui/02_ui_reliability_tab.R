# Tab 2 is a navbar menu showing all analysis results
tabPanel(
  # Set the title of the Panel
  title = "Test-Retest Reliability",
  # Layout of the first element: sidebar layout
  sidebarLayout(
    # Define the input panel
    sidebarPanel(
      # Styling and positioning
      width = 2,
      class = "workflow-sidebar",
      h5("1. Upload", help_icon("Start here: upload a CSV or one-sheet XLSX file. Maximum upload size: 5 MB. Reliability datasets are limited to 25,000 rows. Use long-format data with respondent, round, profile, dv, and att_ columns. After upload, you can view the data table or detected variable types.")),
      # Upload .csv file handling
      fileInput("upload_data", "Data file",
        accept = c(
          "text/csv",
          "text/comma-separated-values,text/plain",
          ".csv", ".xlsx"
        ), width = "100%", multiple = FALSE
      ),
      uiOutput("upload_status"),
      div(
        class = "sidebar-button-row",
        actionButton("show_table", "View", class = "btn-info", icon = icon("list-alt"), `data-tooltip` = "Requirement: upload a readable file first."),
        actionButton("show_class", "Types", class = "btn-info", icon = icon("tags"), `data-tooltip` = "Requirement: upload a readable file first.")
      ),
      hr(),
      # Validate data handling
      h5("2. Validate", help_icon("Requirement: upload a readable CSV or XLSX file first. This step validates required columns, identifiers, duplicate keys, profile consistency, and complete respondent/profile pairing across rounds.")),
      actionButton("check_data", "Validate data", class = "btn-primary", width = "100%", icon = icon("search"), `data-tooltip` = "Requirement: upload a readable CSV or XLSX file first."),
      uiOutput("check_status"),
      hr(),
      # Start analysis handling
      h5("3. Analysis", help_icon("Requirement: validate the uploaded data first. This step computes reliability tables, slope-difference checks, pooled regression results, and plots.")),
      actionButton("compute", "Run analysis", class = "btn-primary", width = "100%", icon = icon("play"), `data-tooltip` = "Requirement: validate the uploaded data first."),
      uiOutput("workflow_status"),
      hr(),
      h5("4. Results", help_icon("Requirement: run the analysis first. Downloads are enabled after the reliability results are computed.")),
      downloadButton("download_results_csv", "CSV", width = "100%"),
      downloadButton("download_results_xlsx", "XLSX", width = "100%"),
      uiOutput("results_status"),
      hr(),
      h5("5. Reset", help_icon("Requirement: upload a file first. Reset clears the current upload, generated session files, and analysis state.")),
      actionButton("reset", "Reset", class = "btn-danger", width = "100%", icon = icon("trash"), `data-tooltip` = "Requirement: upload a file first."),
      hr(),
      # Download demo data
      h5("Demo Data", help_icon("Download sample files to inspect the expected reliability input format.")),
      div(
        class = "sidebar-button-row sidebar-button-row-compact",
        downloadButton("download_csv", "CSV"),
        downloadButton("download_xlsx", "XLSX")
      )
    ),
    # Define the output panel
    mainPanel(
      # Positioning and styling
      width = 10,
      class = "workflow-main-panel",
      # Define top row
      fluidRow(
        # Styling
        class = "app-output-row app-output-inspect-row",
        # Define as single column
        column(
          width = 12, offset = 0, class = "app-output-col app-output-inspect-col",
          uiOutput("inspect_row")
        )
      ),
      fluidRow(
        class = "app-output-row validation-report-row",
        column(
          width = 12, offset = 0, class = "app-output-col",
          uiOutput("validation_report")
        )
      ),
      # Define top row
      fluidRow(
        # Styling
        class = "app-output-row app-output-top-row",
        # Define as single column
        column(
          # Styling
          width = 12, offset = 0, class = "app-output-col app-output-top-col",
          uiOutput("top_row")
        )
      ),
      # Empty line between top and bottom row
      br(),
      # Define bottom row
      fluidRow(
        # Styling
        class = "app-output-row app-output-bottom-row",
        # Define as single column
        column(
          # Styling
          width = 12, offset = 0, class = "app-output-col",
          uiOutput("bottom_row")
        )
      )
    )
  )
)
