#!/usr/bin/env Rscript
#' Run the NomadForms API server.
#'
#' CORS and auth are handled by filters inside server.R; this launcher only
#' locates the API definition, wires up the OpenAPI docs, and starts serving.

library(plumber)

port <- as.integer(Sys.getenv("API_PORT", "8000"))
host <- Sys.getenv("API_HOST", "0.0.0.0")

# Resolve server.R relative to this script so it works regardless of the
# process working directory (bare Rscript, Docker /app, etc.).
this_file <- sub("^--file=", "",
                 grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
api_dir <- if (!is.na(this_file)) dirname(normalizePath(this_file)) else getwd()

cat(sprintf("Starting NomadForms API on http://%s:%d\n", host, port))
cat(sprintf("API docs at http://%s:%d/__docs__/\n", host, port))

pr <- plumber::plumb(file.path(api_dir, "server.R"))
pr$setDocs(TRUE)

# Serve the mobile PWA (collect page, landing, service worker) as static files
# at /app so a phone can open http://<host>:<port>/app/ and collect data.
www_dir <- Sys.getenv("WWW_DIR", "")
if (www_dir == "") {
  for (cand in c(file.path(api_dir, "..", "www"), "/app/www"))
    if (dir.exists(cand)) { www_dir <- normalizePath(cand); break }
}
if (nzchar(www_dir) && dir.exists(www_dir)) {
  pr$mount("/app", plumber::PlumberStatic$new(www_dir))
  cat(sprintf("Serving PWA from %s at http://%s:%d/app/\n", www_dir, host, port))
} else {
  cat("No www directory found; PWA static files not served.\n")
}

pr$run(host = host, port = port)
