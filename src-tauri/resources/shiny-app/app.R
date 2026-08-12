#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

# Load packages
library(shiny) # Shiny package
library(shinyjs) # Used for reset functionality
library(shinycssloaders) # Used loading animations
library(bslib) # Used for theming
library(tidyverse) # Used for data wrangling and manipulation
library(reactable) # Interactive tables
library(FrF2) # Create two-level fractional factorial designs
library(DoE.base) # Create n-level full and fractional factorial designs
library(broom) # Used to create tidy data frames with model results
library(psych) # Used to calculate ICC values
library(sandwich) # For calculating robust standard errors
library(lmtest) # For calculating robust standard errors
library(parameters) # To obtain robust standard errors
library(plotly) # Interactive plots
library(viridis) # Provides additional color schemes
library(vroom) # Reading and writing .csv files
library(openxlsx) # Read and write .xlsx files
options(shiny.maxRequestSize = 5 * 1024^2)
source("R/upload_validation.R") # Upload validation and limits
source("R/session_files.R") # Session-specific temp files
source("R/result_exports.R") # Result export helpers
source("R/ui_labels.R") # UI label helpers
source("R/ui_components.R") # Shared UI components and themes
source("R/alias_diagnostics.R") # Two-way interaction alias diagnostics
source("R/interaction_coverage.R") # N-level interaction coverage diagnostics
source("functions_factorial.R") # Source functions
source("functions_reliability.R") # Source functions
source("custom_corr_plot.R") # Source functions
options(shiny.useragg = FALSE)

# Define custom theme
custom_theme <- bs_theme(
  version = 5, primary = "#009260", secondary = "#7F8990", base_font = "Arial",
  code_font = "Consolas", `enable-gradients` = FALSE,
  `enable-transitions` = FALSE, `enable-shadows` = TRUE
)

# Define UI for application that draws a histogram
ui <- fluidPage(

  # Include shinjs
  useShinyjs(),

  ###################### Styling ###############################################

  # Set theme
  theme = custom_theme,
  tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "app.css")
  ),


  ###################### Layout ################################################

  # Base layout: navbar page
  navbarPage(
    # Set title and add banner at top right
    title = div(
      "Conjoint Companion",
      img(
        src = "index.png",
        height = "34px",
        class = "navbar-logo-lockup"
      )
    ),
    # Set browser title
    windowTitle = "Conjoint Companion",

    ###################### Tabs ################################################

    # Menu entry with drop down selection
    navbarMenu(
      # Menu title
      "About",
      # General about
      source(file.path("ui/01_ui_general_about_tab.R"), local = TRUE)$value,
      # About factorial designs
      source(file.path("ui/01_ui_factorial_about_tab.R"), local = TRUE)$value,
      # About test-retest reliability
      source(file.path("ui/01_ui_reliability_about_tab.R"), local = TRUE)$value,
    ),

    # Factorial tab with drop downs
    navbarMenu(
      # Menu title
      "Factorial Designs",
      # 2-level designs
      source(file.path("ui/02_ui_factorial_two_level_tab.R"), local = TRUE)$value,
      # n-level designs
      source(file.path("ui/03_ui_factorial_n_level_tab.R"), local = TRUE)$value,
    ),

    # Test-retest reliability tab
    source(file.path("ui/02_ui_reliability_tab.R"), local = TRUE)$value,
  )
)


# Define server logic
server <- function(input, output, session) {
 
  # Load all factorial design server logic
  source(file.path("server/01_server_factorial_two_level_tab.R"), local = TRUE)$value
  source(file.path("server/02_server_factorial_n_level_tab.R"), local = TRUE)$value

  # Load test-retest reliability server logic
  source(file.path("server/01_server_reliability_tab.R"), local = TRUE)$value

  # Desktop fallback: save download-button outputs directly from the local Shiny process.
  source(file.path("server/99_server_desktop_downloads.R"), local = TRUE)$value
}


# Run the application
shinyApp(ui = ui, server = server)
