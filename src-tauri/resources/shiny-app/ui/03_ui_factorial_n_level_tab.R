# Tab 2 is a navbar menu showing all analysis results
tabPanel(
  # Set the title of the Panel
  title = "N-Level",
  # Layout of the first element: sidebar layout
  sidebarLayout(
    # Define the input panel
    sidebarPanel(
      # Styling and positioning
      width = 2,
      class = "workflow-sidebar",
      h4("Define", help_icon("Use this tab when at least one attribute has more than two levels.")),
      textInput("attributes_n", tagList("Attributes", help_icon("Comma-separated level counts, for example 3,3,3 or 2,4,4,3. Maximum: 7 attributes and 4 levels.")), "3,3,3"),
      selectInput("design_n", label = tagList("Design", help_icon("Full designs include all combinations. Fractional designs search orthogonal arrays.")), choices = list("Full", "Fractional"), selected = "Fractional"),
      selectInput("effects_n",
        label = tagList("OA criterion", help_icon("Classical Resolution III/IV/V applies to regular two-level fractional factorial designs. Here the app searches mixed-level orthogonal arrays and reports pairwise coverage and balance.")),
        choices = list("Main-effects OA" = "main_effects", "Higher-strength OA search" = "two-way"),
        selected = "main_effects"
      ),
      actionButton("generate_n", "Generate design", class = "btn-primary", width = "100%", icon = icon("cog")),
      uiOutput("n_level_status"),
      hr(),
      h5("Save", help_icon("Generate a design first. Save exports the displayed factorial design table.")),
      div(
        class = "sidebar-button-row sidebar-button-row-compact",
        downloadButton("download_n_level_csv", "CSV"),
        downloadButton("download_n_level_xlsx", "XLSX")
      ),
      br(),
    ),
    # Define the output panel
    mainPanel(
      # Positioning and styling
      width = 10, offset = 0, class = "workflow-main-panel factorial-main-panel",
      uiOutput("n_level")
      )
    )
  )
