shinyjs::disable("download_two_level_csv")
shinyjs::disable("download_two_level_xlsx")

observe({
  if (identical(input$design_2, "Full")) {
    shinyjs::disable("effects_2")
  } else {
    shinyjs::enable("effects_2")
  }
})

two_level_error <- reactiveVal(NULL)

set_two_level_failure <- function(message) {
  two_level_error(message)
  shinyjs::disable("download_two_level_csv")
  shinyjs::disable("download_two_level_xlsx")
  NULL
}

output$two_level_status <- renderUI({
  if (!is.null(two_level_error())) {
    return(tags$div(class = "status-badge status-error", icon("exclamation-triangle"), two_level_error()))
  }
  if (input$generate_2 > 0 && !is.null(get_two_level_factorial()$table)) {
    return(tags$div(class = "status-badge status-complete", icon("check"), "Design generated"))
  }
  NULL
})

# Try to get factorial design when button is pressed
get_two_level_factorial <- reactive({
  if (input$design_2 == "Fractional") {
    # Try to obtain result
    res <- try(get_two_level_fractional(
      attributes = input$attributes_2,
      effects = input$effects_2
    ), silent = TRUE)

    if (inherits(res, "try-error")) {
      res <- set_two_level_failure("No solution could be found for these settings.")
    } else {
      two_level_error(NULL)
      shinyjs::enable("download_two_level_csv")
      shinyjs::enable("download_two_level_xlsx")
      res
    }
  } else if (input$design_2 == "Full") {
    # Try to obtain result
    res <- try(get_two_level_full(
      attributes = input$attributes_2
    ), silent = TRUE)

    if (inherits(res, "try-error")) {
      res <- set_two_level_failure("No solution could be found for these settings.")
    } else {
      two_level_error(NULL)
      shinyjs::enable("download_two_level_csv")
      shinyjs::enable("download_two_level_xlsx")
      res
    }
  }
}) |> bindEvent(input$generate_2)


output$download_two_level_csv <- downloadHandler(
  filename = function() {
    "two_level_factorial_design.csv"
  },
  content = function(file) {
    req(get_two_level_factorial()$table)
    readr::write_csv(get_two_level_factorial()$table, file)
  }
)


output$download_two_level_xlsx <- downloadHandler(
  filename = function() {
    "two_level_factorial_design.xlsx"
  },
  content = function(file) {
    req(get_two_level_factorial()$table)
    openxlsx::write.xlsx(get_two_level_factorial()$table, file, overwrite = TRUE)
  }
)

two_level_alias_data <- reactive({
  req(get_two_level_factorial()$design)
  summarize_two_way_aliases(get_two_level_factorial()$design)
}) |> bindEvent(input$generate_2)


output$two_level_alias_summary <- renderText({
  req(get_two_level_factorial()$table)
  profile_count <- nrow(get_two_level_factorial()$table)
  interaction_count <- choose(input$attributes_2, 2)

  if (input$design_2 == "Full") {
    return(paste0(
      "Full factorial: all ", interaction_count,
      " two-way interactions work separately. The design has ",
      profile_count, " profiles."
    ))
  }

  switch(input$effects_2,
    "main_effects" = paste0(
      "Resolution III: two-way interactions may be confounded with main effects. ",
      "Use the table to see which interactions should not be interpreted separately. ",
      "The design has ", profile_count, " profiles."
    ),
    "two-way" = paste0(
      "Resolution IV: main effects are clear from two-way interactions, but some two-way interactions may be confounded with other two-way interactions. ",
      "The design has ", profile_count, " profiles."
    ),
    "two-way-clear" = paste0(
      "Resolution V: two-way interactions work separately from main effects and other two-way interactions. ",
      "Interpretation still assumes that higher-order interactions are negligible. ",
      "The design has ", profile_count, " profiles."
    )
  )
}) |> bindEvent(input$generate_2)


output$two_level_alias_table <- renderReactable({
  req(two_level_alias_data())

  reactable(two_level_alias_data(),
    highlight = TRUE,
    striped = TRUE,
    bordered = TRUE,
    compact = TRUE,
    defaultPageSize = 20,
    theme = app_reactable_theme(),
    defaultColDef = colDef(
      align = "left",
      minWidth = 130
    ),
    columns = list(
      two_way_interaction = colDef(
        name = "Two-Way Interaction",
        minWidth = 180
      ),
      status = colDef(
        name = "Status",
        minWidth = 115,
        cell = function(value) {
          tags$span(
            class = paste("alias-status", paste0("alias-status-", value)),
            value
          )
        }
      ),
      confounded_with = colDef(
        name = "Confounded With",
        minWidth = 250,
        na = ""
      ),
      interpretation = colDef(
        name = "Interpretation",
        minWidth = 430
      )
    )
  )
}) |> bindEvent(input$generate_2)


# Render table for 2-level fractional
output$two_level_table <- renderReactable({
  # Proceed if not null
  req(get_two_level_factorial()$table)

  custom_width <- 95 + ((ncol(get_two_level_factorial()$table) - 1) * 120) + 2

  # Create reactable
  reactable(get_two_level_factorial()$table,
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
    columns = attribute_column_defs(get_two_level_factorial()$table),
    style = list(maxWidth = custom_width)
  )
}) |> bindEvent(input$generate_2)


# Render correlation plot for 2-level fractional
output$two_level_plot <- renderPlot({
  # Proceed if not null
  req(get_two_level_factorial()$table)

  # Get correlation data
  dat <- get_cor_table(data = get_two_level_factorial()$design)

  # Check if data exists
  if (is.null(dat)) {
    
    # Create a text plot
    tmp <- tibble(x = c(1,2,3), y = c(1,2,3))
    
    ggplot(tmp, aes(x = x, y = y)) +
      xlim(1,3) +
      ylim(1,3) +
      annotate(
        "text",
        x = 2,
        y = 2,
        size = 4.5,
        family = "Arial",
        color = "#5f6b66",
        label = "No encoded-correlation heatmap is available for this design.\nFor Resolution V or full designs, use the interaction estimability table."
      ) +
      theme_void(base_family = "Arial")

    # If there is data, create a heat map
  } else {
    dat <- dat |>
      mutate(
        row_label = prettify_effect_label(rowname),
        variable_label = prettify_effect_label(variables),
        row_label = factor(row_label, levels = rev(unique(row_label))),
        variable_label = factor(variable_label, levels = unique(variable_label))
      )

    ggplot(dat, aes(x = variable_label, y = row_label, fill = correlation)) +
      geom_tile(color = "white", linewidth = 0.55, linetype = 1) +
      geom_text(
        family = "Arial",
        size = 3.2,
        aes(
          label = round(correlation, 1),
          color = after_scale(prismatic::best_contrast(fill, c("white", "#17211d")))
        )
      ) +
      scale_fill_viridis(option = "C", discrete = FALSE, direction = -1, name = "Abs. correlation") +
      labs(x = NULL, y = NULL) +
      theme_minimal(base_family = "Arial", base_size = 11) +
      theme(
        plot.background = element_rect(fill = "white", color = NA),
        panel.background = element_rect(fill = "white", color = NA),
        panel.grid = element_blank(),
        axis.text.x = element_text(angle = 40, hjust = 1, color = "#17211d", size = 9),
        axis.text.y = element_text(color = "#17211d", size = 9),
        legend.position = "right",
        legend.title = element_text(color = "#17211d", size = 10, face = "bold"),
        legend.text = element_text(color = "#17211d", size = 9)
      )
  }
}) |> bindEvent(input$generate_2)


# Render text
output$two_level_line_1 <- renderText({
  req(get_two_level_factorial()$table)
  "The heatmap shows absolute correlations among encoded main effects and two-way interactions."
}) |> bindEvent(input$generate_2)


output$two_level_line_2 <- renderText({
  req(get_two_level_factorial()$table)
  "Use the interaction estimability table for the applied interpretation of two-way interactions."
}) |> bindEvent(input$generate_2)


# Render the ui
output$two_level <- renderUI({
  if (input$generate_2 == 0) {
    return(factorial_placeholder(
      "Generate A Two-Level Design",
      "Generate a two-level design to inspect profiles, two-way interaction estimability, and encoded correlations."
    ))
  }

  if (is.null(get_two_level_factorial()$table)) {
    return(factorial_placeholder(
      "No Design Generated",
      "Adjust the design settings and generate again.",
      two_level_error()
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
        reactableOutput("two_level_table") %>% withSpinner(type = 6, color = "#009260")
      ),
      tabPanel(
        "Interaction Estimability",
        div(class = "result-summary", textOutput("two_level_alias_summary")),
        reactableOutput("two_level_alias_table") %>% withSpinner(type = 6, color = "#009260")
      ),
      # Second panel
      tabPanel(
        # Show attribute correlations
        "Correlations",
        factorial_note_panel(
          "Plot notes",
          p(textOutput("two_level_line_1")),
          p(textOutput("two_level_line_2"))
        ),
        plotOutput("two_level_plot", height = 720) %>% withSpinner(type = 6, color = "#009260")
      )
    )
  )
}) |> bindEvent(input$generate_2)
