# Environment/Dependency Management Helpers for Picard Pipelines
# Functions to ensure reproducible R environments using renv:
# - initializeRenv(): Set up renv for the project
# - snapshotEnvironment(): Capture current package state
# - validateEnvironment(): Check for drift from lockfile
# - restoreEnvironment(): Restore to known package state
# - documentDependencies(): Generate dependency report

#' Initialize Renv for Project
#' @description Sets up renv for the pipeline project on first run.
#'   Creates renv infrastructure and initial lockfile.
#' @return Invisible TRUE
#' @export
#' @details
#' Must be run once per project before using other renv functions.
#' Sets up:
#' - renv.lock in project root
#' - renv/ project library
#' - renv auto-loader in .Rprofile
#'
initializeRenv <- function() {
  cli::cli_rule("Initialize Renv")

  if (!requireNamespace("renv", quietly = TRUE)) {
    cli::cli_abort("renv package required. Install with: install.packages('renv')")
  }

  tryCatch({
    # Initialize renv
    cli::cli_alert_info("Setting up renv project infrastructure...")
    renv::init(bare = FALSE)
    cli::cli_alert_success("✓ Renv initialized")

    # Create initial snapshot
    cli::cli_alert_info("Creating initial package snapshot...")
    renv::snapshot()
    cli::cli_alert_success("✓ Initial snapshot created: renv.lock")

    cli::cli_text("")
    cli::cli_bullets(c(
      "i" = "renv.lock added to project root",
      "i" = "Commit renv.lock and renv/ folder to git",
      "i" = "Use snapshotEnvironment() before major pipeline operations"
    ))

    return(invisible(TRUE))
  }, error = function(e) {
    cli::cli_abort("Failed to initialize renv: {e$message}")
  })
}

#' Snapshot Current Environment State
#' @description Captures all package versions and saves lockfile.
#'   Useful before major pipeline operations for reproducibility tracking.
#' @param versionLabel Character. Optional label for the snapshot (e.g., "v1.0.0").
#'   Used in saved filename: renv_lock_{versionLabel}.json
#' @param savePath Character. Optional path to save versioned lockfile.
#'   If NULL and versionLabel provided, saves to current directory.
#' @return Character. Hash of lockfile contents for audit trail (invisibly)
#' @export
#' @details
#' This function:
#' 1. Updates renv.lock with current package state
#' 2. Optionally saves versioned copy
#' 3. Returns lockfile hash for audit/reproducibility tracking
#'
#' Call before execStudyPipeline() or runPostProcessing().
#'
snapshotEnvironment <- function(versionLabel = NULL, savePath = NULL) {
  if (!requireNamespace("renv", quietly = TRUE)) {
    cli::cli_abort("renv package required")
  }

  cli::cli_alert_info("Snapshotting environment state...")

  tryCatch({
    # Update main lockfile
    renv::snapshot(prompt = FALSE)
    cli::cli_alert_success("✓ Snapshot complete: renv.lock updated")

    # Save versioned copy if requested
    if (!is.null(versionLabel)) {
      lockfile_path <- "renv.lock"

      if (!file.exists(lockfile_path)) {
        cli::cli_abort("renv.lock not found. Run initializeRenv() first.")
      }

      # Read lockfile
      lockfile_content <- readr::read_file(lockfile_path)

      # Compute hash
      lockfile_hash <- rlang::hash(lockfile_content)

      # Determine save path
      if (is.null(savePath)) {
        savePath <- "."
      }

      # Save versioned copy
      versioned_path <- fs::path(
        savePath,
        glue::glue("renv_lock_{versionLabel}.json")
      )

      readr::write_file(lockfile_content, versioned_path)
      cli::cli_alert_success("✓ Versioned copy saved: {fs::path_rel(versioned_path)}")

      return(invisible(lockfile_hash))
    } else {
      # Return hash of main lockfile anyway
      lockfile_content <- readr::read_file("renv.lock")
      lockfile_hash <- rlang::hash(lockfile_content)
      return(invisible(lockfile_hash))
    }
  }, error = function(e) {
    cli::cli_abort("Failed to snapshot environment: {e$message}")
  })
}

#' Validate Environment Against Lockfile
#' @description Checks that installed packages match renv.lock.
#'   Prevents running pipelines with environment drift.
#'   Call before execStudyPipeline() or runPostProcessing().
#' @return Invisible TRUE if valid, aborts if drift detected
#' @keywords internal
validateEnvironment <- function() {
  if (!requireNamespace("renv", quietly = TRUE)) {
    cli::cli_abort("renv package required")
  }

  tryCatch({
    cli::cli_alert_info("Validating environment state...")

    # Capture output to detect unknown source packages
    statusOutput <- utils::capture.output({
      status <- renv::status()
    })
    
    unknownSourceText <- paste(statusOutput, collapse = "\n")
    hasUnknownSources <- grepl("unknown source", unknownSourceText, ignore.case = TRUE)

    if (!is.null(status)) {
      # There are packages that don't match lockfile
      
      if (hasUnknownSources) {
        # Extract package names from status
        packageNames <- if (is.data.frame(status) && "Package" %in% names(status)) {
          status$Package
        } else {
          c()
        }
        
        if (length(packageNames) > 0) {
          cli::cli_alert_warning("Found {length(packageNames)} package(s) from unknown source:")
          for (pkg in packageNames) {
            cli::cli_bullets(c("!" = "{pkg}"))
          }
          cli::cli_bullets(c(
            "i" = "Unknown source packages are permitted in this environment",
            "i" = "Pipeline will proceed with execution"
          ))
          # Continue despite unknown sources - this is not a blocker
        } else {
          # Actual drift detected (not just unknown sources)
          cli::cli_abort(c(
            "Environment drift detected!",
            "i" = "Packages differ from renv.lock",
            "i" = "Restore with: {.code renv::restore()}",
            "i" = "Or update with: {.code snapshotEnvironment()}"
          ))
        }
      } else {
        # Actual drift detected (not unknown sources)
        cli::cli_abort(c(
          "Environment drift detected!",
          "i" = "Packages differ from renv.lock",
          "i" = "Restore with: {.code renv::restore()}",
          "i" = "Or update with: {.code snapshotEnvironment()}"
        ))
      }
    }

    cli::cli_alert_success("✓ Environment validated against renv.lock")
    return(invisible(TRUE))
  }, error = function(e) {
    if (grepl("Environment drift", e$message)) {
      stop(e$message, call. = FALSE)
    } else {
      cli::cli_abort("Failed to validate environment: {e$message}")
    }
  })
}

#' Restore Environment from Lockfile
#' @description Restores all packages to versions specified in renv.lock.
#'   Useful for reproducibility when re-running analyses.
#' @param versionLabel Character. Optional label to restore from specific versioned
#'   lockfile (e.g., "v1.0.0" restores from renv_lock_v1.0.0.json)
#' @return Invisible TRUE
#' @export
#'
restoreEnvironment <- function(versionLabel = NULL) {
  if (!requireNamespace("renv", quietly = TRUE)) {
    cli::cli_abort("renv package required")
  }

  cli::cli_rule("Restore Environment")

  if (!is.null(versionLabel)) {
    versioned_lock <- glue::glue("renv_lock_{versionLabel}.json")
    if (!file.exists(versioned_lock)) {
      cli::cli_abort("Versioned lockfile not found: {versioned_lock}")
    }

    cli::cli_alert_info("Restoring from {versioned_lock}...")
    tryCatch({
      renv::restore(lockfile = versioned_lock, prompt = FALSE)
    }, error = function(e) {
      cli::cli_abort("Failed to restore from {versioned_lock}: {e$message}")
    })
  } else {
    cli::cli_alert_info("Restoring from renv.lock...")
    tryCatch({
      renv::restore(prompt = FALSE)
    }, error = function(e) {
      cli::cli_abort("Failed to restore environment: {e$message}")
    })
  }

  cli::cli_alert_success("✓ Environment restored")
  return(invisible(TRUE))
}

#' Document Dependencies
#' @description Generates human-readable dependency report.
#'   Useful for manuscripts, methods sections, or audit trails.
#' @param outputPath Character. Optional path to save report as CSV.
#'   If NULL, returns tibble silently.
#' @return Tibble with columns: package, version, type(direct/indirect)
#' @export
#'
#' @details
#' Returns data frame with:
#' - package: Package name
#' - version: Installed version
#' - source: CRAN / GitHub / local
#'
documentDependencies <- function(outputPath = NULL) {
  if (!requireNamespace("renv", quietly = TRUE)) {
    cli::cli_abort("renv package required")
  }

  tryCatch({
    cli::cli_alert_info("Documenting project dependencies...")

    # Get lock data
    lockfile <- renv::status()

    # Get installed packages with version info
    dependencies <- as.data.frame(renv::dependencies())

    if (is.null(dependencies) || nrow(dependencies) == 0) {
      cli::cli_alert_warning("No dependencies found or unable to parse")
      return(invisible(tibble::tibble()))
    }

    # Extract key fields
    dep_summary <- dependencies |>
      dplyr::select(Package, Version) |>
      dplyr::distinct() |>
      dplyr::arrange(Package) |>
      dplyr::rename(package = Package, version = Version) |>
      tibble::as_tibble()

    # Save if requested
    if (!is.null(outputPath)) {
      readr::write_csv(dep_summary, outputPath)
      cli::cli_alert_success("✓ Dependencies documented: {fs::path_rel(outputPath)}")
      cli::cli_alert_info("{nrow(dep_summary)} package{?s} recorded")
    } else {
      cli::cli_alert_success("✓ Dependencies documented: {nrow(dep_summary)} package{?s}")
    }

    return(invisible(dep_summary))
  }, error = function(e) {
    cli::cli_warn("Failed to document dependencies: {e$message}")
    return(invisible(tibble::tibble()))
  })
}

#' Get Environment Lockfile Hash
#' @description Retrieves hash of current renv.lock for audit trail.
#' @return Character. Hash of lockfile contents (invisibly)
#' @keywords internal
#'
getEnvironmentHash <- function() {
  if (!file.exists("renv.lock")) {
    return(invisible(NA_character_))
  }

  tryCatch({
    lockfile_content <- readr::read_file("renv.lock")
    hash <- rlang::hash(lockfile_content)
    return(invisible(hash))
  }, error = function(e) {
    return(invisible(NA_character_))
  })
}
