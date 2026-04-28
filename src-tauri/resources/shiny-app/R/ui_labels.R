prettify_attribute_label <- function(value) {
  value <- as.character(value)
  ifelse(
    grepl("^att_\\d+$", value),
    paste("Attribute", sub("^att_", "", value)),
    value
  )
}

prettify_effect_label <- function(value) {
  vapply(strsplit(as.character(value), ":", fixed = TRUE), function(parts) {
    parts <- ifelse(
      grepl("^att_\\d+1$", parts),
      sub("1$", "", parts),
      parts
    )
    paste(prettify_attribute_label(parts), collapse = ":")
  }, character(1))
}

attribute_column_defs <- function(dat) {
  attribute_columns <- names(dat)[grepl("^att_\\d+$", names(dat))]
  stats::setNames(
    lapply(attribute_columns, function(column) {
      reactable::colDef(name = prettify_attribute_label(column), minWidth = 105)
    }),
    attribute_columns
  )
}
