#' Geolocation Support for NomadForms
#'
#' Functions for capturing GPS coordinates and location data
#'
#' @name geolocation
NULL

#' GPS Location Question
#'
#' Captures the user's current location (requires permission)
#'
#' @param id Question ID
#' @param label Question label
#' @param required Is the question required?
#' @param show_map Show interactive map preview
#' @param high_accuracy Use high accuracy GPS (slower but more accurate)
#' @param timeout Timeout in milliseconds (default: 10000)
#'
#' @return Shiny input
#' @export
nf_gps_location <- function(id, label, required = FALSE, 
                              show_map = TRUE, high_accuracy = TRUE,
                              timeout = 10000) {
  
  htmltools::tags$div(
    class = "form-group nf-gps-location",
    htmltools::tags$label(
      `for` = id,
      label,
      if (required) htmltools::tags$span(class = "required-star", "*")
    ),
    htmltools::tags$div(
      class = "gps-controls",
      htmltools::tags$button(
        type = "button",
        id = paste0(id, "_capture"),
        class = "btn btn-primary",
        htmltools::HTML('<i class="fas fa-map-marker-alt"></i> Get My Location')
      ),
      htmltools::tags$span(
        id = paste0(id, "_status"),
        class = "gps-status",
        style = "margin-left: 10px;"
      )
    ),
    if (show_map) {
      htmltools::tags$div(
        id = paste0(id, "_map"),
        class = "gps-map",
        style = "width: 100%; height: 300px; margin-top: 10px; border-radius: 8px; display: none;"
      )
    },
    htmltools::tags$div(
      id = paste0(id, "_details"),
      class = "gps-details",
      style = "margin-top: 10px; display: none;"
    ),
    htmltools::tags$input(
      type = "hidden",
      id = paste0(id, "_latitude"),
      name = paste0(id, "_latitude")
    ),
    htmltools::tags$input(
      type = "hidden",
      id = paste0(id, "_longitude"),
      name = paste0(id, "_longitude")
    ),
    htmltools::tags$input(
      type = "hidden",
      id = paste0(id, "_accuracy"),
      name = paste0(id, "_accuracy")
    ),
    htmltools::tags$input(
      type = "hidden",
      id = paste0(id, "_timestamp"),
      name = paste0(id, "_timestamp")
    ),
    htmltools::tags$script(
      htmltools::HTML(sprintf("
        (function() {
          const captureBtn = document.getElementById('%s_capture');
          const status = document.getElementById('%s_status');
          const details = document.getElementById('%s_details');
          const latInput = document.getElementById('%s_latitude');
          const lonInput = document.getElementById('%s_longitude');
          const accInput = document.getElementById('%s_accuracy');
          const timeInput = document.getElementById('%s_timestamp');
          
          captureBtn.addEventListener('click', () => {
            if (!navigator.geolocation) {
              status.innerHTML = '<span style=\"color: red;\"><i class=\"fas fa-times-circle\"></i> Geolocation not supported</span>';
              return;
            }
            
            status.innerHTML = '<i class=\"fas fa-spinner fa-spin\"></i> Getting location...';
            captureBtn.disabled = true;
            
            const options = {
              enableHighAccuracy: %s,
              timeout: %d,
              maximumAge: 0
            };
            
            navigator.geolocation.getCurrentPosition(
              (position) => {
                const lat = position.coords.latitude;
                const lon = position.coords.longitude;
                const accuracy = position.coords.accuracy;
                const timestamp = new Date(position.timestamp).toISOString();
                
                // Save to hidden inputs
                latInput.value = lat;
                lonInput.value = lon;
                accInput.value = accuracy;
                timeInput.value = timestamp;
                
                // Update status
                status.innerHTML = '<span style=\"color: green;\"><i class=\"fas fa-check-circle\"></i> Location captured</span>';
                captureBtn.disabled = false;
                
                // Show details
                details.style.display = 'block';
                details.innerHTML = `
                  <div style=\"background: #f0fdf4; padding: 15px; border-radius: 8px; border-left: 4px solid #16a34a;\">
                    <p style=\"margin: 0 0 8px 0;\"><strong><i class=\"fas fa-map-pin\"></i> Coordinates:</strong></p>
                    <p style=\"margin: 0 0 5px 0; font-family: monospace;\">Latitude: ${lat.toFixed(6)}</p>
                    <p style=\"margin: 0 0 5px 0; font-family: monospace;\">Longitude: ${lon.toFixed(6)}</p>
                    <p style=\"margin: 0 0 5px 0;\"><strong><i class=\"fas fa-crosshairs\"></i> Accuracy:</strong> ±${accuracy.toFixed(0)} meters</p>
                    <p style=\"margin: 0;\"><strong><i class=\"fas fa-clock\"></i> Captured:</strong> ${new Date(timestamp).toLocaleString()}</p>
                  </div>
                `;
                
                // Show map if enabled
                %s
              },
              (error) => {
                let errorMsg = '';
                switch(error.code) {
                  case error.PERMISSION_DENIED:
                    errorMsg = 'Permission denied. Please allow location access.';
                    break;
                  case error.POSITION_UNAVAILABLE:
                    errorMsg = 'Location unavailable.';
                    break;
                  case error.TIMEOUT:
                    errorMsg = 'Request timed out.';
                    break;
                  default:
                    errorMsg = 'Unknown error occurred.';
                }
                status.innerHTML = `<span style=\"color: red;\"><i class=\"fas fa-times-circle\"></i> ${errorMsg}</span>`;
                captureBtn.disabled = false;
              },
              options
            );
          });
        })();
      ", id, id, id, id, id, id, id,
      tolower(as.character(high_accuracy)), timeout,
      if (show_map) sprintf("
        const mapDiv = document.getElementById('%s_map');
        mapDiv.style.display = 'block';
        mapDiv.innerHTML = `
          <iframe 
            width=\"100%%\" 
            height=\"100%%\" 
            frameborder=\"0\" 
            style=\"border:0; border-radius: 8px;\"
            src=\"https://maps.google.com/maps?q=${lat},${lon}&z=15&output=embed\"
          ></iframe>
        `;
      ", id) else ""))
    )
  )
}


#' Address Lookup Question
#'
#' Text input with address autocomplete (requires Google Places API)
#'
#' @param id Question ID
#' @param label Question label
#' @param required Is the question required?
#' @param api_key Google Places API key (optional, reads from env if not provided)
#' @param placeholder Placeholder text
#'
#' @return Shiny input
#' @export
nf_address_lookup <- function(id, label, required = FALSE, 
                                api_key = Sys.getenv("GOOGLE_PLACES_API_KEY"),
                                placeholder = "Start typing an address...") {
  
  htmltools::tags$div(
    class = "form-group nf-address-lookup",
    htmltools::tags$label(
      `for` = id,
      label,
      if (required) htmltools::tags$span(class = "required-star", "*")
    ),
    htmltools::tags$input(
      type = "text",
      id = id,
      name = id,
      class = "form-control address-autocomplete",
      placeholder = placeholder,
      required = required,
      autocomplete = "off"
    ),
    htmltools::tags$input(
      type = "hidden",
      id = paste0(id, "_latitude"),
      name = paste0(id, "_latitude")
    ),
    htmltools::tags$input(
      type = "hidden",
      id = paste0(id, "_longitude"),
      name = paste0(id, "_longitude")
    ),
    htmltools::tags$input(
      type = "hidden",
      id = paste0(id, "_place_id"),
      name = paste0(id, "_place_id")
    ),
    if (nchar(api_key) > 0) {
      htmltools::tags$script(
        src = paste0("https://maps.googleapis.com/maps/api/js?key=", api_key, "&libraries=places")
      )
    },
    htmltools::tags$p(
      class = "help-text",
      "Type to search for an address"
    )
  )
}


#' Distance Between Two Points
#'
#' Calculate distance between two GPS coordinates using Haversine formula
#'
#' @param lat1 Latitude of point 1
#' @param lon1 Longitude of point 1
#' @param lat2 Latitude of point 2
#' @param lon2 Longitude of point 2
#' @param unit Unit of distance: "km" (default), "miles", or "meters"
#'
#' @return Distance as numeric
#' @export
nf_distance <- function(lat1, lon1, lat2, lon2, unit = "km") {
  # Haversine formula
  R <- switch(unit,
    km = 6371,        # Earth radius in kilometers
    miles = 3959,     # Earth radius in miles
    meters = 6371000  # Earth radius in meters
  )
  
  lat1_rad <- lat1 * pi / 180
  lat2_rad <- lat2 * pi / 180
  delta_lat <- (lat2 - lat1) * pi / 180
  delta_lon <- (lon2 - lon1) * pi / 180
  
  a <- sin(delta_lat/2) * sin(delta_lat/2) +
       cos(lat1_rad) * cos(lat2_rad) *
       sin(delta_lon/2) * sin(delta_lon/2)
  
  c <- 2 * atan2(sqrt(a), sqrt(1-a))
  
  distance <- R * c
  
  return(distance)
}


#' Check if Point is Within Radius
#'
#' Check if a point is within a specified radius of a center point
#'
#' @param lat Point latitude
#' @param lon Point longitude
#' @param center_lat Center latitude
#' @param center_lon Center longitude
#' @param radius Radius distance
#' @param unit Unit of distance: "km", "miles", or "meters"
#'
#' @return Logical
#' @export
nf_within_radius <- function(lat, lon, center_lat, center_lon, radius, unit = "km") {
  distance <- nf_distance(lat, lon, center_lat, center_lon, unit)
  return(distance <= radius)
}

