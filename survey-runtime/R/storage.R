#' Save Response with Connection Handling
#'
#' Saves a survey response with automatic connection management
#'
#' @param project_id Project UUID
#' @param session_id Session identifier
#' @param responses Named list of question IDs and response values
#' @param participant_id Optional participant identifier
#' @param page_id Optional page identifier
#' @param metadata Optional metadata (list)
#' @param conn Optional existing connection, or will create one
#'
#' @return List with success status and response IDs
#' @export
nf_save_survey <- function(project_id,
                            session_id,
                            responses,
                            participant_id = NULL,
                            page_id = NULL,
                            metadata = NULL,
                            conn = NULL) {
  
  # Create connection if not provided
  created_conn <- FALSE
  if (is.null(conn)) {
    # Try to get connection string from environment
    conn_string <- Sys.getenv("DATABASE_URL", "")
    
    if (conn_string == "") {
      # Fallback to local defaults for demo
      tryCatch({
        conn <- nf_database(
          dbname = "nomadforms",
          user = "postgres",
          password = Sys.getenv("DB_PASSWORD", "password")
        )
        created_conn <- TRUE
      }, error = function(e) {
        warning("Could not connect to database. Responses will only be logged.")
        return(list(
          success = FALSE,
          message = "Database not connected. See console for response data.",
          responses = responses
        ))
      })
    } else {
      conn <- nf_database(connection_string = conn_string)
      created_conn <- TRUE
    }
  }
  
  # Save each response
  response_ids <- list()
  
  tryCatch({
    for (question_id in names(responses)) {
      response_value <- responses[[question_id]]
      
      # Convert to string
      if (is.list(response_value)) {
        response_value <- jsonlite::toJSON(response_value, auto_unbox = TRUE)
      } else if (length(response_value) > 1) {
        response_value <- paste(response_value, collapse = ", ")
      }
      
      # Save to database
      response_id <- nf_save_response(
        conn = conn,
        project_id = project_id,
        session_id = session_id,
        question_id = question_id,
        response_value = as.character(response_value),
        participant_id = participant_id,
        page_id = page_id,
        metadata = metadata
      )
      
      response_ids[[question_id]] <- response_id
    }
    
    # Close connection if we created it
    if (created_conn) {
      DBI::dbDisconnect(conn)
    }
    
    return(list(
      success = TRUE,
      message = "Survey responses saved successfully",
      response_ids = response_ids,
      session_id = session_id
    ))
    
  }, error = function(e) {
    if (created_conn && !is.null(conn)) {
      try(DBI::dbDisconnect(conn), silent = TRUE)
    }
    
    return(list(
      success = FALSE,
      message = paste("Error saving responses:", e$message),
      responses = responses
    ))
  })
}


#' Get Responses for Session
#'
#' Retrieves all responses for a given session
#'
#' @param session_id Session identifier
#' @param conn Optional database connection
#'
#' @return Data frame of responses
#' @export
nf_get_responses <- function(session_id, conn = NULL) {
  
  created_conn <- FALSE
  if (is.null(conn)) {
    conn_string <- Sys.getenv("DATABASE_URL", "")
    if (conn_string != "") {
      conn <- nf_database(connection_string = conn_string)
      created_conn <- TRUE
    } else {
      stop("No database connection provided")
    }
  }
  
  tryCatch({
    responses <- DBI::dbGetQuery(conn, "
      SELECT 
        question_id,
        response_value,
        created_at,
        updated_at
      FROM responses
      WHERE session_id = $1
      ORDER BY created_at
    ", params = list(session_id))
    
    if (created_conn) {
      DBI::dbDisconnect(conn)
    }
    
    return(responses)
    
  }, error = function(e) {
    if (created_conn && !is.null(conn)) {
      try(DBI::dbDisconnect(conn), silent = TRUE)
    }
    stop(paste("Error retrieving responses:", e$message))
  })
}


#' Export Responses to CSV
#'
#' Exports all responses for a project to CSV format
#'
#' @param project_id Project UUID
#' @param filename Output filename
#' @param conn Optional database connection
#'
#' @return Path to created file
#' @export
nf_export_csv <- function(project_id, filename = "survey_export.csv", conn = NULL) {
  
  created_conn <- FALSE
  if (is.null(conn)) {
    conn_string <- Sys.getenv("DATABASE_URL", "")
    if (conn_string != "") {
      conn <- nf_database(connection_string = conn_string)
      created_conn <- TRUE
    } else {
      stop("No database connection provided")
    }
  }
  
  tryCatch({
    # Get responses in wide format
    responses <- DBI::dbGetQuery(conn, "
      SELECT 
        session_id,
        participant_id,
        question_id,
        response_value,
        created_at
      FROM responses
      WHERE project_id = $1
      ORDER BY session_id, created_at
    ", params = list(project_id))
    
    if (nrow(responses) == 0) {
      stop("No responses found for this project")
    }
    
    # Pivot to wide format
    wide_data <- tidyr::pivot_wider(
      responses,
      id_cols = c(session_id, participant_id, created_at),
      names_from = question_id,
      values_from = response_value
    )
    
    # Write to CSV
    write.csv(wide_data, filename, row.names = FALSE)
    
    if (created_conn) {
      DBI::dbDisconnect(conn)
    }
    
    message(paste("Exported", nrow(wide_data), "responses to", filename))
    return(filename)
    
  }, error = function(e) {
    if (created_conn && !is.null(conn)) {
      try(DBI::dbDisconnect(conn), silent = TRUE)
    }
    stop(paste("Error exporting data:", e$message))
  })
}

