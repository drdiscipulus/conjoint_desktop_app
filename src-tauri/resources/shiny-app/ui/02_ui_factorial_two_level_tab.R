# Tab 2 is a navbar menu showing all analysis results
tabPanel(
  # Set the title of the Panel
  title = "2-Level",
  # Layout of the first element: sidebar layout
  sidebarLayout(
    # Define the input panel
    sidebarPanel(
      # Styling and positioning
      width = 2,
      class = "workflow-sidebar",
      h4("Define", help_icon("Use this tab when all attributes have exactly two levels.")),
      sliderInput("attributes_2", tagList("Number of Attributes", help_icon("Number of manipulated two-level attributes.")),
        min = 2, max = 10, value = 5
      ),
      selectInput("design_2",
        label = tagList("Design", help_icon("Full designs include every profile combination. Fractional designs reduce the number of profiles.")),
        choices = list("Full", "Fractional"),
        selected = "Fractional"
      ),
      selectInput("effects_2",
        label = tagList("Resolution", help_icon("Only applies to fractional designs. Resolution III estimates main effects. Resolution IV keeps main effects clear from two-way interactions. Resolution V keeps two-way interactions clear from main effects and other two-way interactions, usually with more profiles.")),
        choices = list("III" = "main_effects", "IV" = "two-way", "V" = "two-way-clear"),
        selected = "III"
      ),
      actionButton("generate_2", "Generate design", class = "btn-primary", width = "100%", icon = icon("cog")),
      uiOutput("two_level_status"),
      hr(),
      h5("Save", help_icon("Generate a design first. Save exports the displayed factorial design table.")),
      div(
        class = "sidebar-button-row sidebar-button-row-compact",
        downloadButton("download_two_level_csv", "CSV"),
        downloadButton("download_two_level_xlsx", "XLSX")
      ),
      br(),
    ),
    # Define the output panel
    mainPanel(
      # Positioning and styling
      width = 10,
      class = "workflow-main-panel",
      # Define top row
      fluidRow(
        # Styling
        class = "app-output-row app-output-top-row",
        # Define as single column
        column(
          # Styling
          width = 12, offset = 0, class = "app-output-col app-output-top-col",
          uiOutput("two_level")
        )
      )
    )
  )
)
