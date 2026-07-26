#' Internationalization (i18n) Support for NomadForms
#'
#' Multi-language support for surveys
#'
#' @name i18n
NULL

# Global translations storage. Mutable session state lives in environments
# because namespace bindings are locked once the package is installed.
.translations <- new.env(parent = emptyenv())
.nf_state <- new.env(parent = emptyenv())
.nf_state$current_lang <- "en"

#' Set Current Language
#'
#' @param lang Language code (e.g., "en", "es", "fr", "sw")
#' @return The language code, invisibly.
#' @export
#' @examples
#' old_lang <- nf_get_language()
#' nf_set_language("es")
#' nf_get_language()
#' nf_set_language(old_lang)
nf_set_language <- function(lang) {
  .nf_state$current_lang <- lang
  message(paste("Language set to:", lang))
  invisible(lang)
}

#' Get Current Language
#' @return The current language code as a character string.
#' @export
#' @examples
#' nf_get_language()
nf_get_language <- function() {
  .nf_state$current_lang
}

#' Load Translations from JSON
#'
#' @param file Path to translations JSON file
#' @param lang Language code
#' @return Called for its side effect of parsing \code{file} and registering
#'   its contents as the translations for \code{lang}. Returns \code{NULL}
#'   invisibly (the value returned by \code{message()}).
#' @export
#' @examples
#' path <- file.path(tempdir(), "fr_extra.json")
#' jsonlite::write_json(list(greeting = "Bonjour"), path, auto_unbox = TRUE)
#' nf_load_translations(path, "fr")
#' nf_t("greeting", lang = "fr")
#' unlink(path)
nf_load_translations <- function(file, lang) {
  translations <- jsonlite::fromJSON(file, simplifyVector = FALSE)
  .translations[[lang]] <- translations
  message(paste("Loaded translations for:", lang))
}

#' Load Translations from List
#'
#' @param translations Named list of translations
#' @param lang Language code
#' @return The \code{translations} list, invisibly (the value just stored
#'   in the package's internal translation table).
#' @export
#' @examples
#' nf_add_translations(list(greeting = "Jambo"), "sw")
#' nf_t("greeting", lang = "sw")
nf_add_translations <- function(translations, lang) {
  .translations[[lang]] <- translations
}

#' Translate Text
#'
#' @param key Translation key
#' @param lang Language code (uses current language if NULL)
#' @param fallback Fallback text if translation not found
#' @param ... Named arguments for string interpolation
#' @return A character string: the translated text for \code{key} in
#'   \code{lang} (or the current language, if \code{lang} is \code{NULL}),
#'   falling back to \code{fallback} or to \code{key} itself when no
#'   translation is found. \code{"{name}"} placeholders in the result are
#'   replaced by any named arguments passed via \code{...}.
#' @export
#' @examples
#' nf_t("common.buttons.submit")
#' nf_t("common.buttons.submit", lang = "es")
#' nf_t("survey.progress", percent = 42)
nf_t <- function(key, lang = NULL, fallback = NULL, ...) {
  if (is.null(lang)) {
    lang <- .nf_state$current_lang
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
#' @return A character string: the translation looked up under
#'   \code{"<key>.one"} when \code{count} equals 1, or \code{"<key>.other"}
#'   otherwise, with any \code{"{name}"} placeholders interpolated (including
#'   \code{"{count}"}).
#' @export
#' @examples
#' nf_add_translations(list(items = list(one = "1 item", other = "{count} items")), "xx")
#' nf_tn("items", count = 1, lang = "xx")
#' nf_tn("items", count = 5, lang = "xx")
nf_tn <- function(key, count, lang = NULL) {
  if (is.null(lang)) {
    lang <- .nf_state$current_lang
  }
  
  # Get plural form
  plural_key <- if (count == 1) paste0(key, ".one") else paste0(key, ".other")
  
  nf_t(plural_key, lang = lang, fallback = nf_t(key, lang = lang), count = count)
}

#' Built-in English Translations
#' @return A nested named list of English translation strings, organized
#'   under \code{common}, \code{survey}, and \code{validation}, suitable for
#'   passing to \code{\link{nf_add_translations}}.
#' @export
#' @examples
#' en <- nf_default_translations_en()
#' en$common$buttons$submit
nf_default_translations_en <- function() {
  list(
    common = list(
      buttons = list(
        submit = "Submit",
        cancel = "Cancel",
        save = "Save",
        save_draft = "Save Draft",
        `next` = "Next",
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
#' @return A nested named list of Spanish translation strings, organized
#'   under \code{common} and \code{survey}, suitable for passing to
#'   \code{\link{nf_add_translations}}.
#' @export
#' @examples
#' es <- nf_default_translations_es()
#' es$common$buttons$submit
nf_default_translations_es <- function() {
  list(
    common = list(
      buttons = list(
        submit = "Enviar",
        cancel = "Cancelar",
        save = "Guardar",
        save_draft = "Guardar borrador",
        `next` = "Siguiente",
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
        success = "\u00c9xito"
      ),
      messages = list(
        required_field = "Este campo es obligatorio",
        invalid_email = "Por favor, introduzca una direcci\u00f3n de correo electr\u00f3nico v\u00e1lida",
        invalid_phone = "Por favor, introduzca un n\u00famero de tel\u00e9fono v\u00e1lido",
        invalid_url = "Por favor, introduzca una URL v\u00e1lida",
        save_success = "Guardado correctamente",
        save_error = "Error al guardar datos",
        network_error = "Error de red. Por favor, int\u00e9ntelo de nuevo.",
        offline_mode = "Est\u00e1 sin conexi\u00f3n. Las respuestas se guardar\u00e1n localmente.",
        online_mode = "Est\u00e1 en l\u00ednea. Las respuestas se sincronizar\u00e1n.",
        sync_success = "Datos sincronizados correctamente",
        sync_error = "Error al sincronizar datos"
      )
    ),
    survey = list(
      progress = "Progreso: {percent}%",
      page_of = "P\u00e1gina {current} de {total}",
      question_of = "Pregunta {current} de {total}",
      questions_answered = "{answered} de {total} preguntas respondidas",
      time_remaining = "Tiempo restante estimado: {minutes} minutos"
    )
  )
}

#' Built-in French Translations
#' @return A nested named list of French translation strings, organized
#'   under \code{common} and \code{survey}, suitable for passing to
#'   \code{\link{nf_add_translations}}.
#' @export
#' @examples
#' fr <- nf_default_translations_fr()
#' fr$common$buttons$submit
nf_default_translations_fr <- function() {
  list(
    common = list(
      buttons = list(
        submit = "Soumettre",
        cancel = "Annuler",
        save = "Enregistrer",
        save_draft = "Enregistrer le brouillon",
        `next` = "Suivant",
        previous = "Pr\u00e9c\u00e9dent",
        finish = "Terminer",
        clear = "Effacer",
        undo = "Annuler",
        upload = "T\u00e9l\u00e9charger"
      ),
      labels = list(
        required = "Requis",
        optional = "Facultatif",
        loading = "Chargement...",
        saving = "Enregistrement...",
        saved = "Enregistr\u00e9",
        error = "Erreur",
        success = "Succ\u00e8s"
      ),
      messages = list(
        required_field = "Ce champ est obligatoire",
        invalid_email = "Veuillez entrer une adresse e-mail valide",
        invalid_phone = "Veuillez entrer un num\u00e9ro de t\u00e9l\u00e9phone valide",
        invalid_url = "Veuillez entrer une URL valide",
        save_success = "Enregistr\u00e9 avec succ\u00e8s",
        save_error = "Erreur lors de l'enregistrement des donn\u00e9es",
        network_error = "Erreur r\u00e9seau. Veuillez r\u00e9essayer.",
        offline_mode = "Vous \u00eates hors ligne. Les r\u00e9ponses seront enregistr\u00e9es localement.",
        online_mode = "Vous \u00eates en ligne. Les r\u00e9ponses seront synchronis\u00e9es.",
        sync_success = "Donn\u00e9es synchronis\u00e9es avec succ\u00e8s",
        sync_error = "Erreur lors de la synchronisation des donn\u00e9es"
      )
    ),
    survey = list(
      progress = "Progr\u00e8s: {percent}%",
      page_of = "Page {current} sur {total}",
      question_of = "Question {current} sur {total}",
      questions_answered = "{answered} sur {total} questions r\u00e9pondues",
      time_remaining = "Temps restant estim\u00e9: {minutes} minutes"
    )
  )
}

#' Built-in Swahili Translations
#' @return A nested named list of Swahili translation strings, organized
#'   under \code{common} and \code{survey}, suitable for passing to
#'   \code{\link{nf_add_translations}}.
#' @export
#' @examples
#' sw <- nf_default_translations_sw()
#' sw$common$buttons$submit
nf_default_translations_sw <- function() {
  list(
    common = list(
      buttons = list(
        submit = "Wasilisha",
        cancel = "Ghairi",
        save = "Hifadhi",
        save_draft = "Hifadhi rasimu",
        `next` = "Ifuatayo",
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
#' @return Called for its side effect of loading the built-in English,
#'   Spanish, French, and Swahili translations into the package's
#'   translation store (overwriting any existing translations already
#'   registered for those four language codes). Returns \code{NULL}
#'   invisibly (the value returned by \code{message()}).
#' @export
#' @examples
#' nf_init_i18n()
#' nf_t("common.buttons.submit", lang = "fr")
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
#' @return An \code{htmltools} tag object containing a language \code{<select>}
#'   dropdown with its supporting label and script, ready to be included in a
#'   Shiny UI or R Markdown/Quarto HTML document.
#' @export
#' @examples
#' nf_language_selector()
#' nf_language_selector(languages = c("en" = "English", "sw" = "Kiswahili"),
#'                       default_lang = "sw")
nf_language_selector <- function(languages = c("en" = "English", "es" = "Espa\u00f1ol",
                                                "fr" = "Fran\u00e7ais", "sw" = "Kiswahili"),
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


