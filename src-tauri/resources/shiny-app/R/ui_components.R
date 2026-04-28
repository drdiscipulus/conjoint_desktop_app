help_icon <- function(text) {
  tags$span(class = "help-dot", tabindex = "0", `data-tooltip` = text, "?")
}

app_reactable_theme <- function() {
  reactable::reactableTheme(
    highlightColor = "#d8dfdc",
    stripedColor = "#f6faf8",
    backgroundColor = "#ffffff",
    borderColor = "#d8dfdc"
  )
}

factorial_placeholder <- function(title, detail, error = NULL) {
  div(
    class = "result-placeholder factorial-placeholder",
    h3(title),
    p(detail),
    if (!is.null(error)) {
      tags$div(class = "status-badge status-error", icon("exclamation-triangle"), error)
    }
  )
}

factorial_note_panel <- function(title, ...) {
  tags$details(
    class = "table-notes factorial-notes",
    tags$summary(title),
    tags$div(...)
  )
}

plotly_export_options <- function(filename, width = 1200, height = 720, scale = 2) {
  list(
    format = "png",
    filename = filename,
    width = width,
    height = height,
    scale = scale
  )
}

app_plotly_config <- function(plot, filename, width = 1200, height = 720, scale = 2) {
  plot |>
    config(
      displaylogo = FALSE,
      modeBarButtonsToRemove = c(
        "toggleSpikelines",
        "hoverClosestCartesian",
        "hoverCompareCartesian"
      ),
      toImageButtonOptions = plotly_export_options(
        filename = filename,
        width = width,
        height = height,
        scale = scale
      )
    )
}
