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
      selectInput("design_n", label = tagList("Design", help_icon("Full designs include every possible profile. Fractional designs reduce the number of profiles.")), choices = list("Full", "Fractional"), selected = "Fractional"),
      selectInput("effects_n",
        label = tagList("Resolution", help_icon("Only applies to fractional designs. For N-level and mixed-level orthogonal arrays, this is generalized resolution. Resolution III estimates main effects. Resolution IV keeps main effects clear from two-way interactions. Resolution V also keeps two-way interactions clear from one another and usually requires more profiles.")),
        choices = list("III" = "main_effects", "IV" = "two-way", "V" = "two-way-clear"),
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
