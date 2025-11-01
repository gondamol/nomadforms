#' Multimedia Support for NomadForms
#'
#' Functions for handling images, audio, video, and file uploads
#'
#' @name multimedia
NULL

#' Image Upload Question
#'
#' Creates a question that allows image upload/capture
#'
#' @param id Question ID
#' @param label Question label
#' @param required Is the question required?
#' @param accept Accepted file types (default: image/*)
#' @param max_size Maximum file size in MB (default: 5)
#' @param capture Camera mode: "user" (front), "environment" (back), or NULL
#' @param multiple Allow multiple files
#'
#' @return Shiny input
#' @export
nf_image_upload <- function(id, label, required = FALSE, 
                              accept = "image/*", max_size = 5,
                              capture = "environment", multiple = FALSE) {
  
  capture_attr <- if (!is.null(capture)) paste0('capture="', capture, '"') else ""
  multiple_attr <- if (multiple) "multiple" else ""
  
  htmltools::tags$div(
    class = "form-group nf-image-upload",
    htmltools::tags$label(
      `for` = id,
      label,
      if (required) htmltools::tags$span(class = "required-star", "*")
    ),
    htmltools::tags$div(
      class = "image-upload-container",
      htmltools::tags$input(
        type = "file",
        id = id,
        name = id,
        accept = accept,
        required = required,
        `data-max-size` = max_size * 1024 * 1024,  # Convert to bytes
        htmltools::HTML(capture_attr),
        htmltools::HTML(multiple_attr),
        class = "image-upload-input",
        style = "display: none;"
      ),
      htmltools::tags$button(
        type = "button",
        class = "btn btn-secondary upload-trigger",
        onclick = sprintf("document.getElementById('%s').click()", id),
        htmltools::HTML('<i class="fas fa-camera"></i> Take Photo / Upload')
      ),
      htmltools::tags$div(
        class = "image-preview",
        id = paste0(id, "_preview")
      )
    ),
    htmltools::tags$p(
      class = "help-text",
      paste0("Max file size: ", max_size, " MB")
    ),
    htmltools::tags$script(
      htmltools::HTML(sprintf("
        document.getElementById('%s').addEventListener('change', function(e) {
          const files = e.target.files;
          const maxSize = parseInt(e.target.getAttribute('data-max-size'));
          const preview = document.getElementById('%s_preview');
          preview.innerHTML = '';
          
          Array.from(files).forEach(file => {
            if (file.size > maxSize) {
              alert('File too large: ' + file.name + '. Max size is %d MB.');
              return;
            }
            
            const reader = new FileReader();
            reader.onload = function(e) {
              const img = document.createElement('img');
              img.src = e.target.result;
              img.className = 'preview-image';
              img.style.maxWidth = '200px';
              img.style.maxHeight = '200px';
              img.style.margin = '10px';
              img.style.borderRadius = '8px';
              img.style.boxShadow = '0 2px 8px rgba(0,0,0,0.1)';
              preview.appendChild(img);
            };
            reader.readAsDataURL(file);
          });
        });
      ", id, id, max_size))
    )
  )
}


#' Audio Recording Question
#'
#' Creates a question that allows audio recording or upload
#'
#' @param id Question ID
#' @param label Question label
#' @param required Is the question required?
#' @param max_duration Maximum recording duration in seconds (default: 300)
#'
#' @return Shiny input
#' @export
nf_audio_record <- function(id, label, required = FALSE, max_duration = 300) {
  
  htmltools::tags$div(
    class = "form-group nf-audio-record",
    htmltools::tags$label(
      `for` = id,
      label,
      if (required) htmltools::tags$span(class = "required-star", "*")
    ),
    htmltools::tags$div(
      class = "audio-recorder",
      htmltools::tags$button(
        type = "button",
        id = paste0(id, "_record"),
        class = "btn btn-danger",
        htmltools::HTML('<i class="fas fa-microphone"></i> Start Recording')
      ),
      htmltools::tags$button(
        type = "button",
        id = paste0(id, "_stop"),
        class = "btn btn-secondary",
        disabled = "disabled",
        style = "display: none;",
        htmltools::HTML('<i class="fas fa-stop"></i> Stop')
      ),
      htmltools::tags$div(
        id = paste0(id, "_timer"),
        class = "recording-timer",
        style = "display: none; margin: 10px 0; font-weight: bold;",
        "00:00"
      ),
      htmltools::tags$audio(
        id = paste0(id, "_player"),
        controls = NA,
        style = "display: none; width: 100%; margin-top: 10px;"
      ),
      htmltools::tags$input(
        type = "hidden",
        id = id,
        name = id,
        required = required
      )
    ),
    htmltools::tags$p(
      class = "help-text",
      paste0("Max duration: ", format_duration(max_duration))
    ),
    htmltools::tags$script(
      htmltools::HTML(sprintf("
        (function() {
          let mediaRecorder;
          let audioChunks = [];
          let startTime;
          let timerInterval;
          const maxDuration = %d * 1000; // milliseconds
          
          const recordBtn = document.getElementById('%s_record');
          const stopBtn = document.getElementById('%s_stop');
          const player = document.getElementById('%s_player');
          const timer = document.getElementById('%s_timer');
          const hiddenInput = document.getElementById('%s');
          
          recordBtn.addEventListener('click', async () => {
            try {
              const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
              mediaRecorder = new MediaRecorder(stream);
              audioChunks = [];
              
              mediaRecorder.ondataavailable = (event) => {
                audioChunks.push(event.data);
              };
              
              mediaRecorder.onstop = () => {
                const audioBlob = new Blob(audioChunks, { type: 'audio/webm' });
                const audioUrl = URL.createObjectURL(audioBlob);
                player.src = audioUrl;
                player.style.display = 'block';
                
                // Convert to base64 for storage
                const reader = new FileReader();
                reader.onloadend = () => {
                  hiddenInput.value = reader.result;
                };
                reader.readAsDataURL(audioBlob);
                
                stream.getTracks().forEach(track => track.stop());
                clearInterval(timerInterval);
              };
              
              mediaRecorder.start();
              startTime = Date.now();
              
              recordBtn.style.display = 'none';
              stopBtn.style.display = 'inline-block';
              stopBtn.disabled = false;
              timer.style.display = 'block';
              
              // Update timer
              timerInterval = setInterval(() => {
                const elapsed = Date.now() - startTime;
                const minutes = Math.floor(elapsed / 60000);
                const seconds = Math.floor((elapsed %% 60000) / 1000);
                timer.textContent = 
                  String(minutes).padStart(2, '0') + ':' + 
                  String(seconds).padStart(2, '0');
                
                // Auto-stop at max duration
                if (elapsed >= maxDuration) {
                  stopBtn.click();
                }
              }, 100);
              
            } catch (err) {
              alert('Error accessing microphone: ' + err.message);
            }
          });
          
          stopBtn.addEventListener('click', () => {
            if (mediaRecorder && mediaRecorder.state !== 'inactive') {
              mediaRecorder.stop();
              recordBtn.style.display = 'inline-block';
              stopBtn.style.display = 'none';
            }
          });
        })();
      ", max_duration, id, id, id, id, id))
    )
  )
}


#' Video Recording Question
#'
#' Creates a question that allows video recording or upload
#'
#' @param id Question ID
#' @param label Question label
#' @param required Is the question required?
#' @param max_duration Maximum recording duration in seconds (default: 60)
#' @param facing Camera facing mode: "user" or "environment"
#'
#' @return Shiny input
#' @export
nf_video_record <- function(id, label, required = FALSE, 
                              max_duration = 60, facing = "environment") {
  
  htmltools::tags$div(
    class = "form-group nf-video-record",
    htmltools::tags$label(
      `for` = id,
      label,
      if (required) htmltools::tags$span(class = "required-star", "*")
    ),
    htmltools::tags$div(
      class = "video-recorder",
      htmltools::tags$video(
        id = paste0(id, "_preview"),
        style = "width: 100%; max-width: 400px; background: #000; border-radius: 8px;",
        autoplay = NA,
        muted = NA
      ),
      htmltools::tags$div(
        style = "margin-top: 10px;",
        htmltools::tags$button(
          type = "button",
          id = paste0(id, "_record"),
          class = "btn btn-danger",
          htmltools::HTML('<i class="fas fa-video"></i> Start Recording')
        ),
        htmltools::tags$button(
          type = "button",
          id = paste0(id, "_stop"),
          class = "btn btn-secondary",
          disabled = "disabled",
          style = "display: none;",
          htmltools::HTML('<i class="fas fa-stop"></i> Stop')
        )
      ),
      htmltools::tags$input(
        type = "hidden",
        id = id,
        name = id,
        required = required
      )
    ),
    htmltools::tags$p(
      class = "help-text",
      paste0("Max duration: ", format_duration(max_duration))
    )
  )
}


#' File Upload Question
#'
#' Generic file upload question
#'
#' @param id Question ID
#' @param label Question label
#' @param required Is the question required?
#' @param accept Accepted file types (e.g., ".pdf,.doc,.docx")
#' @param max_size Maximum file size in MB (default: 10)
#' @param multiple Allow multiple files
#'
#' @return Shiny input
#' @export
nf_file_upload <- function(id, label, required = FALSE,
                             accept = "*", max_size = 10, multiple = FALSE) {
  
  htmltools::tags$div(
    class = "form-group nf-file-upload",
    htmltools::tags$label(
      `for` = id,
      label,
      if (required) htmltools::tags$span(class = "required-star", "*")
    ),
    htmltools::tags$input(
      type = "file",
      id = id,
      name = id,
      accept = accept,
      required = required,
      multiple = if (multiple) NA else NULL,
      `data-max-size` = max_size * 1024 * 1024
    ),
    htmltools::tags$div(
      id = paste0(id, "_file_list"),
      class = "file-list"
    ),
    htmltools::tags$p(
      class = "help-text",
      paste0("Max file size: ", max_size, " MB")
    )
  )
}


#' Format Duration
#' @param seconds Duration in seconds
#' @return Formatted string
#' @keywords internal
format_duration <- function(seconds) {
  if (seconds < 60) {
    paste(seconds, "seconds")
  } else if (seconds < 3600) {
    paste(round(seconds / 60, 1), "minutes")
  } else {
    paste(round(seconds / 3600, 1), "hours")
  }
}

