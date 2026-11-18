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
# Helper: abort with install guidance when a Suggests package is missing.
# Used by the handful of entry points that genuinely need an optional package
# rather than making every study repo install it.
require_pkg <- function(pkg, why) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    return(invisible(TRUE))
  }

  install_call <- paste0("install.packages(\"", pkg, "\")")
  cli::cli_abort(c(
    "The {.pkg {pkg}} package is required to {why}.",
    i = "Install it with {.code {install_call}}."
  ))
}

# Helper: open a file in the RStudio editor when running inside RStudio.
# Outside RStudio (plain console, Rscript, VS Code, Positron) there is no
# editor to drive, so report the path instead of erroring after the file has
# already been written.
rstudio_navigate_to_file <- function(file) {
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    rstudioapi::navigateToFile(file = file)
    return(invisible(TRUE))
  }

  cli::cli_alert_info("Open {.file {file}} to edit it.")
  invisible(FALSE)
}

# Helper: open a project in a new RStudio session, where that is possible
rstudio_open_project <- function(path) {
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    rstudioapi::openProject(path, newSession = TRUE)
    return(invisible(TRUE))
  }

  cli::cli_alert_info("Open {.file {path}} in your IDE to start work on the study.")
  invisible(FALSE)
}
