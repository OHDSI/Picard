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

# Record the lockfile as it currently stands on disk, without writing to it.
# Used for the run audit trail, where capturing what the environment *is* must
# not change what it is. Optionally archives a versioned copy for provenance.
captureLockfile <- function(versionLabel = NULL, savePath = NULL, path = "renv.lock") {
  if (!fs::file_exists(path)) {
    cli::cli_abort("{.file {path}} not found. Run {.code initializeRenv()} first.")
  }

  lockfile_content <- readr::read_file(path)

  if (!is.null(versionLabel)) {
    versioned_path <- fs::path(
      savePath %||% ".",
      glue::glue("renv_lock_{versionLabel}.json")
    )
    readr::write_file(lockfile_content, versioned_path)
    cli::cli_alert_success("Versioned copy saved: {fs::path_rel(versioned_path)}")
  }

  invisible(rlang::hash(lockfile_content))
}

lockfileHashOnDisk <- function(path = "renv.lock") {
  captureLockfile(path = path)
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

    captureLockfile(versionLabel = versionLabel, savePath = savePath)
  }, error = function(e) {
    cli::cli_abort("Failed to snapshot environment: {e$message}")
  })
}

# Read the `synchronized` flag from a renv::status() result.
# Returns NA when the installed renv is too old to report it, so callers can
# fall back to comparing the library and lockfile records themselves.
renv_status_synchronized <- function(status) {
  if (!is.list(status) || is.null(status[["synchronized"]])) {
    return(NA)
  }
  isTRUE(status[["synchronized"]])
}

# Compare the package records renv::status() reports for the project library
# against those recorded in renv.lock. Returns a character vector describing
# each genuine difference ("pkg (lockfile 1.0.0, installed 1.1.0)"), or an
# empty vector when every recorded package matches.
#
# Only Package/Version are compared: a differing Source or Repository is
# metadata drift (the "unknown source" case) and must not block a pipeline.
renv_status_drift <- function(status) {
  packageVersions <- function(lockfileLike) {
    packages <- if (is.list(lockfileLike)) lockfileLike[["Packages"]] else NULL
    if (!is.list(packages) || length(packages) == 0) {
      return(character(0))
    }
    versions <- vapply(
      packages,
      function(record) as.character(record[["Version"]] %||% NA_character_),
      character(1)
    )
    names(versions) <- vapply(
      seq_along(packages),
      function(i) {
        name <- packages[[i]][["Package"]] %||% names(packages)[i]
        if (length(name) != 1 || is.na(name)) {
          name <- paste0("<package ", i, ">")
        }
        as.character(name)
      },
      character(1)
    )
    versions
  }

  installed <- packageVersions(status[["library"]])
  recorded <- packageVersions(status[["lockfile"]])

  if (length(installed) == 0 && length(recorded) == 0) {
    return(character(0))
  }

  lookup <- function(versions, pkg) {
    if (pkg %in% names(versions)) unname(versions[[pkg]]) else NA_character_
  }

  describe <- function(version) {
    if (is.na(version)) "absent" else version
  }

  allPackages <- sort(union(names(recorded), names(installed)))

  drift <- vapply(allPackages, function(pkg) {
    lockVersion <- lookup(recorded, pkg)
    libVersion <- lookup(installed, pkg)
    if (identical(lockVersion, libVersion)) {
      return(NA_character_)
    }
    paste0(
      pkg, " (lockfile ", describe(lockVersion),
      ", installed ", describe(libVersion), ")"
    )
  }, character(1))

  unname(drift[!is.na(drift)])
}

#' Validate Environment Against Lockfile
#' @description Checks that installed packages match renv.lock.
#'   Prevents running pipelines with environment drift.
#'   Call before execStudyPipeline() or runPostProcessing().
#' @return Invisible TRUE if valid, aborts if drift detected
#' @keywords internal
#' @details
#' `renv::status()` always returns a list describing the project state — it
#' never returns `NULL` — so the result must be inspected rather than merely
#' tested for `NULL`. A project is treated as in sync when `renv::status()`
#' reports `synchronized = TRUE`, or (on older renv versions that omit the
#' flag) when no package version differs between the project library and
#' `renv.lock`. Source-only mismatches, such as packages installed from an
#' unknown source, are reported as a warning and do not block the pipeline.
validateEnvironment <- function() {
  if (!requireNamespace("renv", quietly = TRUE)) {
    cli::cli_abort("renv package required")
  }

  cli::cli_alert_info("Validating environment state...")

  status <- NULL
  statusOutput <- tryCatch(
    utils::capture.output(status <- renv::status()),
    error = function(e) {
      cli::cli_abort("Failed to validate environment: {conditionMessage(e)}")
    }
  )

  if (isTRUE(renv_status_synchronized(status))) {
    cli::cli_alert_success("Environment validated against renv.lock")
    return(invisible(TRUE))
  }

  drift <- tryCatch(
    renv_status_drift(status),
    error = function(e) character(0)
  )

  if (length(drift) == 0) {
    # renv flags the project as out of sync, but no package version differs.
    # This is metadata-only drift (typically packages installed from a source
    # renv cannot identify) and is not a reproducibility blocker.
    hasUnknownSources <- any(grepl(
      "unknown source",
      statusOutput,
      ignore.case = TRUE
    ))

    if (hasUnknownSources) {
      cli::cli_alert_warning("Package(s) from an unknown source found in the project library")
    } else {
      cli::cli_alert_warning("renv reports the project as out of sync, but no package version differs from renv.lock")
    }
    cli::cli_bullets(c(
      "i" = "No package version differs from renv.lock — continuing",
      "i" = "Run {.code snapshotEnvironment()} to record the current state"
    ))
    return(invisible(TRUE))
  }

  cli::cli_abort(c(
    "Environment drift detected!",
    "i" = "{length(drift)} package{?s} out of sync with renv.lock: {drift}",
    "i" = "Restore with: {.code renv::restore()}",
    "i" = "Or update with: {.code snapshotEnvironment()}"
  ))
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
