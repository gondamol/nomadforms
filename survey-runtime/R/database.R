#' Connect to PostgreSQL Database
#'
#' Creates a connection to a PostgreSQL database for storing survey responses.
#' Supports both self-hosted PostgreSQL and Supabase.
#'
#' @param host Database host (default: localhost)
#' @param port Database port (default: 5432)
#' @param dbname Database name
#' @param user Database user
#' @param password Database password
#' @param connection_string Optional connection string (overrides other params)
#'
#' @return DBI connection object
#' @export
#'
#' @examples
#' \dontrun{
#' # Connect to local PostgreSQL
#' conn <- nf_database(
#'   dbname = "nomadforms",
#'   user = "postgres",
#'   password = "password"
#' )
#'
#' # Connect via connection string (Supabase)
#' conn <- nf_database(
#'   connection_string = Sys.getenv("DATABASE_URL")
#' )
#' }
nf_database <- function(host = "localhost",
                        port = 5432,
                        dbname = NULL,
                        user = NULL,
                        password = NULL,
                        connection_string = NULL) {
  
  # Check for required packages
  if (!requireNamespace("DBI", quietly = TRUE)) {
    stop("Package 'DBI' is required. Please install it.")
  }
  if (!requireNamespace("RPostgres", quietly = TRUE)) {
    stop("Package 'RPostgres' is required. Please install it.")
  }
  
  # Use connection string if provided
  if (!is.null(connection_string)) {
    # Parse connection string
    # Format: postgresql://user:password@host:port/dbname
    conn <- DBI::dbConnect(
      RPostgres::Postgres(),
      connection_string = connection_string
    )
  } else {
    # Validate required parameters
    if (is.null(dbname) || is.null(user) || is.null(password)) {
      stop("dbname, user, and password are required when not using connection_string")
    }
    
    # Connect with individual parameters
    conn <- DBI::dbConnect(
      RPostgres::Postgres(),
      host = host,
      port = port,
      dbname = dbname,
      user = user,
      password = password
    )
  }
  
  message("Database connection established successfully")
  return(conn)
}


#' Initialize Database Schema
#'
#' Creates the required tables for NomadForms if they don't exist.
#'
#' @param conn DBI connection object from nf_database()
#'
#' @return TRUE if successful
#' @export
nf_init_schema <- function(conn) {
  
  # Projects table
  DBI::dbExecute(conn, "
    CREATE TABLE IF NOT EXISTS projects (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      name TEXT NOT NULL,
      created_by UUID,
      created_at TIMESTAMP DEFAULT NOW(),
      updated_at TIMESTAMP DEFAULT NOW(),
      codebook JSONB,
      survey_qmd TEXT,
      survey_r TEXT,
      settings JSONB
    );
  ")
  
  # Responses table
  DBI::dbExecute(conn, "
    CREATE TABLE IF NOT EXISTS responses (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
      participant_id TEXT,
      session_id TEXT NOT NULL,
      page_id TEXT,
      question_id TEXT NOT NULL,
      response_value TEXT,
      response_metadata JSONB,
      created_at TIMESTAMP DEFAULT NOW(),
      updated_at TIMESTAMP DEFAULT NOW(),
      synced_at TIMESTAMP,
      device_id TEXT,
      user_id UUID
    );
  ")
  
  # Audit log table
  DBI::dbExecute(conn, "
    CREATE TABLE IF NOT EXISTS audit_log (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
      response_id UUID REFERENCES responses(id) ON DELETE SET NULL,
      action TEXT NOT NULL,
      old_value JSONB,
      new_value JSONB,
      user_id UUID,
      device_id TEXT,
      timestamp TIMESTAMP DEFAULT NOW()
    );
  ")
  
  # Create indexes
  DBI::dbExecute(conn, "
    CREATE INDEX IF NOT EXISTS idx_responses_session 
    ON responses(session_id);
  ")
  
  DBI::dbExecute(conn, "
    CREATE INDEX IF NOT EXISTS idx_responses_participant 
    ON responses(participant_id);
  ")
  
  DBI::dbExecute(conn, "
    CREATE INDEX IF NOT EXISTS idx_responses_project 
    ON responses(project_id);
  ")
  
  message("Database schema initialized successfully")
  return(TRUE)
}


#' Save Survey Response
#'
#' Stores a survey response in the database with metadata.
#'
#' @param conn DBI connection object
#' @param project_id Project UUID
#' @param session_id Session identifier
#' @param question_id Question identifier
#' @param response_value Response value
#' @param participant_id Optional participant identifier
#' @param page_id Optional page identifier
#' @param metadata Optional metadata (list)
#'
#' @return Response UUID
#' @export
nf_save_response <- function(conn,
                              project_id,
                              session_id,
                              question_id,
                              response_value,
                              participant_id = NULL,
                              page_id = NULL,
                              metadata = NULL) {
  
  # Convert metadata to JSON if provided
  metadata_json <- if (!is.null(metadata)) {
    jsonlite::toJSON(metadata, auto_unbox = TRUE)
  } else {
    NULL
  }
  
  # Insert response
  result <- DBI::dbGetQuery(conn, "
    INSERT INTO responses (
      project_id,
      session_id,
      question_id,
      response_value,
      participant_id,
      page_id,
      response_metadata
    ) VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb)
    RETURNING id;
  ", params = list(
    project_id,
    session_id,
    question_id,
    as.character(response_value),
    participant_id,
    page_id,
    metadata_json
  ))
  
  return(result$id)
}

