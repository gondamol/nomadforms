#' Package Load Hook
#'
#' Registers the built-in translations (en, es, fr, sw) when the package is
#' loaded. Without this, `nf_t()` silently returns the lookup key itself
#' instead of translated text until the caller remembers to invoke
#' `nf_init_i18n()` by hand -- a failure mode that looks like working code.
#'
#' @param libname Library path (supplied by R)
#' @param pkgname Package name (supplied by R)
#' @noRd
.onLoad <- function(libname, pkgname) {
  nf_add_translations(nf_default_translations_en(), "en")
  nf_add_translations(nf_default_translations_es(), "es")
  nf_add_translations(nf_default_translations_fr(), "fr")
  nf_add_translations(nf_default_translations_sw(), "sw")
  invisible(NULL)
}
