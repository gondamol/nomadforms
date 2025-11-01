#' Codebook Import for NomadForms
#'
#' Import survey definitions from codebooks (REDCap, CSV, etc.)
#'
#' @name codebook
NULL

#' Import REDCap Codebook
#'
#' Parses a REDCap data dictionary CSV and generates survey questions
#'
#' @param file Path to REDCap data dictionary CSV file
#' @param auto_generate Automatically generate Shiny UI code (default: FALSE)
#'
#' @return List of question definitions
#' @export
nf_import_redcap <- function(file, auto_generate = FALSE) {
  # Read CSV
  codebook <- read.csv(file, stringsAsFactors = FALSE, na.strings = c("", "NA"))
  
  # Initialize questions list
  questions <- list()
  
  for (i in seq_len(nrow(codebook))) {
    row <- codebook[i, ]
    
    # Extract field information
    field_name <- row$Variable...Field.Name %||% row$field_name
    field_type <- row$Field.Type %||% row$field_type
    field_label <- row$Field.Label %||% row$field_label %||% field_name
    validation <- row$Text.Validation.Type.OR.Show.Slider.Number %||% row$validation %||% ""
    choices <- row$Choices..Calculations..OR.Slider.Labels %||% row$choices %||% ""
    required <- tolower(row$Required.Field. %||% row$required %||% "n") == "y"
    
    # Parse question definition
    question <- list(
      id = field_name,
      label = field_label,
      type = parse_redcap_type(field_type),
      required = required,
      validation = parse_redcap_validation(validation),
      choices = parse_redcap_choices(choices)
    )
    
    # Add branching logic if present
    if (!is.null(row$Branching.Logic..Show.field.only.if...) && 
        nchar(row$Branching.Logic..Show.field.only.if...) > 0) {
      question$skip_logic <- parse_redcap_branching(row$Branching.Logic..Show.field.only.if...)
    }
    
    questions[[field_name]] <- question
  }
  
  if (auto_generate) {
    generate_ui_code(questions)
  }
  
  return(questions)
}


#' Import Generic CSV Codebook
#'
#' Parses a generic CSV codebook
#'
#' @param file Path to CSV file
#' @param field_name_col Column name for field names (default: "field_name")
#' @param field_type_col Column name for field types (default: "field_type")
#' @param field_label_col Column name for field labels (default: "field_label")
#' @param choices_col Column name for choices (default: "choices")
#' @param required_col Column name for required flag (default: "required")
#'
#' @return List of question definitions
#' @export
nf_import_csv <- function(file,
                           field_name_col = "field_name",
                           field_type_col = "field_type",
                           field_label_col = "field_label",
                           choices_col = "choices",
                           required_col = "required") {
  
  codebook <- read.csv(file, stringsAsFactors = FALSE)
  
  questions <- list()
  
  for (i in seq_len(nrow(codebook))) {
    row <- codebook[i, ]
    
    field_name <- row[[field_name_col]]
    
    question <- list(
      id = field_name,
      label = row[[field_label_col]] %||% field_name,
      type = normalize_field_type(row[[field_type_col]]),
      required = isTRUE(row[[required_col]]) || tolower(row[[required_col]]) == "yes",
      choices = if (!is.null(row[[choices_col]])) parse_choices(row[[choices_col]]) else NULL
    )
    
    questions[[field_name]] <- question
  }
  
  return(questions)
}


#' Parse REDCap Field Type
#' @param type REDCap field type
#' @return Normalized field type
#' @keywords internal
parse_redcap_type <- function(type) {
  type <- tolower(type)
  
  switch(type,
    text = "text",
    notes = "textarea",
    dropdown = "select",
    radio = "radio",
    checkbox = "checkbox",
    yesno = "radio",
    truefalse = "radio",
    file = "file",
    slider = "slider",
    calc = "calculated",
    descriptive = "html",
    "text"  # default
  )
}


#' Parse REDCap Validation
#' @param validation REDCap validation string
#' @return Validation rules list
#' @keywords internal
parse_redcap_validation <- function(validation) {
  if (is.null(validation) || nchar(validation) == 0) {
    return(NULL)
  }
  
  rules <- list()
  
  if (grepl("email", validation, ignore.case = TRUE)) {
    rules$type <- "email"
  } else if (grepl("date", validation, ignore.case = TRUE)) {
    rules$type <- "date"
  } else if (grepl("phone", validation, ignore.case = TRUE)) {
    rules$type <- "phone"
  } else if (grepl("number", validation, ignore.case = TRUE)) {
    rules$type <- "numeric"
  } else if (grepl("integer", validation, ignore.case = TRUE)) {
    rules$type <- "integer"
  }
  
  # Extract min/max from validation like "number(0,100)"
  if (grepl("\\(\\d+,\\d+\\)", validation)) {
    matches <- regmatches(validation, regexec("\\((\\d+),(\\d+)\\)", validation))[[1]]
    if (length(matches) == 3) {
      rules$min <- as.numeric(matches[2])
      rules$max <- as.numeric(matches[3])
    }
  }
  
  return(if (length(rules) > 0) rules else NULL)
}


#' Parse REDCap Choices
#' @param choices REDCap choices string (e.g., "1, Yes | 0, No")
#' @return Named character vector of choices
#' @keywords internal
parse_redcap_choices <- function(choices) {
  if (is.null(choices) || nchar(choices) == 0) {
    return(NULL)
  }
  
  # Split by pipe
  choice_list <- strsplit(choices, "\\|")[[1]]
  choice_list <- trimws(choice_list)
  
  # Parse each choice (format: "value, label")
  parsed_choices <- lapply(choice_list, function(choice) {
    parts <- strsplit(choice, ",")[[1]]
    if (length(parts) >= 2) {
      value <- trimws(parts[1])
      label <- trimws(paste(parts[-1], collapse = ","))
      return(c(value = value, label = label))
    }
    return(NULL)
  })
  
  parsed_choices <- Filter(Negate(is.null), parsed_choices)
  
  if (length(parsed_choices) == 0) {
    return(NULL)
  }
  
  values <- sapply(parsed_choices, function(x) x["value"])
  labels <- sapply(parsed_choices, function(x) x["label"])
  names(values) <- labels
  
  return(values)
}


#' Parse REDCap Branching Logic
#' @param logic REDCap branching logic string
#' @return Skip logic expression
#' @keywords internal
parse_redcap_branching <- function(logic) {
  # This is a simplified parser - REDCap logic can be complex
  # Example: "[field1] = '1'" -> show if field1 equals 1
  
  # Remove brackets
  logic <- gsub("\\[|\\]", "", logic)
  
  # Convert to R expression (simplified)
  # In production, you'd want a proper parser
  logic <- gsub("=", "==", logic)
  
  return(logic)
}


#' Parse Generic Choices String
#' @param choices Comma-separated or pipe-separated choices
#' @return Character vector of choices
#' @keywords internal
parse_choices <- function(choices) {
  if (is.null(choices) || nchar(choices) == 0) {
    return(NULL)
  }
  
  # Try pipe separator first, then comma
  if (grepl("\\|", choices)) {
    choice_list <- strsplit(choices, "\\|")[[1]]
  } else {
    choice_list <- strsplit(choices, ",")[[1]]
  }
  
  return(trimws(choice_list))
}


#' Normalize Field Type
#' @param type Field type string
#' @return Normalized type
#' @keywords internal
normalize_field_type <- function(type) {
  type <- tolower(trimws(type))
  
  switch(type,
    string = "text",
    integer = "numeric",
    float = "numeric",
    boolean = "radio",
    select = "select",
    multiselect = "checkbox",
    type
  )
}


#' Generate UI Code from Questions
#' @param questions List of question definitions
#' @return Character vector of R code
#' @keywords internal
generate_ui_code <- function(questions) {
  code <- character()
  
  for (q_id in names(questions)) {
    q <- questions[[q_id]]
    
    func_name <- switch(q$type,
      text = "nf_text_input",
      textarea = "nf_textarea",
      numeric = "nf_numeric_input",
      select = "nf_select_input",
      radio = "nf_radio_buttons",
      checkbox = "nf_checkbox_group",
      "nf_text_input"
    )
    
    line <- sprintf('%s(id = "%s", label = "%s", required = %s)',
                    func_name, q$id, q$label, q$required)
    
    code <- c(code, line)
  }
  
  cat(paste(code, collapse = ",\n\n"))
  invisible(code)
}


# Helper: null coalescing operator
`%||%` <- function(a, b) if (is.null(a) || is.na(a) || nchar(a) == 0) b else a

