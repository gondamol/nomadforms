#' nomadforms: Offline-Capable Survey Toolkit for Field Research
#'
#' Tools for building survey data collection workflows that keep working when
#' the network does not. The package targets field research in low- and
#' middle-income countries, where enumerators routinely work for days without
#' connectivity on budget devices.
#'
#' @section Building a survey:
#' [nf_question()] renders a single question as a Shiny input. Existing
#' instruments do not have to be retyped: [nf_import_redcap()] reads a REDCap
#' data dictionary and [nf_import_csv()] reads a generic codebook, both
#' returning question definitions.
#'
#' @section Validation:
#' [nf_validate()] checks one response against a list of rules covering
#' required fields, numeric ranges, string lengths, regular expressions, and
#' membership. [nf_validate_batch()] applies rules across a whole response set,
#' and [nf_validate_cross_field()] expresses constraints that span questions.
#'
#' @section Skip logic:
#' A rule written once drives both ends of the stack. [nf_skip_logic()] and the
#' [nf_show_if_equals()] family evaluate conditions in R, while
#' [nf_condition_to_js()] and [nf_skip_logic_js()] transpile the same condition
#' to JavaScript so the offline browser client applies identical logic without
#' a round trip to the server.
#'
#' @section Field data capture:
#' [nf_gps_location()], [nf_image_upload()], [nf_audio_record()],
#' [nf_video_record()], and [nf_signature()] produce browser widgets for
#' capturing evidence alongside responses. [nf_distance()] and
#' [nf_within_radius()] support geofenced sampling.
#'
#' @section Translation:
#' English, Spanish, French, and Swahili translations are registered when the
#' package loads, so [nf_t()] and [nf_tn()] work immediately. Add other
#' languages with [nf_add_translations()] or [nf_load_translations()].
#'
#' @section Export:
#' [nf_export_csv()], [nf_export_json()], [nf_export_rds()],
#' [nf_export_excel()], [nf_export_stata()], and [nf_export_spss()] write a
#' single format; [nf_export_batch()] writes several at once; and
#' [nf_export_labeled()] substitutes value labels from a codebook first, which
#' is what analysts working in Stata or SPSS usually want.
#'
#' @section Optional dependencies:
#' The package installs without a database driver or a Shiny stack. Question
#' rendering needs 'shiny', PostgreSQL storage needs 'RPostgres', Excel export
#' needs 'openxlsx', and 'Stata'/'SPSS' export needs 'haven'. Each function
#' checks for its dependency and fails with an actionable message rather than
#' at load time.
#'
#' @keywords internal
"_PACKAGE"
