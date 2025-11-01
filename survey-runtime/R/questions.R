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
#' \dontrun{
#' # Text question
#' nf_question("name", "text", "What is your name?", required = TRUE)
#'
#' # Radio buttons
#' nf_question("gender", "radio", "Gender", choices = c("Male", "Female", "Other"))
#'
#' # Numeric with range
#' nf_question("age", "numeric", "Age", min = 0, max = 120, required = TRUE)
#' }
nf_question <- function(id,
                        type = "text",
                        label,
                        choices = NULL,
                        required = FALSE,
                        min = NULL,
                        max = NULL,
                        help_text = NULL) {
  
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


#' Validate Question Response
#'
#' Validates a question response based on its requirements.
#'
#' @param value Response value
#' @param required Is the question required?
#' @param type Question type
#' @param min Minimum value (for numeric/slider)
#' @param max Maximum value (for numeric/slider)
#'
#' @return List with valid (TRUE/FALSE) and message (error message if invalid)
#' @export
nf_validate <- function(value, required = FALSE, type = "text", min = NULL, max = NULL) {
  
  # Check if required and empty
  if (required && (is.null(value) || length(value) == 0 || value == "")) {
    return(list(valid = FALSE, message = "This question is required"))
  }
  
  # Skip validation if not required and empty
  if (!required && (is.null(value) || length(value) == 0 || value == "")) {
    return(list(valid = TRUE, message = NULL))
  }
  
  # Type-specific validation
  if (type %in% c("numeric", "slider")) {
    if (!is.numeric(value)) {
      return(list(valid = FALSE, message = "Please enter a valid number"))
    }
    if (!is.null(min) && value < min) {
      return(list(valid = FALSE, message = paste("Value must be at least", min)))
    }
    if (!is.null(max) && value > max) {
      return(list(valid = FALSE, message = paste("Value must be at most", max)))
    }
  }
  
  return(list(valid = TRUE, message = NULL))
}

