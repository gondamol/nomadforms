#' NomadForms REST API
#'
#' Plumber API for survey definition, mobile data collection, offline sync,
#' submission management and export. Backed by the canonical `submissions`
#' document store (see database/migrations/002_submissions.sql).
#'
#' Survey definitions live in the `projects` table; each completed form is one
#' row in `submissions`; the `answers` view exposes the long/EAV shape used by
#' exports.

library(plumber)
library(DBI)
library(RPostgres)
library(jsonlite)

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

# --- Connection handling ---------------------------------------------------
# One short-lived connection per request. Survey data collection is low-QPS and
# a pool adds failure modes (stale sockets after a laptop sleeps) that are not
# worth it at this scale.
get_db_connection <- function() {
  conn_string <- Sys.getenv("DATABASE_URL", "")
  if (conn_string != "") {
    return(DBI::dbConnect(RPostgres::Postgres(), connection_string = conn_string))
  }
  DBI::dbConnect(
    RPostgres::Postgres(),
    dbname   = Sys.getenv("DB_NAME", "nomadforms"),
    host     = Sys.getenv("DB_HOST", "localhost"),
    port     = as.integer(Sys.getenv("DB_PORT", "5432")),
    user     = Sys.getenv("DB_USER", "nomadforms"),
    password = Sys.getenv("DB_PASSWORD", "nomadforms")
  )
}

# Run fn(conn) and always disconnect, even on error.
with_db <- function(fn) {
  conn <- get_db_connection()
  on.exit(try(DBI::dbDisconnect(conn), silent = TRUE), add = TRUE)
  fn(conn)
}

# Pivot a data frame of submissions (response_data JSONB as text) into wide
# rows keyed by question id. Base R only -- no tidyr dependency in the API.
submissions_to_wide <- function(rows) {
  if (nrow(rows) == 0) return(data.frame())
  parsed <- lapply(rows$response_data, function(x) {
    if (is.na(x) || x == "") list() else jsonlite::fromJSON(x, simplifyVector = TRUE)
  })
  all_keys <- unique(unlist(lapply(parsed, names)))
  base_cols <- data.frame(
    response_id  = rows$response_id,
    survey_id    = rows$survey_id,
    session_id   = rows$session_id,
    submitted_at = rows$submitted_at,
    stringsAsFactors = FALSE
  )
  for (k in all_keys) {
    base_cols[[k]] <- vapply(parsed, function(p) {
      v <- p[[k]]
      if (is.null(v)) NA_character_
      else if (length(v) > 1) paste(v, collapse = "; ")
      else as.character(v)
    }, character(1))
  }
  base_cols
}

# --- Global filters --------------------------------------------------------

#* CORS so the PWA (served from another origin / a device) can call the API.
#* @filter cors
function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", Sys.getenv("CORS_ORIGIN", "*"))
  res$setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
  res$setHeader("Access-Control-Allow-Headers", "Content-Type, X-API-Key")
  if (req$REQUEST_METHOD == "OPTIONS") {
    res$status <- 200
    return(list())
  }
  plumber::forward()
}

#* Optional API-key gate. Enabled only when API_KEY is set, so local dev and
#* the demo stay friction-free while production can lock write access down.
#* @filter auth
function(req, res) {
  required <- Sys.getenv("API_KEY", "")
  open_paths <- c("/api/health", "/__docs__", "/openapi.json")
  is_open <- required == "" ||
    any(startsWith(req$PATH_INFO, open_paths)) ||
    req$REQUEST_METHOD == "OPTIONS"
  if (is_open) return(plumber::forward())
  if (identical(req$HTTP_X_API_KEY, required)) return(plumber::forward())
  res$status <- 401
  list(success = FALSE, error = "Invalid or missing X-API-Key")
}

# --- Meta ------------------------------------------------------------------

#* @apiTitle NomadForms API
#* @apiDescription Offline-capable survey data collection for field research.
#* @apiVersion 1.0.0

#* Liveness + database reachability check
#* @serializer unboxedJSON
#* @get /api/health
function(res) {
  db_ok <- tryCatch(with_db(function(conn) DBI::dbGetQuery(conn, "SELECT 1")[[1]] == 1),
                    error = function(e) FALSE)
  if (!db_ok) res$status <- 503
  list(status = if (db_ok) "ok" else "degraded",
       database = if (db_ok) "connected" else "unreachable",
       version = "1.0.0",
       timestamp = format(Sys.time(), tz = "UTC", usetz = TRUE))
}

# --- Surveys (stored as projects) ------------------------------------------

#* List all surveys
#* @serializer unboxedJSON
#* @get /api/surveys
function(res) {
  tryCatch(with_db(function(conn) {
    surveys <- DBI::dbGetQuery(conn, "
      SELECT id AS survey_id, name AS title, description, created_at, updated_at
      FROM projects ORDER BY updated_at DESC")
    list(success = TRUE, data = surveys, count = nrow(surveys))
  }), error = function(e) { res$status <- 500; list(success = FALSE, error = e$message) })
}

#* Get one survey with its question definitions (from the codebook)
#* @param survey_id Survey UUID
#* @serializer unboxedJSON
#* @get /api/surveys/<survey_id>
function(survey_id, res) {
  tryCatch(with_db(function(conn) {
    survey <- DBI::dbGetQuery(conn, "
      SELECT id AS survey_id, name AS title, description, codebook, settings,
             created_at, updated_at
      FROM projects WHERE id = $1", params = list(survey_id))
    if (nrow(survey) == 0) { res$status <- 404; return(list(success = FALSE, error = "Survey not found")) }
    codebook <- if (!is.na(survey$codebook[1])) jsonlite::fromJSON(survey$codebook[1]) else list()
    list(success = TRUE, data = list(
      survey = list(survey_id = survey$survey_id[1], title = survey$title[1],
                    description = survey$description[1]),
      questions = codebook))
  }), error = function(e) { res$status <- 500; list(success = FALSE, error = e$message) })
}

#* Create a survey
#* @serializer unboxedJSON
#* @post /api/surveys
function(req, res) {
  tryCatch(with_db(function(conn) {
    body <- jsonlite::fromJSON(req$postBody)
    if (is.null(body$title) || nchar(body$title) == 0) {
      res$status <- 400; return(list(success = FALSE, error = "title is required"))
    }
    codebook <- if (!is.null(body$questions))
      jsonlite::toJSON(body$questions, auto_unbox = TRUE) else "[]"
    out <- DBI::dbGetQuery(conn, "
      INSERT INTO projects (name, description, codebook)
      VALUES ($1, $2, $3::jsonb) RETURNING id",
      params = list(body$title, body$description %||% "", codebook))
    res$status <- 201
    list(success = TRUE, message = "Survey created", data = list(survey_id = out$id[1]))
  }), error = function(e) { res$status <- 500; list(success = FALSE, error = e$message) })
}

#* Update a survey's title, description and question definitions
#* @param survey_id Survey UUID
#* @serializer unboxedJSON
#* @put /api/surveys/<survey_id>
function(survey_id, req, res) {
  tryCatch(with_db(function(conn) {
    body <- jsonlite::fromJSON(req$postBody, simplifyVector = TRUE)
    if (is.null(body$title) || nchar(body$title) == 0) {
      res$status <- 400; return(list(success = FALSE, error = "title is required"))
    }
    codebook <- if (!is.null(body$questions))
      jsonlite::toJSON(body$questions, auto_unbox = TRUE) else "[]"
    n <- DBI::dbExecute(conn, "
      UPDATE projects SET name = $1, description = $2, codebook = $3::jsonb, updated_at = NOW()
      WHERE id = $4",
      params = list(body$title, body$description %||% "", codebook, survey_id))
    if (n == 0) { res$status <- 404; return(list(success = FALSE, error = "Survey not found")) }
    list(success = TRUE, message = "Survey updated", data = list(survey_id = survey_id))
  }), error = function(e) { res$status <- 500; list(success = FALSE, error = e$message) })
}

# --- Submissions -----------------------------------------------------------

# Shared insert used by both the single-submit and batch-sync endpoints.
# Client may supply response_id; if it does, re-sending the same submission is
# idempotent (ON CONFLICT) so a flaky field connection never double-counts.
insert_submission <- function(conn, s, mark_synced = FALSE) {
  data_json   <- jsonlite::toJSON(s$responses %||% list(), auto_unbox = TRUE)
  device_json <- jsonlite::toJSON(s$device_info %||% list(), auto_unbox = TRUE)
  rid <- s$response_id %||% NA
  if (is.na(rid)) {
    out <- DBI::dbGetQuery(conn, "
      INSERT INTO submissions
        (survey_id, session_id, participant_id, response_data, device_info,
         is_offline, submitted_at, synced_at)
      VALUES ($1,$2,$3,$4::jsonb,$5::jsonb,$6,$7,$8) RETURNING response_id",
      params = list(s$survey_id, s$session_id, s$participant_id %||% NA,
                    data_json, device_json, s$is_offline %||% FALSE,
                    s$submitted_at %||% format(Sys.time()),
                    if (mark_synced) format(Sys.time()) else NA))
    return(out$response_id[1])
  }
  DBI::dbExecute(conn, "
    INSERT INTO submissions
      (response_id, survey_id, session_id, participant_id, response_data,
       device_info, is_offline, submitted_at, synced_at)
    VALUES ($1,$2,$3,$4,$5::jsonb,$6::jsonb,$7,$8,$9)
    ON CONFLICT (response_id) DO UPDATE
      SET synced_at = EXCLUDED.synced_at, updated_at = NOW()",
    params = list(rid, s$survey_id, s$session_id, s$participant_id %||% NA,
                  data_json, device_json, s$is_offline %||% FALSE,
                  s$submitted_at %||% format(Sys.time()),
                  if (mark_synced) format(Sys.time()) else NA))
  rid
}

#* Submit one completed form
#* @serializer unboxedJSON
#* @post /api/responses
function(req, res) {
  tryCatch(with_db(function(conn) {
    body <- jsonlite::fromJSON(req$postBody, simplifyVector = TRUE)
    if (is.null(body$survey_id) || is.null(body$session_id)) {
      res$status <- 400
      return(list(success = FALSE, error = "survey_id and session_id are required"))
    }
    rid <- insert_submission(conn, body)
    res$status <- 201
    list(success = TRUE, message = "Response saved", data = list(response_id = rid))
  }), error = function(e) { res$status <- 500; list(success = FALSE, error = e$message) })
}

#* Batch-sync offline submissions (idempotent per response_id)
#* @serializer unboxedJSON
#* @post /api/sync
function(req, res) {
  tryCatch(with_db(function(conn) {
    body <- jsonlite::fromJSON(req$postBody, simplifyVector = FALSE)
    items <- body$responses
    if (is.null(items) || length(items) == 0) {
      res$status <- 400; return(list(success = FALSE, error = "No responses to sync"))
    }
    synced <- 0; errors <- list()
    for (i in seq_along(items)) {
      ok <- tryCatch({ insert_submission(conn, items[[i]], mark_synced = TRUE); TRUE },
                     error = function(e) { errors[[length(errors) + 1]] <<-
                       list(index = i, error = e$message); FALSE })
      if (ok) synced <- synced + 1
    }
    list(success = TRUE,
         message = sprintf("Synced %d of %d", synced, length(items)),
         data = list(synced = synced, failed = length(errors), errors = errors))
  }), error = function(e) { res$status <- 500; list(success = FALSE, error = e$message) })
}

#* List submissions for a survey (with search/filter/pagination)
#* @param survey_id Survey UUID
#* @param q:string Optional full-text match within answer values
#* @param status:string Optional status filter
#* @param limit:int Page size (default 50)
#* @param offset:int Page offset (default 0)
#* @serializer unboxedJSON
#* @get /api/surveys/<survey_id>/responses
function(survey_id, q = "", status = "", limit = 50, offset = 0, res) {
  tryCatch(with_db(function(conn) {
    limit <- min(as.integer(limit), 500); offset <- as.integer(offset)
    clauses <- "survey_id = $1 AND status <> 'deleted'"; params <- list(survey_id)
    if (nzchar(status)) { params <- c(params, status)
      clauses <- paste0(clauses, sprintf(" AND status = $%d", length(params))) }
    if (nzchar(q)) { params <- c(params, paste0("%", q, "%"))
      clauses <- paste0(clauses, sprintf(" AND response_data::text ILIKE $%d", length(params))) }
    total <- DBI::dbGetQuery(conn, sprintf(
      "SELECT COUNT(*) n FROM submissions WHERE %s", clauses), params = params)$n
    rows <- DBI::dbGetQuery(conn, sprintf("
      SELECT response_id, survey_id, session_id, participant_id, response_data,
             is_offline, status, submitted_at, synced_at
      FROM submissions WHERE %s ORDER BY submitted_at DESC
      LIMIT %d OFFSET %d", clauses, limit, offset), params = params)
    rows$response_data <- lapply(rows$response_data, function(x)
      if (is.na(x)) list() else jsonlite::fromJSON(x))
    list(success = TRUE, data = rows, count = nrow(rows),
         total = total, limit = limit, offset = offset)
  }), error = function(e) { res$status <- 500; list(success = FALSE, error = e$message) })
}

#* Change a submission's status (approve / reject / delete / restore)
#* @param response_id Submission UUID
#* @param action:string approve|reject|delete|restore
#* @serializer unboxedJSON
#* @put /api/responses/<response_id>/status
function(response_id, req, res) {
  tryCatch(with_db(function(conn) {
    body <- jsonlite::fromJSON(req$postBody)
    new_status <- switch(body$action %||% "",
      approve = "approved", reject = "rejected",
      delete = "deleted", restore = "submitted", NULL)
    if (is.null(new_status)) {
      res$status <- 400
      return(list(success = FALSE, error = "action must be approve|reject|delete|restore"))
    }
    n <- DBI::dbExecute(conn,
      "UPDATE submissions SET status = $1 WHERE response_id = $2",
      params = list(new_status, response_id))
    if (n == 0) { res$status <- 404; return(list(success = FALSE, error = "Submission not found")) }
    DBI::dbExecute(conn, "
      INSERT INTO audit_log (response_id, action, new_value)
      VALUES ($1, $2, $3::jsonb)",
      params = list(response_id,
                    if (new_status == "deleted") "delete" else "update",
                    jsonlite::toJSON(list(status = new_status), auto_unbox = TRUE)))
    list(success = TRUE, data = list(response_id = response_id, status = new_status))
  }), error = function(e) { res$status <- 500; list(success = FALSE, error = e$message) })
}

# --- Analytics + export ----------------------------------------------------

#* Dashboard analytics for a survey
#* @param survey_id Survey UUID
#* @serializer unboxedJSON
#* @get /api/surveys/<survey_id>/analytics
function(survey_id, res) {
  tryCatch(with_db(function(conn) {
    total <- DBI::dbGetQuery(conn, "
      SELECT COUNT(*) n FROM submissions
      WHERE survey_id = $1 AND status <> 'deleted'", params = list(survey_id))$n
    offline <- DBI::dbGetQuery(conn, "
      SELECT COUNT(*) n FROM submissions
      WHERE survey_id = $1 AND is_offline AND status <> 'deleted'",
      params = list(survey_id))$n
    by_day <- DBI::dbGetQuery(conn, "
      SELECT DATE(submitted_at) AS date, COUNT(*) AS count
      FROM submissions WHERE survey_id = $1 AND status <> 'deleted'
      GROUP BY DATE(submitted_at) ORDER BY date DESC LIMIT 30", params = list(survey_id))
    list(success = TRUE, data = list(
      total_responses = total, offline_responses = offline,
      online_responses = total - offline, responses_by_day = by_day))
  }), error = function(e) { res$status <- 500; list(success = FALSE, error = e$message) })
}

# Fetch a survey's submissions as a wide data frame (shared by both exports).
export_wide <- function(survey_id) {
  with_db(function(conn) {
    rows <- DBI::dbGetQuery(conn, "
      SELECT response_id, survey_id, session_id, response_data, submitted_at
      FROM submissions WHERE survey_id = $1 AND status <> 'deleted'
      ORDER BY submitted_at", params = list(survey_id))
    submissions_to_wide(rows)
  })
}

#* Export submissions as CSV (one row per submission, one column per question)
#* @param survey_id Survey UUID
#* @serializer contentType list(type="text/csv; charset=utf-8")
#* @get /api/surveys/<survey_id>/export.csv
function(survey_id, res) {
  wide <- export_wide(survey_id)
  res$setHeader("Content-Disposition",
    sprintf('attachment; filename="survey_%s.csv"', survey_id))
  # Serialize to CSV text via an in-memory connection (no readr dependency).
  tc <- textConnection("csv_out", "w", local = TRUE)
  utils::write.csv(wide, tc, row.names = FALSE, na = "")
  close(tc)
  paste(csv_out, collapse = "\n")
}

#* Export submissions as wide JSON
#* @param survey_id Survey UUID
#* @serializer unboxedJSON
#* @get /api/surveys/<survey_id>/export.json
function(survey_id, res) {
  wide <- export_wide(survey_id)
  res$setHeader("Content-Disposition",
    sprintf('attachment; filename="survey_%s.json"', survey_id))
  wide
}
