#' Export Survey Data
#'
#' Export survey responses in various formats
#'
#' @name export
NULL

#' Export to CSV
#'
#' Exports survey data to CSV format
#'
#' @param data Data frame of survey responses
#' @param filename Output filename
#' @param include_metadata Include metadata columns
#'
#' @return Path to created file
#' @export
nf_export_csv <- function(data, filename = "survey_export.csv", include_metadata = TRUE) {
  if (!include_metadata) {
    # Remove metadata columns
    metadata_cols <- c("session_id", "created_at", "updated_at", "device_info")
    data <- data[, !(names(data) %in% metadata_cols), drop = FALSE]
  }
  
  write.csv(data, filename, row.names = FALSE, fileEncoding = "UTF-8")
  message(paste("✓ Exported", nrow(data), "responses to", filename))
  return(normalizePath(filename))
}


#' Export to Excel
#'
#' Exports survey data to Excel format (.xlsx)
#'
#' @param data Data frame of survey responses
#' @param filename Output filename
#' @param include_metadata Include metadata columns
#'
#' @return Path to created file
#' @export
nf_export_excel <- function(data, filename = "survey_export.xlsx", include_metadata = TRUE) {
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop("Package 'openxlsx' is required for Excel export. Install it with: install.packages('openxlsx')")
  }
  
  if (!include_metadata) {
    metadata_cols <- c("session_id", "created_at", "updated_at", "device_info")
    data <- data[, !(names(data) %in% metadata_cols), drop = FALSE]
  }
  
  # Create workbook
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Survey Data")
  openxlsx::writeData(wb, "Survey Data", data)
  
  # Add formatting
  openxlsx::addStyle(wb, "Survey Data", 
                     style = openxlsx::createStyle(textDecoration = "bold"),
                     rows = 1, cols = 1:ncol(data), gridExpand = TRUE)
  
  openxlsx::saveWorkbook(wb, filename, overwrite = TRUE)
  message(paste("✓ Exported", nrow(data), "responses to", filename))
  return(normalizePath(filename))
}


#' Export to Stata (.dta)
#'
#' Exports survey data to Stata format
#'
#' @param data Data frame of survey responses
#' @param filename Output filename
#' @param version Stata version (default: 14)
#'
#' @return Path to created file
#' @export
nf_export_stata <- function(data, filename = "survey_export.dta", version = 14) {
  if (!requireNamespace("haven", quietly = TRUE)) {
    stop("Package 'haven' is required for Stata export. Install it with: install.packages('haven')")
  }
  
  # Convert dates to numeric (Stata doesn't handle POSIXct well)
  date_cols <- sapply(data, inherits, "POSIXct")
  if (any(date_cols)) {
    data[date_cols] <- lapply(data[date_cols], as.numeric)
  }
  
  haven::write_dta(data, filename, version = version)
  message(paste("✓ Exported", nrow(data), "responses to", filename, "(Stata", version, "format)"))
  return(normalizePath(filename))
}


#' Export to SPSS (.sav)
#'
#' Exports survey data to SPSS format
#'
#' @param data Data frame of survey responses
#' @param filename Output filename
#'
#' @return Path to created file
#' @export
nf_export_spss <- function(data, filename = "survey_export.sav") {
  if (!requireNamespace("haven", quietly = TRUE)) {
    stop("Package 'haven' is required for SPSS export. Install it with: install.packages('haven')")
  }
  
  haven::write_sav(data, filename)
  message(paste("✓ Exported", nrow(data), "responses to", filename))
  return(normalizePath(filename))
}


#' Export to R Data (.rds)
#'
#' Exports survey data to R's native format
#'
#' @param data Data frame of survey responses
#' @param filename Output filename
#' @param compress Compression method (default: "xz")
#'
#' @return Path to created file
#' @export
nf_export_rds <- function(data, filename = "survey_export.rds", compress = "xz") {
  saveRDS(data, filename, compress = compress)
  message(paste("✓ Exported", nrow(data), "responses to", filename))
  return(normalizePath(filename))
}


#' Export with Value Labels
#'
#' Exports survey data with value labels for coded responses
#'
#' @param data Data frame of survey responses
#' @param codebook Data frame mapping codes to labels (columns: question_id, code, label)
#' @param format Export format: "csv", "excel", "stata", or "spss"
#' @param filename Output filename
#'
#' @return Path to created file
#' @export
nf_export_labeled <- function(data, codebook, format = "csv", filename = NULL) {
  # Apply labels from codebook
  for (i in seq_len(nrow(codebook))) {
    question_id <- codebook$question_id[i]
    code <- codebook$code[i]
    label <- codebook$label[i]
    
    if (question_id %in% names(data)) {
      # Replace codes with labels
      data[[question_id]][data[[question_id]] == code] <- label
    }
  }
  
  # Set default filename if not provided
  if (is.null(filename)) {
    filename <- paste0("survey_export_labeled.", 
                      switch(format,
                             csv = "csv",
                             excel = "xlsx",
                             stata = "dta",
                             spss = "sav",
                             rds = "rds",
                             "csv"))
  }
  
  # Export using appropriate function
  switch(format,
         csv = nf_export_csv(data, filename),
         excel = nf_export_excel(data, filename),
         stata = nf_export_stata(data, filename),
         spss = nf_export_spss(data, filename),
         rds = nf_export_rds(data, filename),
         stop("Unsupported format. Use: csv, excel, stata, spss, or rds"))
}


#' Export to JSON
#'
#' Exports survey data to JSON format
#'
#' @param data Data frame of survey responses
#' @param filename Output filename
#' @param pretty Pretty print JSON (default: TRUE)
#'
#' @return Path to created file
#' @export
nf_export_json <- function(data, filename = "survey_export.json", pretty = TRUE) {
  json_str <- jsonlite::toJSON(data, pretty = pretty, auto_unbox = TRUE)
  writeLines(json_str, filename, useBytes = TRUE)
  message(paste("✓ Exported", nrow(data), "responses to", filename))
  return(normalizePath(filename))
}


#' Batch Export
#'
#' Exports survey data to multiple formats at once
#'
#' @param data Data frame of survey responses
#' @param formats Vector of formats: c("csv", "excel", "stata", "spss", "rds", "json")
#' @param prefix Filename prefix (default: "survey_export")
#' @param output_dir Output directory (default: current directory)
#'
#' @return Named vector of created file paths
#' @export
nf_export_batch <- function(data, 
                             formats = c("csv", "excel", "stata", "spss"),
                             prefix = "survey_export",
                             output_dir = ".") {
  
  # Create output directory if it doesn't exist
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  results <- list()
  
  for (format in formats) {
    ext <- switch(format,
                 csv = "csv",
                 excel = "xlsx",
                 stata = "dta",
                 spss = "sav",
                 rds = "rds",
                 json = "json",
                 stop("Unknown format:", format))
    
    filename <- file.path(output_dir, paste0(prefix, ".", ext))
    
    tryCatch({
      results[[format]] <- switch(format,
                                 csv = nf_export_csv(data, filename),
                                 excel = nf_export_excel(data, filename),
                                 stata = nf_export_stata(data, filename),
                                 spss = nf_export_spss(data, filename),
                                 rds = nf_export_rds(data, filename),
                                 json = nf_export_json(data, filename))
    }, error = function(e) {
      warning(paste("Failed to export to", format, ":", e$message))
      results[[format]] <- NA
    })
  }
  
  message(paste("\n✓ Batch export complete!", length(results[!is.na(results)]), "of", length(formats), "formats succeeded"))
  return(unlist(results))
}

