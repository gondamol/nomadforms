#' Save a Survey Submission (with connection handling)
#'
#' Convenience wrapper around [nf_save_submission()] that manages the database
#' connection. The full set of answers for one completed form is written as a
#' single document row.
#'
#' @param survey_id Survey identifier (text)
#' @param session_id Session identifier
#' @param responses Named list of question ids to values
#' @param participant_id Optional participant identifier
#' @param project_id Optional project UUID
#' @param device_info Optional named list of device metadata
#' @param response_id Optional client-supplied UUID (idempotent upsert)
#' @param conn Optional existing connection; one is created if omitted
#'
#' @return List with success status and the submission id
#' @export
nf_save_survey <- function(survey_id,
                           session_id,
                           responses,
                           participant_id = NULL,
                           project_id = NULL,
                           device_info = NULL,
                           response_id = NULL,
                           conn = NULL) {

  created_conn <- FALSE
  if (is.null(conn)) {
    conn_string <- Sys.getenv("DATABASE_URL", "")
    conn <- tryCatch({
      if (conn_string != "") nf_database(connection_string = conn_string)
      else nf_database(dbname = Sys.getenv("DB_NAME", "nomadforms"),
                       user = Sys.getenv("DB_USER", "nomadforms"),
                       password = Sys.getenv("DB_PASSWORD", "nomadforms"),
                       host = Sys.getenv("DB_HOST", "localhost"),
                       port = as.integer(Sys.getenv("DB_PORT", "5432")))
    }, error = function(e) NULL)

    if (is.null(conn)) {
      return(list(success = FALSE,
                  message = "Database not connected.",
                  responses = responses))
    }
    created_conn <- TRUE
  }
  if (created_conn) on.exit(try(DBI::dbDisconnect(conn), silent = TRUE), add = TRUE)

  tryCatch({
    id <- nf_save_submission(conn, survey_id = survey_id, session_id = session_id,
                             responses = responses, participant_id = participant_id,
                             project_id = project_id, device_info = device_info,
                             response_id = response_id)
    list(success = TRUE, message = "Survey submission saved",
         response_id = id, session_id = session_id)
  }, error = function(e) {
    list(success = FALSE,
         message = paste("Error saving submission:", e$message),
         responses = responses)
  })
}


#' Get Responses for a Session
#'
#' Retrieves the long-format answers for a session from the `answers` view.
#'
#' @param session_id Session identifier
#' @param conn Optional database connection
#'
#' @return Data frame of answers (question_id, response_value, ...)
#' @export
nf_get_responses <- function(session_id, conn = NULL) {

  created_conn <- FALSE
  if (is.null(conn)) {
    conn_string <- Sys.getenv("DATABASE_URL", "")
    if (conn_string == "") stop("No database connection provided")
    conn <- nf_database(connection_string = conn_string)
    created_conn <- TRUE
  }
  if (created_conn) on.exit(try(DBI::dbDisconnect(conn), silent = TRUE), add = TRUE)

  DBI::dbGetQuery(conn, "
    SELECT question_id, response_value, submitted_at
    FROM answers WHERE session_id = $1
    ORDER BY submitted_at, question_id
  ", params = list(session_id))
}


#' Export a Survey's Responses to CSV (from the database)
#'
#' Reads a survey's answers from the `answers` view and writes a wide CSV, one
#' row per submission. For exporting an in-memory data frame instead, see
#' [nf_export_csv()].
#'
#' @param survey_id Survey identifier
#' @param filename Output filename
#' @param conn Optional database connection
#'
#' @return Path to the created file
#' @export
nf_export_survey_csv <- function(survey_id, filename = "survey_export.csv", conn = NULL) {

  created_conn <- FALSE
  if (is.null(conn)) {
    conn_string <- Sys.getenv("DATABASE_URL", "")
    if (conn_string == "") stop("No database connection provided")
    conn <- nf_database(connection_string = conn_string)
    created_conn <- TRUE
  }
  if (created_conn) on.exit(try(DBI::dbDisconnect(conn), silent = TRUE), add = TRUE)

  long <- DBI::dbGetQuery(conn, "
    SELECT submission_id, session_id, participant_id, submitted_at,
           question_id, response_value
    FROM answers WHERE survey_id = $1
    ORDER BY submission_id, question_id
  ", params = list(survey_id))

  if (nrow(long) == 0) stop("No responses found for this survey")

  # Pivot long -> wide in base R (no tidyr dependency).
  ids <- unique(long$submission_id)
  questions <- unique(long$question_id)
  wide <- data.frame(submission_id = ids, stringsAsFactors = FALSE)
  meta <- long[!duplicated(long$submission_id),
               c("submission_id", "session_id", "participant_id", "submitted_at")]
  wide <- merge(wide, meta, by = "submission_id")
  for (q in questions) {
    sub <- long[long$question_id == q, c("submission_id", "response_value")]
    wide[[q]] <- sub$response_value[match(wide$submission_id, sub$submission_id)]
  }

  utils::write.csv(wide, filename, row.names = FALSE, na = "")
  message(paste("Exported", nrow(wide), "submissions to", filename))
  filename
}
