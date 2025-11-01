#' NomadForms REST API Server
#'
#' Plumber API for survey data collection and management
#'
#' @export

library(plumber)
library(DBI)
library(RPostgres)
library(jsonlite)

# Database connection pool
db_pool <- NULL

#* @apiTitle NomadForms API
#* @apiDescription RESTful API for survey data collection
#* @apiVersion 1.0.0

#* Initialize database connection
#* @serializer unboxedJSON
#* @get /api/health
function() {
  list(
    status = "ok",
    message = "NomadForms API is running",
    version = "1.0.0",
    timestamp = Sys.time()
  )
}

#* Get all surveys
#* @serializer unboxedJSON
#* @get /api/surveys
function(req, res) {
  tryCatch({
    conn <- get_db_connection()
    surveys <- DBI::dbGetQuery(conn, "
      SELECT 
        survey_id,
        title,
        description,
        status,
        created_at,
        updated_at
      FROM surveys
      ORDER BY updated_at DESC
    ")
    
    list(
      success = TRUE,
      data = surveys,
      count = nrow(surveys)
    )
  }, error = function(e) {
    res$status <- 500
    list(
      success = FALSE,
      error = e$message
    )
  })
}

#* Get survey by ID
#* @param survey_id Survey UUID
#* @serializer unboxedJSON
#* @get /api/surveys/<survey_id>
function(survey_id, req, res) {
  tryCatch({
    conn <- get_db_connection()
    survey <- DBI::dbGetQuery(conn, "
      SELECT * FROM surveys WHERE survey_id = $1
    ", params = list(survey_id))
    
    if (nrow(survey) == 0) {
      res$status <- 404
      return(list(
        success = FALSE,
        error = "Survey not found"
      ))
    }
    
    # Get questions for this survey
    questions <- DBI::dbGetQuery(conn, "
      SELECT * FROM questions WHERE survey_id = $1 ORDER BY created_at
    ", params = list(survey_id))
    
    list(
      success = TRUE,
      data = list(
        survey = survey[1, ],
        questions = questions
      )
    )
  }, error = function(e) {
    res$status <- 500
    list(
      success = FALSE,
      error = e$message
    )
  })
}

#* Create new survey
#* @param title:string Survey title
#* @param description:string Survey description
#* @serializer unboxedJSON
#* @post /api/surveys
function(req, res) {
  tryCatch({
    body <- jsonlite::fromJSON(req$postBody)
    
    if (is.null(body$title) || nchar(body$title) == 0) {
      res$status <- 400
      return(list(
        success = FALSE,
        error = "Title is required"
      ))
    }
    
    conn <- get_db_connection()
    survey_id <- uuid::UUIDgenerate()
    
    DBI::dbExecute(conn, "
      INSERT INTO surveys (survey_id, title, description, status)
      VALUES ($1, $2, $3, $4)
    ", params = list(
      survey_id,
      body$title,
      body$description %||% "",
      "draft"
    ))
    
    list(
      success = TRUE,
      message = "Survey created successfully",
      data = list(survey_id = survey_id)
    )
  }, error = function(e) {
    res$status = 500
    list(
      success = FALSE,
      error = e$message
    )
  })
}

#* Submit survey response
#* @param survey_id:string Survey UUID
#* @param session_id:string Session UUID
#* @param responses:object Response data
#* @serializer unboxedJSON
#* @post /api/responses
function(req, res) {
  tryCatch({
    body <- jsonlite::fromJSON(req$postBody)
    
    if (is.null(body$survey_id) || is.null(body$session_id)) {
      res$status <- 400
      return(list(
        success = FALSE,
        error = "survey_id and session_id are required"
      ))
    }
    
    conn <- get_db_connection()
    response_id <- uuid::UUIDgenerate()
    
    # Save response
    DBI::dbExecute(conn, "
      INSERT INTO responses (
        response_id,
        survey_id,
        session_id,
        response_data,
        submitted_at,
        device_info,
        is_offline
      ) VALUES ($1, $2, $3, $4, $5, $6, $7)
    ", params = list(
      response_id,
      body$survey_id,
      body$session_id,
      jsonlite::toJSON(body$responses, auto_unbox = TRUE),
      Sys.time(),
      jsonlite::toJSON(body$device_info %||% list(), auto_unbox = TRUE),
      body$is_offline %||% FALSE
    ))
    
    list(
      success = TRUE,
      message = "Response saved successfully",
      data = list(response_id = response_id)
    )
  }, error = function(e) {
    res$status <- 500
    list(
      success = FALSE,
      error = e$message
    )
  })
}

#* Get responses for a survey
#* @param survey_id Survey UUID
#* @param format:string Output format (json, csv, xlsx)
#* @serializer unboxedJSON
#* @get /api/surveys/<survey_id>/responses
function(survey_id, format = "json", req, res) {
  tryCatch({
    conn <- get_db_connection()
    
    responses <- DBI::dbGetQuery(conn, "
      SELECT 
        response_id,
        session_id,
        response_data,
        submitted_at,
        device_info,
        is_offline,
        synced_at
      FROM responses
      WHERE survey_id = $1
      ORDER BY submitted_at DESC
    ", params = list(survey_id))
    
    if (format == "csv") {
      # Convert JSON responses to wide format
      res$setHeader("Content-Type", "text/csv")
      res$setHeader("Content-Disposition", 
                    sprintf('attachment; filename="survey_%s_responses.csv"', survey_id))
      
      # TODO: Implement wide format conversion
      return("CSV export not yet implemented")
    }
    
    list(
      success = TRUE,
      data = responses,
      count = nrow(responses)
    )
  }, error = function(e) {
    res$status <- 500
    list(
      success = FALSE,
      error = e$message
    )
  })
}

#* Get analytics for a survey
#* @param survey_id Survey UUID
#* @serializer unboxedJSON
#* @get /api/surveys/<survey_id>/analytics
function(survey_id, req, res) {
  tryCatch({
    conn <- get_db_connection()
    
    # Get response count
    total_responses <- DBI::dbGetQuery(conn, "
      SELECT COUNT(*) as count FROM responses WHERE survey_id = $1
    ", params = list(survey_id))$count
    
    # Get responses by day
    responses_by_day <- DBI::dbGetQuery(conn, "
      SELECT 
        DATE(submitted_at) as date,
        COUNT(*) as count
      FROM responses
      WHERE survey_id = $1
      GROUP BY DATE(submitted_at)
      ORDER BY date DESC
      LIMIT 30
    ", params = list(survey_id))
    
    # Get offline responses
    offline_count <- DBI::dbGetQuery(conn, "
      SELECT COUNT(*) as count 
      FROM responses 
      WHERE survey_id = $1 AND is_offline = TRUE
    ", params = list(survey_id))$count
    
    list(
      success = TRUE,
      data = list(
        total_responses = total_responses,
        offline_responses = offline_count,
        online_responses = total_responses - offline_count,
        responses_by_day = responses_by_day
      )
    )
  }, error = function(e) {
    res$status <- 500
    list(
      success = FALSE,
      error = e$message
    )
  })
}

#* Batch sync offline responses
#* @serializer unboxedJSON
#* @post /api/sync
function(req, res) {
  tryCatch({
    body <- jsonlite::fromJSON(req$postBody)
    
    if (is.null(body$responses) || length(body$responses) == 0) {
      res$status <- 400
      return(list(
        success = FALSE,
        error = "No responses to sync"
      ))
    }
    
    conn <- get_db_connection()
    synced_count <- 0
    errors <- list()
    
    for (i in seq_along(body$responses)) {
      resp <- body$responses[[i]]
      
      tryCatch({
        response_id <- resp$response_id %||% uuid::UUIDgenerate()
        
        DBI::dbExecute(conn, "
          INSERT INTO responses (
            response_id, survey_id, session_id, response_data,
            submitted_at, device_info, is_offline, synced_at
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
          ON CONFLICT (response_id) DO UPDATE SET
            synced_at = EXCLUDED.synced_at
        ", params = list(
          response_id,
          resp$survey_id,
          resp$session_id,
          jsonlite::toJSON(resp$responses, auto_unbox = TRUE),
          resp$submitted_at %||% Sys.time(),
          jsonlite::toJSON(resp$device_info %||% list(), auto_unbox = TRUE),
          TRUE,
          Sys.time()
        ))
        
        synced_count <- synced_count + 1
      }, error = function(e) {
        errors <- c(errors, list(list(index = i, error = e$message)))
      })
    }
    
    list(
      success = TRUE,
      message = sprintf("Synced %d of %d responses", synced_count, length(body$responses)),
      data = list(
        synced = synced_count,
        failed = length(errors),
        errors = errors
      )
    )
  }, error = function(e) {
    res$status <- 500
    list(
      success = FALSE,
      error = e$message
    )
  })
}

#* Export survey responses
#* @param survey_id Survey UUID
#* @param format:string Export format (csv, stata, spss, excel, r)
#* @get /api/surveys/<survey_id>/export
function(survey_id, format = "csv", req, res) {
  tryCatch({
    conn <- get_db_connection()
    
    # Get responses
    responses <- DBI::dbGetQuery(conn, "
      SELECT response_data FROM responses WHERE survey_id = $1
    ", params = list(survey_id))
    
    if (nrow(responses) == 0) {
      res$status <- 404
      return(list(
        success = FALSE,
        error = "No responses found"
      ))
    }
    
    # Parse JSON and convert to wide format
    # TODO: Implement proper conversion
    
    res$setHeader("Content-Disposition", 
                  sprintf('attachment; filename="survey_%s_export.%s"', 
                          survey_id, format))
    
    return("Export functionality coming soon")
    
  }, error = function(e) {
    res$status <- 500
    list(
      success = FALSE,
      error = e$message
    )
  })
}

# Helper functions
get_db_connection <- function() {
  conn_string <- Sys.getenv("DATABASE_URL", "")
  
  if (conn_string != "") {
    # Parse connection string
    # Format: postgresql://user:password@host:port/database
    parts <- regmatches(conn_string, regexec("postgresql://([^:]+):([^@]+)@([^:]+):([^/]+)/(.+)", conn_string))[[1]]
    
    DBI::dbConnect(
      RPostgres::Postgres(),
      user = parts[2],
      password = parts[3],
      host = parts[4],
      port = as.integer(parts[5]),
      dbname = parts[6]
    )
  } else {
    # Local development
    DBI::dbConnect(
      RPostgres::Postgres(),
      dbname = Sys.getenv("DB_NAME", "nomadforms"),
      host = Sys.getenv("DB_HOST", "localhost"),
      port = as.integer(Sys.getenv("DB_PORT", 5432)),
      user = Sys.getenv("DB_USER", "postgres"),
      password = Sys.getenv("DB_PASSWORD", "password")
    )
  }
}

`%||%` <- function(a, b) if (is.null(a)) b else a

