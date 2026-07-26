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
#' @examples
#' csv_lines <- c(
#'   paste(
#'     "Variable / Field Name,Field Type,Field Label,",
#'     "Text Validation Type OR Show Slider Number,",
#'     "\"Choices, Calculations, OR Slider Labels\",Required Field?",
#'     sep = ""
#'   ),
#'   "age,text,What is your age?,number,,y",
#'   "county,dropdown,County,,\"1, Turkana | 2, Wajir\",n"
#' )
#' path <- file.path(tempdir(), "redcap_dictionary.csv")
#' writeLines(csv_lines, path)
#' questions <- nf_import_redcap(path)
#' unlink(path)
nf_import_redcap <- function(file, auto_generate = FALSE) {
  # Read CSV
  codebook <- utils::read.csv(file, stringsAsFactors = FALSE, na.strings = c("", "NA"))
  
  # Initialize questions list
  questions <- list()
  
  for (i in seq_len(nrow(codebook))) {
    row <- codebook[i, ]
    
    # Extract field information. Empty cells arrive as NA rather than "",
    # because read.csv() is called with na.strings; `%||%` only catches NULL,
    # so NA has to be collapsed explicitly or every downstream nchar() test
    # returns NA and fails inside `if`.
    field_name <- redcap_chr(row$Variable...Field.Name, row$field_name)
    field_type <- redcap_chr(row$Field.Type, row$field_type)
    field_label <- redcap_chr(row$Field.Label, row$field_label, field_name)
    validation <- redcap_chr(row$Text.Validation.Type.OR.Show.Slider.Number,
                             row$validation)
    choices <- redcap_chr(row$Choices..Calculations..OR.Slider.Labels,
                          row$choices)
    branching <- redcap_chr(row$Branching.Logic..Show.field.only.if...,
                            row$branching_logic)
    required <- identical(tolower(redcap_chr(row$Required.Field., row$required, "n")), "y")

    if (!nzchar(field_name)) {
      next
    }

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
    if (nzchar(branching)) {
      question$skip_logic <- parse_redcap_branching(branching)
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
#' @examples
#' path <- file.path(tempdir(), "codebook.csv")
#' write.csv(
#'   data.frame(
#'     field_name = c("age", "county"),
#'     field_type = c("integer", "select"),
#'     field_label = c("Age", "County"),
#'     choices = c("", "Turkana|Wajir"),
#'     required = c("yes", "no"),
#'     stringsAsFactors = FALSE
#'   ),
#'   path, row.names = FALSE
#' )
#' questions <- nf_import_csv(path)
#' unlink(path)
nf_import_csv <- function(file,
                           field_name_col = "field_name",
                           field_type_col = "field_type",
                           field_label_col = "field_label",
                           choices_col = "choices",
                           required_col = "required") {
  
  codebook <- utils::read.csv(file, stringsAsFactors = FALSE)
  
  questions <- list()
  
  for (i in seq_len(nrow(codebook))) {
    row <- codebook[i, ]
    
    field_name <- redcap_chr(row[[field_name_col]])
    if (!nzchar(field_name)) {
      next
    }

    required_raw <- row[[required_col]]
    question <- list(
      id = field_name,
      label = redcap_chr(row[[field_label_col]], field_name),
      type = normalize_field_type(redcap_chr(row[[field_type_col]])),
      required = isTRUE(required_raw) ||
        tolower(redcap_chr(required_raw)) %in% c("yes", "y", "true", "1"),
      choices = parse_choices(redcap_chr(row[[choices_col]]))
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

    # nf_question() is the only question constructor this package exports, so
    # every generated line has to be a call to it. REDCap types that it cannot
    # represent are emitted as comments rather than as calls that would fail
    # the moment someone ran the generated script.
    nf_type <- switch(q$type,
      text = "text",
      textarea = "text",
      numeric = "numeric",
      select = "select",
      radio = "radio",
      checkbox = "checkbox",
      slider = "slider",
      date = "date",
      NA_character_
    )

    if (is.na(nf_type)) {
      code <- c(code, sprintf(
        '# TODO: field "%s" has REDCap type "%s", which nf_question() does not\n# support. Handle it manually.',
        q$id, q$type))
      next
    }

    args <- sprintf('id = "%s", type = "%s", label = "%s"',
                    q$id, nf_type, gsub('"', '\\\\"', q$label))

    if (!is.null(q$choices) && length(q$choices) > 0) {
      args <- paste0(args, ", choices = ", deparse_choices(q$choices))
    }

    args <- paste0(args, sprintf(", required = %s", if (isTRUE(q$required)) "TRUE" else "FALSE"))

    code <- c(code, sprintf("nf_question(%s)", args))
  }

  cat(paste(code, collapse = "\n\n"))
  invisible(code)
}


#' Coalesce Codebook Cells to a Single Non-Missing String
#'
#' Returns the first argument that is neither `NULL`, `NA`, nor a zero-length
#' vector, coerced to a length-one character string. Falls back to `""` so
#' callers can rely on `nzchar()` rather than guarding for `NA`.
#'
#' @param ... Candidate cell values, in priority order
#' @return A length-one character vector, possibly `""`
#' @keywords internal
redcap_chr <- function(...) {
  for (value in list(...)) {
    if (is.null(value) || length(value) == 0) next
    value <- value[[1]]
    if (is.na(value)) next
    return(as.character(value))
  }
  ""
}


#' Deparse a Named Choice Vector into R Source
#'
#' @param choices Named character vector of choice values (names are labels)
#' @return A single string of R source for a `c(...)` call
#' @keywords internal
deparse_choices <- function(choices) {
  labels <- names(choices)
  if (is.null(labels)) {
    return(paste0("c(", paste(sprintf('"%s"', choices), collapse = ", "), ")"))
  }
  paste0("c(", paste(sprintf('"%s" = "%s"', labels, choices), collapse = ", "), ")")
}


# Helper: null coalescing operator

