#' Internationalization (i18n) Support for NomadForms
#'
#' Multi-language support for surveys
#'
#' @name i18n
NULL

# Global translations storage
.translations <- new.env(parent = emptyenv())
.current_lang <- "en"

#' Set Current Language
#'
#' @param lang Language code (e.g., "en", "es", "fr", "sw")
#' @export
nf_set_language <- function(lang) {
  .current_lang <<- lang
  message(paste("Language set to:", lang))
}

#' Get Current Language
#' @export
nf_get_language <- function() {
  .current_lang
}

#' Load Translations from JSON
#'
#' @param file Path to translations JSON file
#' @param lang Language code
#' @export
nf_load_translations <- function(file, lang) {
  translations <- jsonlite::fromJSON(file, simplifyVector = FALSE)
  .translations[[lang]] <- translations
  message(paste("Loaded translations for:", lang))
}

#' Load Translations from List
#'
#' @param translations Named list of translations
#' @param lang Language code
#' @export
nf_add_translations <- function(translations, lang) {
  .translations[[lang]] <- translations
}

#' Translate Text
#'
#' @param key Translation key
#' @param lang Language code (uses current language if NULL)
#' @param fallback Fallback text if translation not found
#' @param ... Named arguments for string interpolation
#' @export
nf_t <- function(key, lang = NULL, fallback = NULL, ...) {
  if (is.null(lang)) {
    lang <- .current_lang
  }
  
  # Get translations for language
  lang_translations <- .translations[[lang]]
  
  if (is.null(lang_translations)) {
    # Try fallback to English
    lang_translations <- .translations[["en"]]
  }
  
  # Navigate nested keys (e.g., "common.buttons.submit")
  keys <- strsplit(key, "\\.")[[1]]
  result <- lang_translations
  
  for (k in keys) {
    if (is.null(result[[k]])) {
      result <- NULL
      break
    }
    result <- result[[k]]
  }
  
  # Use fallback if translation not found
  if (is.null(result)) {
    result <- fallback %||% key
  }
  
  # Interpolate variables
  args <- list(...)
  if (length(args) > 0) {
    for (var_name in names(args)) {
      result <- gsub(paste0("\\{", var_name, "\\}"), args[[var_name]], result)
    }
  }
  
  return(result)
}

#' Translate with Pluralization
#'
#' @param key Translation key
#' @param count Number for pluralization
#' @param lang Language code
#' @export
nf_tn <- function(key, count, lang = NULL) {
  if (is.null(lang)) {
    lang <- .current_lang
  }
  
  # Get plural form
  plural_key <- if (count == 1) paste0(key, ".one") else paste0(key, ".other")
  
  nf_t(plural_key, lang = lang, fallback = nf_t(key, lang = lang), count = count)
}

#' Built-in English Translations
#' @export
nf_default_translations_en <- function() {
  list(
    common = list(
      buttons = list(
        submit = "Submit",
        cancel = "Cancel",
        save = "Save",
        save_draft = "Save Draft",
        next = "Next",
        previous = "Previous",
        finish = "Finish",
        clear = "Clear",
        undo = "Undo",
        upload = "Upload"
      ),
      labels = list(
        required = "Required",
        optional = "Optional",
        loading = "Loading...",
        saving = "Saving...",
        saved = "Saved",
        error = "Error",
        success = "Success"
      ),
      messages = list(
        required_field = "This field is required",
        invalid_email = "Please enter a valid email address",
        invalid_phone = "Please enter a valid phone number",
        invalid_url = "Please enter a valid URL",
        save_success = "Saved successfully",
        save_error = "Error saving data",
        network_error = "Network error. Please try again.",
        offline_mode = "You are offline. Responses will be saved locally.",
        online_mode = "You are online. Responses will be synced.",
        sync_success = "Data synced successfully",
        sync_error = "Error syncing data"
      )
    ),
    survey = list(
      progress = "Progress: {percent}%",
      page_of = "Page {current} of {total}",
      question_of = "Question {current} of {total}",
      questions_answered = "{answered} of {total} questions answered",
      time_remaining = "Estimated time remaining: {minutes} minutes"
    ),
    validation = list(
      min_length = "Must be at least {min} characters",
      max_length = "Must be at most {max} characters",
      min_value = "Must be at least {min}",
      max_value = "Must be at most {max}",
      pattern = "Invalid format",
      unique = "Must be unique",
      match = "{field1} and {field2} must match"
    )
  )
}

#' Built-in Spanish Translations
#' @export
nf_default_translations_es <- function() {
  list(
    common = list(
      buttons = list(
        submit = "Enviar",
        cancel = "Cancelar",
        save = "Guardar",
        save_draft = "Guardar borrador",
        next = "Siguiente",
        previous = "Anterior",
        finish = "Finalizar",
        clear = "Limpiar",
        undo = "Deshacer",
        upload = "Subir"
      ),
      labels = list(
        required = "Requerido",
        optional = "Opcional",
        loading = "Cargando...",
        saving = "Guardando...",
        saved = "Guardado",
        error = "Error",
        success = "Éxito"
      ),
      messages = list(
        required_field = "Este campo es obligatorio",
        invalid_email = "Por favor, introduzca una dirección de correo electrónico válida",
        invalid_phone = "Por favor, introduzca un número de teléfono válido",
        invalid_url = "Por favor, introduzca una URL válida",
        save_success = "Guardado correctamente",
        save_error = "Error al guardar datos",
        network_error = "Error de red. Por favor, inténtelo de nuevo.",
        offline_mode = "Está sin conexión. Las respuestas se guardarán localmente.",
        online_mode = "Está en línea. Las respuestas se sincronizarán.",
        sync_success = "Datos sincronizados correctamente",
        sync_error = "Error al sincronizar datos"
      )
    ),
    survey = list(
      progress = "Progreso: {percent}%",
      page_of = "Página {current} de {total}",
      question_of = "Pregunta {current} de {total}",
      questions_answered = "{answered} de {total} preguntas respondidas",
      time_remaining = "Tiempo restante estimado: {minutes} minutos"
    )
  )
}

#' Built-in French Translations
#' @export
nf_default_translations_fr <- function() {
  list(
    common = list(
      buttons = list(
        submit = "Soumettre",
        cancel = "Annuler",
        save = "Enregistrer",
        save_draft = "Enregistrer le brouillon",
        next = "Suivant",
        previous = "Précédent",
        finish = "Terminer",
        clear = "Effacer",
        undo = "Annuler",
        upload = "Télécharger"
      ),
      labels = list(
        required = "Requis",
        optional = "Facultatif",
        loading = "Chargement...",
        saving = "Enregistrement...",
        saved = "Enregistré",
        error = "Erreur",
        success = "Succès"
      ),
      messages = list(
        required_field = "Ce champ est obligatoire",
        invalid_email = "Veuillez entrer une adresse e-mail valide",
        invalid_phone = "Veuillez entrer un numéro de téléphone valide",
        invalid_url = "Veuillez entrer une URL valide",
        save_success = "Enregistré avec succès",
        save_error = "Erreur lors de l'enregistrement des données",
        network_error = "Erreur réseau. Veuillez réessayer.",
        offline_mode = "Vous êtes hors ligne. Les réponses seront enregistrées localement.",
        online_mode = "Vous êtes en ligne. Les réponses seront synchronisées.",
        sync_success = "Données synchronisées avec succès",
        sync_error = "Erreur lors de la synchronisation des données"
      )
    ),
    survey = list(
      progress = "Progrès: {percent}%",
      page_of = "Page {current} sur {total}",
      question_of = "Question {current} sur {total}",
      questions_answered = "{answered} sur {total} questions répondues",
      time_remaining = "Temps restant estimé: {minutes} minutes"
    )
  )
}

#' Built-in Swahili Translations
#' @export
nf_default_translations_sw <- function() {
  list(
    common = list(
      buttons = list(
        submit = "Wasilisha",
        cancel = "Ghairi",
        save = "Hifadhi",
        save_draft = "Hifadhi rasimu",
        next = "Ifuatayo",
        previous = "Iliyotangulia",
        finish = "Maliza",
        clear = "Futa",
        undo = "Tengua",
        upload = "Pakia"
      ),
      labels = list(
        required = "Inahitajika",
        optional = "Si lazima",
        loading = "Inapakia...",
        saving = "Inahifadhi...",
        saved = "Imehifadhiwa",
        error = "Hitilafu",
        success = "Mafanikio"
      ),
      messages = list(
        required_field = "Sehemu hii inahitajika",
        invalid_email = "Tafadhali weka anwani sahihi ya barua pepe",
        invalid_phone = "Tafadhali weka nambari sahihi ya simu",
        invalid_url = "Tafadhali weka URL sahihi",
        save_success = "Imehifadhiwa kwa mafanikio",
        save_error = "Hitilafu katika kuhifadhi data",
        network_error = "Hitilafu ya mtandao. Tafadhali jaribu tena.",
        offline_mode = "Uko nje ya mtandao. Majibu yatahifadhiwa kimahali.",
        online_mode = "Uko kwenye mtandao. Majibu yatasawazishwa.",
        sync_success = "Data imesawazishwa kwa mafanikio",
        sync_error = "Hitilafu katika kusawazisha data"
      )
    ),
    survey = list(
      progress = "Maendeleo: {percent}%",
      page_of = "Ukurasa {current} wa {total}",
      question_of = "Swali {current} la {total}",
      questions_answered = "{answered} ya maswali {total} yamejibiwa",
      time_remaining = "Muda uliobaki: dakika {minutes}"
    )
  )
}

#' Initialize Default Translations
#' @export
nf_init_i18n <- function() {
  nf_add_translations(nf_default_translations_en(), "en")
  nf_add_translations(nf_default_translations_es(), "es")
  nf_add_translations(nf_default_translations_fr(), "fr")
  nf_add_translations(nf_default_translations_sw(), "sw")
  
  message("Default translations loaded: en, es, fr, sw")
}

#' Language Selector Widget
#'
#' Creates a language selector dropdown
#'
#' @param languages Named vector of language codes and names
#' @param default_lang Default language
#' @export
nf_language_selector <- function(languages = c("en" = "English", "es" = "Español", 
                                                "fr" = "Français", "sw" = "Kiswahili"),
                                  default_lang = "en") {
  htmltools::tags$div(
    class = "language-selector",
    style = "text-align: right; margin-bottom: 1rem;",
    htmltools::tags$label(
      `for` = "lang_select",
      htmltools::HTML('<i class="fas fa-globe"></i> '),
      style = "margin-right: 0.5rem;"
    ),
    htmltools::tags$select(
      id = "lang_select",
      class = "form-control",
      style = "display: inline-block; width: auto;",
      lapply(names(languages), function(code) {
        htmltools::tags$option(
          value = code,
          selected = if (code == default_lang) NA else NULL,
          languages[[code]]
        )
      })
    ),
    htmltools::tags$script(
      htmltools::HTML("
        document.getElementById('lang_select').addEventListener('change', function(e) {
          const lang = e.target.value;
          // Send to Shiny if available
          if (typeof Shiny !== 'undefined') {
            Shiny.setInputValue('selected_language', lang);
          }
          // Store in localStorage
          localStorage.setItem('nomadforms_lang', lang);
          // Reload page to apply new language
          window.location.reload();
        });
        
        // Load saved language preference
        const savedLang = localStorage.getItem('nomadforms_lang');
        if (savedLang) {
          document.getElementById('lang_select').value = savedLang;
        }
      ")
    )
  )
}

`%||%` <- function(a, b) if (is.null(a)) b else a

