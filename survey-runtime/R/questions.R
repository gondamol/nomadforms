#' Create Survey Question
#'
#' Creates different types of survey questions compatible with Shiny.
#'
#' @param id Question identifier (used as variable name)
#' @param type Question type: "text", "numeric", "radio", "checkbox", "select", "date", "slider"
#' @param label Question label/text
#' @param choices For radio/checkbox/select: vector of choices
#' @param required Is this question required? (default: FALSE)
#' @param min For numeric/slider: minimum value
#' @param max For numeric/slider: maximum value
#' @param help_text Optional help text displayed below question
#'
#' @return Shiny UI element
#' @export
#'
#' @examples
#' if (requireNamespace("shiny", quietly = TRUE)) {
#'   # Numeric with range
#'   nf_question("age", "numeric", "Age", min = 0, max = 120, required = TRUE)
#'
#'   # Radio buttons
#'   nf_question("gender", "radio", "Gender", choices = c("Male", "Female", "Other"))
#' }
nf_question <- function(id,
                        type = "text",
                        label,
                        choices = NULL,
                        required = FALSE,
                        min = NULL,
                        max = NULL,
                        help_text = NULL) {
  
  # This helper builds Shiny inputs for the optional Shiny/Quarto demo path.
  # The mobile PWA collection path does not use it, so shiny is a Suggests
  # dependency rather than a hard Import.
  if (!requireNamespace("shiny", quietly = TRUE)) {
    stop("Package 'shiny' is required for nf_question(). Install it with ",
         "install.packages('shiny'), or use the PWA collection path.")
  }

  # Add required indicator to label
  if (required) {
    label <- htmltools::HTML(paste0(label, ' <span style="color:red;">*</span>'))
  }

  # Create question based on type
  question_ui <- switch(type,
    "text" = shiny::textInput(id, label),
    "numeric" = shiny::numericInput(id, label, value = NA, min = min, max = max),
    "radio" = shiny::radioButtons(id, label, choices = choices),
    "checkbox" = shiny::checkboxGroupInput(id, label, choices = choices),
    "select" = shiny::selectInput(id, label, choices = c("", choices)),
    "date" = shiny::dateInput(id, label),
    "slider" = shiny::sliderInput(id, label, min = min, max = max, value = min),
    stop(paste("Unknown question type:", type))
  )
  
  # Add help text if provided
  if (!is.null(help_text)) {
    question_ui <- htmltools::div(
      question_ui,
      htmltools::p(class = "help-text", style = "color: #666; font-size: 0.9em;", help_text)
    )
  }
  
  return(question_ui)
}

