#' Skip Logic / Conditional Display
#'
#' Functions for implementing skip logic and conditional question display
#'
#' @name skip_logic
NULL

#' Evaluate Skip Logic
#'
#' Determines whether a question should be shown based on previous responses
#'
#' @param condition Expression or function to evaluate
#' @param responses Named list of previous responses
#' @param default Default value if evaluation fails (default: TRUE)
#'
#' @return Logical indicating whether to show the question
#' @export
nf_skip_logic <- function(condition, responses, default = TRUE) {
  tryCatch({
    if (is.function(condition)) {
      # Condition is a function
      result <- condition(responses)
    } else if (is.language(condition)) {
      # Condition is an expression
      result <- eval(condition, envir = responses)
    } else if (is.character(condition)) {
      # Condition is a string expression
      result <- eval(parse(text = condition), envir = responses)
    } else {
      # Condition is already a logical value
      result <- condition
    }
    
    return(isTRUE(result))
  }, error = function(e) {
    warning(paste("Skip logic evaluation failed:", e$message))
    return(default)
  })
}


#' Create Skip Logic Rule
#'
#' Helper to create skip logic rules in a structured format
#'
#' @param show_if Expression or function that returns TRUE to show the question
#' @param hide_if Expression or function that returns TRUE to hide the question
#'
#' @return Skip logic rule object
#' @export
nf_skip_rule <- function(show_if = NULL, hide_if = NULL) {
  if (!is.null(show_if) && !is.null(hide_if)) {
    stop("Specify either show_if or hide_if, not both")
  }
  
  list(
    show_if = show_if,
    hide_if = hide_if
  )
}


#' Apply Skip Logic to Question Set
#'
#' Applies skip logic rules to determine which questions should be shown
#'
#' @param questions List of question definitions with skip_logic rules
#' @param responses Current responses
#'
#' @return Named list of question_id -> should_show (logical)
#' @export
nf_apply_skip_logic <- function(questions, responses) {
  results <- list()
  
  for (q_id in names(questions)) {
    question <- questions[[q_id]]
    skip_rule <- question$skip_logic
    
    if (is.null(skip_rule)) {
      # No skip logic - always show
      results[[q_id]] <- TRUE
    } else {
      if (!is.null(skip_rule$show_if)) {
        # Show if condition is TRUE
        results[[q_id]] <- nf_skip_logic(skip_rule$show_if, responses, default = FALSE)
      } else if (!is.null(skip_rule$hide_if)) {
        # Hide if condition is TRUE (inverse)
        results[[q_id]] <- !nf_skip_logic(skip_rule$hide_if, responses, default = FALSE)
      } else {
        results[[q_id]] <- TRUE
      }
    }
  }
  
  return(results)
}


#' Common Skip Logic Patterns
#'
#' Pre-built skip logic patterns for common scenarios
#'
#' @name skip_patterns
NULL

#' Show if Previous Answer Equals
#'
#' @param previous_question_id ID of previous question
#' @param value Value to compare against
#' @return Skip logic function
#' @export
nf_show_if_equals <- function(previous_question_id, value) {
  function(responses) {
    previous_value <- responses[[previous_question_id]]
    !is.null(previous_value) && previous_value == value
  }
}


#' Show if Previous Answer In List
#'
#' @param previous_question_id ID of previous question
#' @param values Vector of values to check
#' @return Skip logic function
#' @export
nf_show_if_in <- function(previous_question_id, values) {
  function(responses) {
    previous_value <- responses[[previous_question_id]]
    !is.null(previous_value) && previous_value %in% values
  }
}


#' Show if Previous Answer Contains
#'
#' For checkbox/multi-select questions
#'
#' @param previous_question_id ID of previous question
#' @param value Value to check for
#' @return Skip logic function
#' @export
nf_show_if_contains <- function(previous_question_id, value) {
  function(responses) {
    previous_value <- responses[[previous_question_id]]
    !is.null(previous_value) && value %in% previous_value
  }
}


#' Show if Previous Answer Greater Than
#'
#' @param previous_question_id ID of previous question
#' @param threshold Threshold value
#' @return Skip logic function
#' @export
nf_show_if_greater <- function(previous_question_id, threshold) {
  function(responses) {
    previous_value <- responses[[previous_question_id]]
    !is.null(previous_value) && is.numeric(previous_value) && previous_value > threshold
  }
}


#' Show if Previous Answer Less Than
#'
#' @param previous_question_id ID of previous question
#' @param threshold Threshold value
#' @return Skip logic function
#' @export
nf_show_if_less <- function(previous_question_id, threshold) {
  function(responses) {
    previous_value <- responses[[previous_question_id]]
    !is.null(previous_value) && is.numeric(previous_value) && previous_value < threshold
  }
}


#' Show if Multiple Conditions Met (AND)
#'
#' @param ... Skip logic functions or expressions
#' @return Skip logic function
#' @export
nf_show_if_all <- function(...) {
  conditions <- list(...)
  function(responses) {
    results <- sapply(conditions, function(cond) {
      if (is.function(cond)) {
        cond(responses)
      } else {
        eval(cond, envir = responses)
      }
    })
    all(results)
  }
}


#' Show if Any Condition Met (OR)
#'
#' @param ... Skip logic functions or expressions
#' @return Skip logic function
#' @export
nf_show_if_any <- function(...) {
  conditions <- list(...)
  function(responses) {
    results <- sapply(conditions, function(cond) {
      if (is.function(cond)) {
        cond(responses)
      } else {
        eval(cond, envir = responses)
      }
    })
    any(results)
  }
}


#' Generate JavaScript for Client-Side Skip Logic
#'
#' Converts R skip logic rules to JavaScript for immediate UI updates
#'
#' @param question_id Question ID
#' @param skip_rule Skip logic rule
#'
#' @return JavaScript code as string
#' @export
nf_skip_logic_js <- function(question_id, skip_rule) {
  if (is.null(skip_rule)) {
    return("")
  }
  
  # This is a simplified version - in production you'd want a proper R-to-JS transpiler
  # For now, we'll generate basic JavaScript for common patterns
  
  js_code <- sprintf("
    function updateVisibility_%s() {
      var questionDiv = document.getElementById('question_%s');
      if (!questionDiv) return;
      
      // Evaluate skip logic condition
      var shouldShow = %s;
      
      questionDiv.style.display = shouldShow ? 'block' : 'none';
      
      // Clear value if hidden
      if (!shouldShow) {
        var inputs = questionDiv.querySelectorAll('input, select, textarea');
        inputs.forEach(function(input) {
          if (input.type === 'checkbox' || input.type === 'radio') {
            input.checked = false;
          } else {
            input.value = '';
          }
        });
      }
    }
    
    // Run on load and on input changes
    document.addEventListener('DOMContentLoaded', updateVisibility_%s);
    document.addEventListener('input', updateVisibility_%s);
  ", question_id, question_id, "true", question_id, question_id)  # TODO: Convert R condition to JS
  
  return(js_code)
}

