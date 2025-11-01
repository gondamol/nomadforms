#' Advanced Validation Functions for NomadForms
#'
#' @name validation
NULL

#' Validate Response
#'
#' Validates a single response value against specified rules
#'
#' @param value The response value to validate
#' @param rules List of validation rules
#' @param question_label Label of the question (for error messages)
#'
#' @return List with valid (TRUE/FALSE) and message
#' @export
nf_validate <- function(value, rules = list(), question_label = "This field") {
  errors <- character()
  
  # Required validation
  if (isTRUE(rules$required)) {
    if (is.null(value) || length(value) == 0 || 
        (is.character(value) && all(trimws(value) == "")) ||
        (is.numeric(value) && all(is.na(value)))) {
      errors <- c(errors, paste(question_label, "is required"))
    }
  }
  
  # Skip further validation if value is empty and not required
  if (is.null(value) || length(value) == 0 || all(is.na(value))) {
    if (length(errors) > 0) {
      return(list(valid = FALSE, errors = errors))
    }
    return(list(valid = TRUE, errors = NULL))
  }
  
  # Type validation
  if (!is.null(rules$type)) {
    type_valid <- switch(rules$type,
      numeric = is.numeric(value),
      integer = is.integer(value) || (is.numeric(value) && all(value %% 1 == 0)),
      text = is.character(value),
      email = nf_validate_email(value),
      url = nf_validate_url(value),
      date = inherits(value, "Date") || nf_validate_date(value),
      phone = nf_validate_phone(value),
      TRUE
    )
    
    if (!type_valid) {
      errors <- c(errors, paste(question_label, "must be a valid", rules$type))
    }
  }
  
  # Min/Max for numeric values
  if (is.numeric(value)) {
    if (!is.null(rules$min) && any(value < rules$min, na.rm = TRUE)) {
      errors <- c(errors, paste(question_label, "must be at least", rules$min))
    }
    if (!is.null(rules$max) && any(value > rules$max, na.rm = TRUE)) {
      errors <- c(errors, paste(question_label, "must be at most", rules$max))
    }
  }
  
  # Min/Max length for strings
  if (is.character(value)) {
    if (!is.null(rules$min_length)) {
      if (any(nchar(value) < rules$min_length)) {
        errors <- c(errors, paste(question_label, "must be at least", rules$min_length, "characters"))
      }
    }
    if (!is.null(rules$max_length)) {
      if (any(nchar(value) > rules$max_length)) {
        errors <- c(errors, paste(question_label, "must be at most", rules$max_length, "characters"))
      }
    }
  }
  
  # Pattern matching (regex)
  if (!is.null(rules$pattern) && is.character(value)) {
    if (!all(grepl(rules$pattern, value))) {
      msg <- rules$pattern_message %||% paste(question_label, "has invalid format")
      errors <- c(errors, msg)
    }
  }
  
  # Custom validation function
  if (!is.null(rules$custom_fn) && is.function(rules$custom_fn)) {
    custom_result <- rules$custom_fn(value)
    if (is.character(custom_result)) {
      errors <- c(errors, custom_result)
    } else if (isFALSE(custom_result)) {
      errors <- c(errors, paste(question_label, "is invalid"))
    }
  }
  
  # In list validation
  if (!is.null(rules$in)) {
    if (!all(value %in% rules$in)) {
      errors <- c(errors, paste(question_label, "must be one of:", paste(rules$in, collapse = ", ")))
    }
  }
  
  # Not in list validation
  if (!is.null(rules$not_in)) {
    if (any(value %in% rules$not_in)) {
      errors <- c(errors, paste(question_label, "cannot be:", paste(rules$not_in[value %in% rules$not_in], collapse = ", ")))
    }
  }
  
  # Unique validation
  if (isTRUE(rules$unique) && length(value) > 1) {
    if (any(duplicated(value))) {
      errors <- c(errors, paste(question_label, "must contain unique values"))
    }
  }
  
  if (length(errors) > 0) {
    return(list(valid = FALSE, errors = errors))
  }
  
  return(list(valid = TRUE, errors = NULL))
}


#' Validate Email
#' @param email Email address
#' @return Logical
#' @export
nf_validate_email <- function(email) {
  pattern <- "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
  grepl(pattern, email)
}


#' Validate URL
#' @param url URL string
#' @return Logical
#' @export
nf_validate_url <- function(url) {
  pattern <- "^https?://[a-zA-Z0-9.-]+(:[0-9]+)?(/.*)?$"
  grepl(pattern, url)
}


#' Validate Date
#' @param date Date string
#' @return Logical
#' @export
nf_validate_date <- function(date) {
  tryCatch({
    as.Date(date)
    return(TRUE)
  }, error = function(e) {
    return(FALSE)
  })
}


#' Validate Phone Number
#' @param phone Phone number string
#' @return Logical
#' @export
nf_validate_phone <- function(phone) {
  # International format: +1234567890 or local formats
  pattern <- "^\\+?[1-9]\\d{1,14}$|^\\(?\\d{3}\\)?[-\\s]?\\d{3}[-\\s]?\\d{4}$"
  grepl(pattern, phone)
}


#' Validate Batch
#'
#' Validates multiple responses at once
#'
#' @param responses Named list of responses
#' @param rules Named list of validation rules for each field
#' @param labels Named list of labels for each field
#'
#' @return List with valid (TRUE/FALSE), errors list, and summary
#' @export
nf_validate_batch <- function(responses, rules, labels = NULL) {
  results <- list()
  all_errors <- list()
  
  for (field_name in names(responses)) {
    field_rules <- rules[[field_name]]
    field_label <- if (!is.null(labels)) labels[[field_name]] else field_name
    
    if (!is.null(field_rules)) {
      result <- nf_validate(
        responses[[field_name]], 
        field_rules,
        field_label
      )
      
      results[[field_name]] <- result
      
      if (!result$valid) {
        all_errors[[field_name]] <- result$errors
      }
    }
  }
  
  return(list(
    valid = length(all_errors) == 0,
    results = results,
    errors = all_errors,
    error_count = length(all_errors)
  ))
}


#' Cross-field Validation
#'
#' Validates relationships between multiple fields
#'
#' @param responses Named list of responses
#' @param rules List of cross-field validation rules
#'
#' @return List with valid (TRUE/FALSE) and errors
#' @export
nf_validate_cross_field <- function(responses, rules) {
  errors <- character()
  
  for (rule in rules) {
    if (rule$type == "match") {
      # Fields must match (e.g., password confirmation)
      if (responses[[rule$field1]] != responses[[rule$field2]]) {
        msg <- rule$message %||% paste(rule$field1, "and", rule$field2, "must match")
        errors <- c(errors, msg)
      }
    } else if (rule$type == "greater_than") {
      # Field1 must be greater than Field2
      if (responses[[rule$field1]] <= responses[[rule$field2]]) {
        msg <- rule$message %||% paste(rule$field1, "must be greater than", rule$field2)
        errors <- c(errors, msg)
      }
    } else if (rule$type == "less_than") {
      # Field1 must be less than Field2
      if (responses[[rule$field1]] >= responses[[rule$field2]]) {
        msg <- rule$message %||% paste(rule$field1, "must be less than", rule$field2)
        errors <- c(errors, msg)
      }
    } else if (rule$type == "date_after") {
      # Date1 must be after Date2
      date1 <- as.Date(responses[[rule$field1]])
      date2 <- as.Date(responses[[rule$field2]])
      if (date1 <= date2) {
        msg <- rule$message %||% paste(rule$field1, "must be after", rule$field2)
        errors <- c(errors, msg)
      }
    } else if (rule$type == "conditional_required") {
      # Field is required if condition is met
      condition_met <- eval(rule$condition, envir = responses)
      if (condition_met && (is.null(responses[[rule$field]]) || responses[[rule$field]] == "")) {
        msg <- rule$message %||% paste(rule$field, "is required")
        errors <- c(errors, msg)
      }
    }
  }
  
  if (length(errors) > 0) {
    return(list(valid = FALSE, errors = errors))
  }
  
  return(list(valid = TRUE, errors = NULL))
}

# Helper: null coalescing operator
`%||%` <- function(a, b) if (is.null(a)) b else a

