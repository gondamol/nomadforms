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
#' @examples
#' \dontrun{
#' conn <- nf_database(
#'   dbname = "nomadforms",
#'   user = "postgres",
#'   password = "password"
#' )
#' nf_init_schema(conn)
#' }
nf_init_schema <- function(conn) {

  # Survey definitions.
  DBI::dbExecute(conn, "
    CREATE TABLE IF NOT EXISTS projects (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      name TEXT NOT NULL,
      description TEXT,
      created_by UUID,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW(),
      codebook JSONB,
      survey_qmd TEXT,
      survey_r TEXT,
      settings JSONB DEFAULT '{}'::jsonb
    );
  ")

  # Canonical document store: one row per completed form. Mirrors
  # database/migrations/002_submissions.sql so an R-only user can bootstrap
  # without running the SQL migrations by hand.
  DBI::dbExecute(conn, "
    CREATE TABLE IF NOT EXISTS submissions (
      response_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      survey_id TEXT NOT NULL,
      project_id UUID REFERENCES projects(id) ON DELETE SET NULL,
      session_id TEXT NOT NULL,
      participant_id TEXT,
      response_data JSONB NOT NULL DEFAULT '{}'::jsonb,
      device_info JSONB DEFAULT '{}'::jsonb,
      is_offline BOOLEAN DEFAULT FALSE,
      status TEXT NOT NULL DEFAULT 'submitted'
        CHECK (status IN ('submitted','approved','rejected','deleted')),
      submitted_at TIMESTAMPTZ DEFAULT NOW(),
      synced_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW()
    );
  ")

  DBI::dbExecute(conn, "
    CREATE INDEX IF NOT EXISTS idx_submissions_survey ON submissions(survey_id);
  ")
  DBI::dbExecute(conn, "
    CREATE INDEX IF NOT EXISTS idx_submissions_session ON submissions(session_id);
  ")

  # EAV projection used by the export/analysis path.
  DBI::dbExecute(conn, "
    CREATE OR REPLACE VIEW answers AS
    SELECT s.response_id AS submission_id, s.survey_id, s.project_id,
           s.session_id, s.participant_id, s.submitted_at, s.status,
           kv.key AS question_id, kv.value AS response_value
    FROM submissions s,
         LATERAL jsonb_each_text(s.response_data) AS kv(key, value)
    WHERE s.status <> 'deleted';
  ")

  message("Database schema initialized successfully")
  return(TRUE)
}


#' Save a Completed Survey Submission
#'
#' Stores one completed form as a single document row in `submissions`. The
#' whole set of answers is the unit that is written and synced, which is what
#' makes offline retries idempotent.
#'
#' @param conn DBI connection object
#' @param survey_id Survey identifier (text; matches the PWA's survey id)
#' @param session_id Session identifier
#' @param responses Named list of question ids to values
#' @param participant_id Optional participant identifier
#' @param project_id Optional project UUID this survey belongs to
#' @param device_info Optional named list of device metadata
#' @param response_id Optional client-supplied UUID (enables idempotent upsert)
#'
#' @return Submission UUID
#' @export
#' @examples
#' \dontrun{
#' conn <- nf_database(connection_string = Sys.getenv("DATABASE_URL"))
#' nf_save_submission(
#'   conn,
#'   survey_id = "household_survey",
#'   session_id = "session-001",
#'   responses = list(age = 34, county = "Turkana")
#' )
#' }
nf_save_submission <- function(conn,
                               survey_id,
                               session_id,
                               responses,
                               participant_id = NULL,
                               project_id = NULL,
                               device_info = NULL,
                               response_id = NULL) {

  data_json   <- jsonlite::toJSON(responses, auto_unbox = TRUE)
  device_json <- jsonlite::toJSON(device_info %||% list(), auto_unbox = TRUE)

  if (is.null(response_id)) {
    result <- DBI::dbGetQuery(conn, "
      INSERT INTO submissions
        (survey_id, project_id, session_id, participant_id, response_data, device_info)
      VALUES ($1, $2, $3, $4, $5::jsonb, $6::jsonb)
      RETURNING response_id;
    ", params = list(survey_id, project_id, session_id, participant_id,
                     data_json, device_json))
    return(result$response_id)
  }

  DBI::dbExecute(conn, "
    INSERT INTO submissions
      (response_id, survey_id, project_id, session_id, participant_id,
       response_data, device_info)
    VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7::jsonb)
    ON CONFLICT (response_id) DO UPDATE
      SET response_data = EXCLUDED.response_data, updated_at = NOW();
  ", params = list(response_id, survey_id, project_id, session_id,
                   participant_id, data_json, device_json))
  response_id
}

