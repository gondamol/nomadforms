#!/usr/bin/env Rscript
#' Run the NomadForms API Server
#'
#' This script starts the Plumber API server for NomadForms

library(plumber)

# Get port from environment or use default
port <- as.integer(Sys.getenv("API_PORT", 8080))
host <- Sys.getenv("API_HOST", "0.0.0.0")

cat("Starting NomadForms API Server...\n")
cat(sprintf("Server will run on http://%s:%d\n", host, port))
cat("Press Ctrl+C to stop\n\n")

# Load API
pr <- plumber::plumb("server.R")

# Add CORS headers
pr$registerHooks(list(
  preroute = function(req) {
    # Enable CORS
    req$headers$`Access-Control-Allow-Origin` <- "*"
    req$headers$`Access-Control-Allow-Methods` <- "GET, POST, PUT, DELETE, OPTIONS"
    req$headers$`Access-Control-Allow-Headers` <- "Content-Type, Authorization"
  }
))

# Add OPTIONS handler for CORS preflight
pr$handle("OPTIONS", "*", function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  res$setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
  res$setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization")
  res$status <- 200
  return(list())
})

# Run server
pr$run(
  host = host,
  port = port,
  swagger = TRUE  # Enable Swagger UI at /api/__docs__/
)

