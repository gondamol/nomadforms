#' Null-coalescing operator
#'
#' Returns `a` unless it is NULL, in which case it returns `b`. Package-internal
#' helper shared across modules.
#'
#' @param a Value to test
#' @param b Fallback used when `a` is NULL
#' @return `a` if not NULL, otherwise `b`
#' @name null-coalesce
#' @keywords internal
`%||%` <- function(a, b) if (is.null(a)) b else a
