.onLoad <- function(libname, pkgname) {
  op <- options()
  op_picard <- list(
    picard.suppressIdRouteWarning = FALSE
  )
  to_set <- !(names(op_picard) %in% names(op))
  if (any(to_set)) {
    options(op_picard[to_set])
  }
  invisible(NULL)
}