#' Signature Capture for NomadForms
#'
#' Digital signature capture using canvas
#'
#' @name signature
NULL

#' Signature Pad Question
#'
#' Creates a canvas for capturing digital signatures
#'
#' @param id Question ID
#' @param label Question label
#' @param required Is the question required?
#' @param width Canvas width in pixels (default: 500)
#' @param height Canvas height in pixels (default: 200)
#' @param pen_color Pen color (default: "#000000")
#' @param pen_width Pen width in pixels (default: 2)
#' @param background_color Background color (default: "#ffffff")
#'
#' @return Shiny input
#' @export
nf_signature <- function(id, label, required = FALSE,
                          width = 500, height = 200,
                          pen_color = "#000000", pen_width = 2,
                          background_color = "#ffffff") {
  
  htmltools::tags$div(
    class = "form-group nf-signature",
    htmltools::tags$label(
      `for` = id,
      label,
      if (required) htmltools::tags$span(class = "required-star", "*")
    ),
    htmltools::tags$div(
      class = "signature-pad-container",
      style = "border: 2px solid #ddd; border-radius: 8px; background: white; display: inline-block;",
      htmltools::tags$canvas(
        id = paste0(id, "_canvas"),
        width = width,
        height = height,
        style = "display: block; touch-action: none; cursor: crosshair;"
      )
    ),
    htmltools::tags$div(
      style = "margin-top: 10px;",
      htmltools::tags$button(
        type = "button",
        id = paste0(id, "_clear"),
        class = "btn btn-secondary",
        htmltools::HTML('<i class="fas fa-eraser"></i> Clear')
      ),
      htmltools::tags$button(
        type = "button",
        id = paste0(id, "_undo"),
        class = "btn btn-secondary",
        htmltools::HTML('<i class="fas fa-undo"></i> Undo')
      )
    ),
    htmltools::tags$input(
      type = "hidden",
      id = id,
      name = id,
      required = required
    ),
    htmltools::tags$p(
      class = "help-text",
      "Draw your signature above"
    ),
    htmltools::tags$script(
      htmltools::HTML(sprintf("
        (function() {
          const canvas = document.getElementById('%s_canvas');
          const ctx = canvas.getContext('2d');
          const clearBtn = document.getElementById('%s_clear');
          const undoBtn = document.getElementById('%s_undo');
          const hiddenInput = document.getElementById('%s');
          
          let isDrawing = false;
          let lastX = 0;
          let lastY = 0;
          let strokes = [];
          let currentStroke = [];
          
          // Set canvas background
          ctx.fillStyle = '%s';
          ctx.fillRect(0, 0, canvas.width, canvas.height);
          
          // Set pen style
          ctx.strokeStyle = '%s';
          ctx.lineWidth = %d;
          ctx.lineCap = 'round';
          ctx.lineJoin = 'round';
          
          // Get coordinates relative to canvas
          function getCoords(e) {
            const rect = canvas.getBoundingClientRect();
            const scaleX = canvas.width / rect.width;
            const scaleY = canvas.height / rect.height;
            
            if (e.touches) {
              return {
                x: (e.touches[0].clientX - rect.left) * scaleX,
                y: (e.touches[0].clientY - rect.top) * scaleY
              };
            } else {
              return {
                x: (e.clientX - rect.left) * scaleX,
                y: (e.clientY - rect.top) * scaleY
              };
            }
          }
          
          // Start drawing
          function startDrawing(e) {
            e.preventDefault();
            isDrawing = true;
            const coords = getCoords(e);
            lastX = coords.x;
            lastY = coords.y;
            currentStroke = [{x: lastX, y: lastY}];
          }
          
          // Draw
          function draw(e) {
            if (!isDrawing) return;
            e.preventDefault();
            
            const coords = getCoords(e);
            
            ctx.beginPath();
            ctx.moveTo(lastX, lastY);
            ctx.lineTo(coords.x, coords.y);
            ctx.stroke();
            
            currentStroke.push({x: coords.x, y: coords.y});
            lastX = coords.x;
            lastY = coords.y;
          }
          
          // Stop drawing
          function stopDrawing(e) {
            if (isDrawing) {
              isDrawing = false;
              strokes.push([...currentStroke]);
              currentStroke = [];
              saveSignature();
            }
          }
          
          // Save signature as base64
          function saveSignature() {
            hiddenInput.value = canvas.toDataURL('image/png');
          }
          
          // Clear canvas
          function clearCanvas() {
            ctx.fillStyle = '%s';
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            strokes = [];
            currentStroke = [];
            hiddenInput.value = '';
          }
          
          // Undo last stroke
          function undoStroke() {
            if (strokes.length === 0) return;
            
            strokes.pop();
            
            // Redraw all strokes
            ctx.fillStyle = '%s';
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            ctx.strokeStyle = '%s';
            
            strokes.forEach(stroke => {
              ctx.beginPath();
              ctx.moveTo(stroke[0].x, stroke[0].y);
              stroke.forEach(point => {
                ctx.lineTo(point.x, point.y);
              });
              ctx.stroke();
            });
            
            saveSignature();
          }
          
          // Mouse events
          canvas.addEventListener('mousedown', startDrawing);
          canvas.addEventListener('mousemove', draw);
          canvas.addEventListener('mouseup', stopDrawing);
          canvas.addEventListener('mouseout', stopDrawing);
          
          // Touch events
          canvas.addEventListener('touchstart', startDrawing);
          canvas.addEventListener('touchmove', draw);
          canvas.addEventListener('touchend', stopDrawing);
          canvas.addEventListener('touchcancel', stopDrawing);
          
          // Button events
          clearBtn.addEventListener('click', clearCanvas);
          undoBtn.addEventListener('click', undoStroke);
        })();
      ", id, id, id, id, background_color, pen_color, pen_width,
         background_color, background_color, pen_color))
    )
  )
}


#' Initials Capture
#'
#' Smaller signature pad for capturing initials
#'
#' @param id Question ID
#' @param label Question label
#' @param required Is the question required?
#'
#' @return Shiny input
#' @export
nf_initials <- function(id, label, required = FALSE) {
  nf_signature(
    id = id,
    label = label,
    required = required,
    width = 150,
    height = 100,
    pen_width = 3
  )
}

