# manifest_helpers.R
# Standalone helper functions for CohortManifest and ConceptSetManifest.
# Wraps the R6 class methods with convenient top-level functions and provides
# visualization / review utilities.

# ============================================================
# COHORT MANIFEST HELPERS
# ============================================================

#' Initialize a New Cohort Manifest
#'
#' Creates a blank `cohortManifest.sqlite` database with the new schema.
#' Directory creation (`json/`, `sql/`, `derived/`) is handled by the study repo
#' initialization (see `listDefaultFolders()` in `R/Ulysses.R`).
#'
#' @param path Character. Path to the cohorts folder where the SQLite file will be created.
#'   Defaults to `"inputs/cohorts"`.
#'
#' @return A `CohortManifest` R6 object (empty, ready for `$add*()` calls).
#'
#' @export
initCohortManifest <- function(path = "inputs/cohorts") {
  dbPath <- fs::path(path, "cohortManifest.sqlite")

  if (file.exists(dbPath)) {
    cli::cli_alert_warning("Manifest already exists at {fs::path_rel(dbPath)}.")
    cli::cli_alert_info("Use loadCohortManifest() to load the existing manifest.")
    cli::cli_alert_info("Use resetCohortManifest() to delete and start fresh.")
    return(invisible(NULL))
  }

  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }

  cm <- CohortManifest$new(dbPath = dbPath)
  cli::cli_alert_success("Initialized empty cohort manifest at {fs::path_rel(dbPath)}")
  cli::cli_alert_info("Add cohorts with $addAtlasCohort(), $addCaprCohort(), $addCirceCohort(), $addSqlCohort(), or $importAtlasCohorts()")

  return(cm)
}


#' Load Cohort Manifest from SQLite Database
#'
#' Loads a CohortManifest R6 object from an existing `cohortManifest.sqlite` database.
#' This is a pure read from SQLite — it does not scan directories or auto-add new files.
#' If new files exist on disk that aren't in the manifest, a warning is printed
#' suggesting the appropriate `$add*()` method.
#'
#' @param cohortsFolderPath Character. Path to the cohorts folder containing the manifest
#'   database. Defaults to `here::here("inputs/cohorts")`.
#' @param executionSettings An ExecutionSettings object containing database configuration
#'   for cohort generation. Optional; can be added later using `$setExecutionSettings()`.
#' @param verbose Logical. If TRUE, prints informative messages. Defaults to TRUE.
#'
#' @return A CohortManifest R6 object.
#'
#' @details
#' If no SQLite database exists at the expected path, the function stops with an
#' error directing the user to `initCohortManifest()`.
#'
#' After loading, the function checks for new files in `json/`, `sql/`, and `derived/`
#' directories that are not tracked in the manifest. These are reported as warnings
#' but NOT auto-added (because `category` is required and cannot be guessed).
#'
#' @export
loadCohortManifest <- function(cohortsFolderPath = here::here("inputs/cohorts"),
                               executionSettings = NULL,
                               autoSync = TRUE,
                               verbose = TRUE) {
  dbPath <- fs::path(cohortsFolderPath, "cohortManifest.sqlite")

  if (!file.exists(dbPath)) {
    cli::cli_abort(c(
      "Cohort manifest not found at {.path {fs::path_rel(dbPath)}}.",
      "i" = "Use {.code initCohortManifest()} to create a new manifest.",
      "i" = "Use {.code migrateCohortManifest()} if upgrading from picard <= 0.0.3."
    ))
  }

  cm <- CohortManifest$new(dbPath = dbPath)

  if (!is.null(executionSettings)) {
    cm$setExecutionSettings(executionSettings)
  }

  # Auto-sync manifest to ensure 1:1 correspondence between SQLite and file system
  if (autoSync) {
    if (verbose) {
      cli::cli_alert_info("Auto-syncing manifest to reconcile files...")
    }
    sync_results <- cm$syncManifest(strict_mode = TRUE)
    if (verbose) {
      n_orphan_removed <- sum(sync_results$action == "auto_removed_orphan")
      n_missing <- sum(sync_results$action == "missing_flagged")
      if (n_orphan_removed > 0 || n_missing > 0) {
        cli::cli_alert_info("Sync cleaned {n_orphan_removed} orphaned file(s) and marked {n_missing} missing")
      }
    }
  }

  if (verbose) {
    n_cohorts <- length(cm$getManifest())
    cli::cli_alert_success("Loaded cohort manifest: {n_cohorts} active cohort(s)")
  }

  return(cm)
}



#' Reset Cohort Manifest
#'
#' Cleans up cohort manifest data at one of three scopes. All destructive
#' operations require the user to type \code{"yes"} at a confirmation prompt
#' (disable with \code{confirm = FALSE} for scripted use).
#'
#' @section Scope options:
#' \describe{
#'   \item{\code{"derived"}}{Removes all derived cohort rows from the SQLite
#'     database (union, subset, complement, composite) and deletes the
#'     \code{derived/} folder. Base cohorts (circe, custom) and their files
#'     are untouched. Use when rebuilding the derived pipeline with new
#'     parameters. Requires a live \code{manifest} object.}
#'   \item{\code{"manifest"}}{Deletes the SQLite database and the \code{derived/}
#'     folder. Source files in \code{json/} and \code{sql/} are archived to a
#'     timestamped directory (unless \code{archive = FALSE}) and can be restored
#'     after \code{initCohortManifest()} using \code{$addCirceCohort()} or
#'     \code{$addSqlCohort()}.}
#'   \item{\code{"full"}}{Deletes the SQLite database, \code{derived/},
#'     \code{json/}, \code{sql/}, and \code{cohortsLoad.csv}. Also drops OMOP
#'     cohort tables from the database (requires \code{executionSettings}).}
#' }
#'
#' @param manifest A \code{CohortManifest} R6 object. Required for
#'   \code{scope = "derived"}; optional for other scopes (extracts path and
#'   settings automatically when provided).
#' @param cohortsFolderPath Character. Path to the cohorts folder. Inferred
#'   from \code{manifest} when provided; otherwise defaults to
#'   \code{here::here("inputs/cohorts")}.
#' @param scope Character. One of \code{"derived"}, \code{"manifest"},
#'   or \code{"full"}. Defaults to \code{"derived"}.
#' @param executionSettings An \code{ExecutionSettings} object. Required for
#'   \code{scope = "full"} to drop OMOP cohort tables. If \code{manifest} is
#'   provided and already has settings attached, those are used automatically;
#'   this argument overrides them.
#' @param archive Logical. For \code{scope = "manifest"}, if \code{TRUE} (default),
#'   archives source files in \code{json/} and \code{sql/} to a timestamped
#'   directory instead of deleting them. Set to \code{FALSE} to delete without archiving.
#' @param confirm Logical. If \code{TRUE} (default), the user must type
#'   \code{"yes"} to proceed. Set to \code{FALSE} for non-interactive use.
#'
#' @return Invisibly returns NULL.
#'
#' @export
resetCohortManifest <- function(manifest = NULL,
                                cohortsFolderPath = here::here("inputs/cohorts"),
                                scope = c("derived", "manifest", "full"),
                                executionSettings = NULL,
                                archive = TRUE,
                                confirm = TRUE) {
  scope <- match.arg(scope)
  checkmate::assert_logical(confirm, len = 1)
  checkmate::assert_logical(archive, len = 1)

  # Resolve cohortsFolderPath and executionSettings from manifest object
  if (!is.null(manifest)) {
    checkmate::assert_r6(manifest, classes = "CohortManifest")
    cohortsFolderPath <- dirname(manifest$getDbPath())
    if (is.null(executionSettings)) {
      executionSettings <- manifest$getExecutionSettings()
    }
  }

  checkmate::assert_string(cohortsFolderPath)

  if (scope == "derived" && is.null(manifest)) {
    cli::cli_abort(
      c("`scope = 'derived'` requires a live {.cls CohortManifest} object.",
        "i" = "Load one with {.code loadCohortManifest()} and pass it as {.arg manifest}.")
    )
  }

  if (scope == "full" && is.null(executionSettings)) {
    cli::cli_abort(
      c("`scope = 'full'` requires {.arg executionSettings} to drop OMOP cohort tables.",
        "i" = "Pass an {.cls ExecutionSettings} object or attach one to the manifest first.")
    )
  }

  dbPath      <- fs::path(cohortsFolderPath, "cohortManifest.sqlite")
  derived_dir <- fs::path(cohortsFolderPath, "derived")
  json_dir    <- fs::path(cohortsFolderPath, "json")
  sql_dir     <- fs::path(cohortsFolderPath, "sql")
  load_csv    <- fs::path(cohortsFolderPath, "cohortsLoad.csv")

  # Count what exists
  n_derived <- if (dir.exists(derived_dir)) {
    length(list.files(derived_dir, recursive = TRUE))
  } else {
    0L
  }
  n_json <- if (dir.exists(json_dir)) length(list.files(json_dir, recursive = TRUE)) else 0L
  n_sql  <- if (dir.exists(sql_dir))  length(list.files(sql_dir,  recursive = TRUE)) else 0L

  # Count derived rows in SQLite (for scope = derived)
  n_derived_rows <- 0L
  if (scope == "derived" && file.exists(dbPath)) {
    conn_sq <- DBI::dbConnect(RSQLite::SQLite(), dbPath)
    n_derived_rows <- DBI::dbGetQuery(
      conn_sq,
      "SELECT COUNT(*) AS n FROM cohort_manifest
       WHERE status = 'active' AND cohort_type NOT IN ('circe', 'custom')"
    )$n
    DBI::dbDisconnect(conn_sq)
  }

  # ── Print summary of what will be deleted ────────────────────────────────
  cli::cli_rule("Cohort Manifest Reset")

  if (scope == "derived") {
    cli::cli_alert_danger("The following will be {.strong permanently deleted}:")
    cli::cli_bullets(c(
      "x" = "{n_derived_rows} derived cohort record(s) from the manifest database",
      "x" = "{n_derived} file(s) in {.file {fs::path_rel(derived_dir)}}"
    ))
    cli::cli_alert_info("Base cohorts (circe, custom) and their source files will be preserved.")

  } else if (scope == "manifest") {
    cli::cli_alert_danger("The following will be {.strong deleted}:")
    cli::cli_bullets(c(
      "x" = "Manifest database: {.file {fs::path_rel(dbPath)}}",
      "x" = "{n_derived} derived file(s) in {.file {fs::path_rel(derived_dir)}}"
    ))
    if (archive) {
      cli::cli_alert_info(
        "Source files in {.file json/} ({n_json} file(s)) and {.file sql/} ({n_sql} file(s)) will be {.strong archived} to {.file _archive/manifest_reset_TIMESTAMP/}."
      )
    } else {
      cli::cli_alert_warning(
        "Source files in {.file json/} ({n_json} file(s)) and {.file sql/} ({n_sql} file(s)) will be {.strong permanently deleted}."
      )
    }
    cli::cli_alert_info(
      "After reset, call {.code initCohortManifest()} then re-register cohorts with {.code $addCirceCohort()} or {.code $addSqlCohort()}."
    )

  } else if (scope == "full") {
    settings <- executionSettings
    schema   <- settings$workDatabaseSchema
    tbl      <- settings$cohortTable
    cli::cli_alert_danger("The following will be {.strong permanently deleted}:")
    cli::cli_bullets(c(
      "x" = "Manifest database: {.file {fs::path_rel(dbPath)}}",
      "x" = "{n_derived} derived file(s) in {.file {fs::path_rel(derived_dir)}}",
      "x" = "{n_json} file(s) in {.file {fs::path_rel(json_dir)}}",
      "x" = "{n_sql} file(s) in {.file {fs::path_rel(sql_dir)}}",
      "x" = "{.file {fs::path_rel(load_csv)}} (if present)"
    ))
    cli::cli_alert_danger(
      "OMOP cohort tables will be dropped from {.strong {schema}.{tbl}} (and related stats tables)."
    )
  }

  if (confirm) {
    answer <- readline("Type 'yes' to confirm reset, anything else to cancel: ")
    if (!identical(trimws(tolower(answer)), "yes")) {
      cli::cli_alert_info("Reset cancelled.")
      return(NULL)
    }
  }

  # ── Execute deletions ─────────────────────────────────────────────────────

  if (scope == "derived") {
    # Hard-delete derived rows from SQLite
    conn_sq <- DBI::dbConnect(RSQLite::SQLite(), dbPath)
    DBI::dbExecute(
      conn_sq,
      "DELETE FROM cohort_manifest WHERE cohort_type NOT IN ('circe', 'custom')"
    )
    DBI::dbDisconnect(conn_sq)
    cli::cli_alert_success("Removed {n_derived_rows} derived cohort record(s) from manifest database.")

    # Remove derived folder
    if (dir.exists(derived_dir)) {
      unlink(derived_dir, recursive = TRUE)
      cli::cli_alert_success("Deleted {.file {fs::path_rel(derived_dir)}} ({n_derived} file(s)).")
    }

    # Evict derived entries from in-memory manifest
    if (!is.null(manifest)) {
      manifest$reloadFromDb()
    }

    cli::cli_alert_info(
      "Derived pipeline cleared. Rebuild with {.code manifest$buildUnionCohort()}, {.code $buildSubsetCohortTemporal()}, etc."
    )

  } else if (scope == "manifest") {
    if (file.exists(dbPath)) {
      file.remove(dbPath)
      cli::cli_alert_success("Deleted manifest database: {.file {fs::path_rel(dbPath)}}")
    }
    
    # Archive or delete source and derived cohort files
    if (archive && (dir.exists(json_dir) || dir.exists(sql_dir))) {
      archive_dir <- fs::path(cohortsFolderPath, "_archive", 
                               paste0("manifest_reset_", format(Sys.time(), "%Y%m%d_%H%M%S")))
      dir.create(archive_dir, recursive = TRUE)
      
      for (src_dir in list(json_dir, sql_dir)) {
        if (dir.exists(src_dir)) {
          dest_dir <- fs::path(archive_dir, basename(src_dir))
          fs::dir_copy(src_dir, dest_dir)
          unlink(src_dir, recursive = TRUE)
          n_files <- length(list.files(dest_dir, recursive = TRUE))
          cli::cli_alert_success("Archived {.file {fs::path_rel(src_dir)}} ({n_files} file(s)) to {.file {fs::path_rel(dest_dir)}}")
        }
      }
      
      cli::cli_alert_info("Archive location: {.file {fs::path_rel(archive_dir)}}")
      cli::cli_alert_info(
        "To restore: Move files from archive back to {.file json/} or {.file sql/}, then call {.code initCohortManifest()} and use {.code $addCirceCohort()} or {.code $addSqlCohort()} to re-register."
      )
    } else {
      # Delete without archive
      for (target in list(derived_dir, json_dir, sql_dir)) {
        if (dir.exists(target)) {
          n_files <- length(list.files(target, recursive = TRUE))
          unlink(target, recursive = TRUE)
          cli::cli_alert_success("Deleted {.file {fs::path_rel(target)}} ({n_files} file(s)).")
        }
      }
      
      cli::cli_alert_info(
        "Call {.code initCohortManifest()} then re-register cohorts with {.code $addCirceCohort()} or {.code $addSqlCohort()}."
      )
    }

  } else if (scope == "full") {
    # Drop OMOP cohort tables first (while we still have settings)
    cli::cli_rule("Dropping OMOP Cohort Tables")
    tryCatch({
      # Reuse the manifest's dropCohortTables() if available
      if (!is.null(manifest)) {
        manifest$dropCohortTables()
      } else {
        # Construct a temporary manifest to call the method
        if (file.exists(dbPath)) {
          tmp_manifest <- CohortManifest$new(dbPath = dbPath)
          tmp_manifest$setExecutionSettings(executionSettings)
          tmp_manifest$dropCohortTables()
        } else {
          cli::cli_alert_warning("Manifest database not found — skipping OMOP table drop.")
        }
      }
    }, error = function(e) {
      cli::cli_alert_warning("Could not drop OMOP cohort tables: {e$message}")
    })

    # Delete manifest database
    if (file.exists(dbPath)) {
      file.remove(dbPath)
      cli::cli_alert_success("Deleted manifest database: {.file {fs::path_rel(dbPath)}}")
    }

    # Delete all cohort file folders
    for (target in list(derived_dir, json_dir, sql_dir)) {
      if (dir.exists(target)) {
        n_files <- length(list.files(target, recursive = TRUE))
        unlink(target, recursive = TRUE)
        cli::cli_alert_success("Deleted {.file {fs::path_rel(target)}} ({n_files} file(s)).")
      }
    }

    # Delete cohortsLoad.csv if present
    if (file.exists(load_csv)) {
      file.remove(load_csv)
      cli::cli_alert_success("Deleted {.file {fs::path_rel(load_csv)}}.")
    }

    cli::cli_alert_info(
      "Full reset complete. Call {.code initCohortManifest()} to start fresh."
    )
  }

  invisible(NULL)
}


#' Create Blank Cohorts Load File
#'
#' Creates a blank cohortsLoad.csv template file in the specified folder
#' with proper column structure.
#'
#' @param cohortsFolderPath Character. Path where the blank file will be created.
#'   Defaults to `here::here("inputs/cohorts")`. Creates the folder if it doesn't exist.
#'
#' @return Invisibly returns the file path.
#'
#' @export
createBlankCohortsLoadFile <- function(cohortsFolderPath = here::here("inputs/cohorts")) {
  checkmate::assert_string(cohortsFolderPath)

  fs::dir_create(cohortsFolderPath)

  file_path <- fs::path(cohortsFolderPath, "cohortsLoad.csv")

  # Check if file already exists
  if (fs::file_exists(file_path)) {
    cli::cli_alert_warning("File already exists: {.file {fs::path_rel(file_path)}}")
    answer <- readline("Overwrite with blank template? (yes/no): ")
    if (!identical(trimws(tolower(answer)), "yes")) {
      cli::cli_alert_info("Operation cancelled. Existing file was not modified.")
      return(NULL)
    }
    cli::cli_alert_info("Overwriting existing file with blank template...")
  }

  template <- data.frame(
    atlasId = integer(1),
    label = character(1),
    category = character(1),
    subCategory = character(1),
    stringsAsFactors = FALSE
  )

  readr::write_csv(template, file = file_path)

  cli::cli_rule("Blank Cohorts Load File Created")
  cli::cli_text("File created at: {.file {fs::path_rel(file_path)}}")
  cli::cli_text("")
  cli::cli_h3("Column Guide:")
  cli::cli_ul(c(
    "{.field atlasId} - ATLAS cohort ID (numeric)",
    "{.field label} - Display name (e.g., 'Type 2 Diabetes patients')",
    "{.field category} - Broad category (e.g., 'Disease Populations')",
    "{.field subCategory} - Optional sub-grouping"
  ))
  cli::cli_text("")
  cli::cli_h3("Next Steps:")
  cli::cli_ol(c(
    "Open {.file inputs/cohorts/cohortsLoad.csv} in Excel or your text editor",
    "Fill in the table",
    "Save the file",
    "Use {.code importAtlasCohorts()} to import JSON definitions from ATLAS",
    "Use {.code loadCohortManifest()} to load into your study"
  ))

  invisible(file_path)
}




#' Plot Cohort Dependency Graph
#'
#' @description
#' Generates a mermaid `graph TD` diagram showing how cohorts in a
#' [CohortManifest] depend on each other. Dependency data is read directly from
#' the SQLite manifest database — no sidecar JSON files required.
#'
#' Prints the mermaid string to the console (renders automatically in RStudio,
#' Quarto, and GitHub markdown) and returns it invisibly.
#'
#' @param manifest A [CohortManifest] R6 object.
#'
#' @return Character. The mermaid diagram string (invisibly).
#'
#' @details
#' **Node shapes by cohort type:**
#' - Rectangle `[label]` — circe (base) cohort
#' - Circle `(label)` — subset cohort
#' - Diamond `{{label}}` — union cohort
#' - Hexagon `{{{{label}}}}` — complement / composite cohort
#'
#' Arrows show dependency direction: parent → dependent cohort.
#'
#' For a tabular view of derived cohorts and their rule parameters, see
#' [CohortManifest]`$reviewDependentCohorts()`.
#'
#' @export
plotCohortGraph <- function(manifest) {
  checkmate::assert_r6(manifest, classes = "CohortManifest")

  conn <- DBI::dbConnect(RSQLite::SQLite(), manifest$getDbPath())
  on.exit(DBI::dbDisconnect(conn))

  rows <- DBI::dbGetQuery(
    conn,
    "SELECT id, label, cohort_type, depends_on
     FROM cohort_manifest
     WHERE status IN ('active', 'stale')
     ORDER BY id"
  )

  if (nrow(rows) == 0) {
    cli::cli_alert_warning("No cohorts found in manifest.")
    return(invisible(NULL))
  }

  node_defs <- character()
  edge_defs <- character()

  for (i in seq_len(nrow(rows))) {
    cid   <- rows$id[i]
    clbl  <- gsub('"', "'", rows$label[i])
    ctype <- rows$cohort_type[i]
    nid   <- paste0("c", cid)

    node_shape <- switch(
      ctype,
      circe     = paste0(nid, '["', clbl, '"]'),
      subset    = paste0(nid, '("',  clbl, '")'),
      union     = paste0(nid, '{{"', clbl, '"}}'),
      paste0(nid, '{{{{"', clbl, '"}}}}')  # complement / composite / custom
    )
    node_defs <- c(node_defs, node_shape)

    dep_json <- rows$depends_on[i]
    if (!is.na(dep_json) && nchar(dep_json) > 0) {
      parent_ids <- tryCatch(
        as.integer(jsonlite::fromJSON(dep_json)),
        error = function(e) integer(0)
      )
      for (pid in parent_ids) {
        edge_defs <- c(edge_defs, paste0("c", pid, " --> ", nid))
      }
    }
  }

  mermaid <- paste(
    c("graph TD", node_defs, edge_defs),
    collapse = "\n"
  )

  legend <- paste(
    "\n# Legend:",
    "# [ ] Rectangle  = circe (base) cohort",
    "# ( ) Circle     = subset cohort",
    "# {{ }} Diamond  = union cohort",
    "# {{{{ }}}} Hexagon = complement / composite cohort",
    sep = "\n"
  )

  cat(mermaid, legend, sep = "\n")
  invisible(mermaid)
}


#' Validate a Custom SQL Cohort for Picard Compatibility
#'
#' @noRd
.validateCustomSql <- function(sql, label = "custom cohort") {
  if (!grepl("@target_cohort_id", sql, fixed = TRUE)) {
    cli::cli_alert_warning("[{label}] SQL does not contain `@target_cohort_id`")
  }
  if (!grepl("@target_database_schema", sql, fixed = TRUE)) {
    cli::cli_alert_warning("[{label}] SQL does not contain `@target_database_schema`")
  }
  if (!grepl("@target_cohort_table", sql, fixed = TRUE)) {
    cli::cli_alert_warning("[{label}] SQL does not contain `@target_cohort_table`")
  }

  has_delete <- grepl("DELETE", sql, ignore.case = TRUE) &&
    grepl("@target_cohort_id", sql, fixed = TRUE)
  if (!has_delete) {
    cli::cli_alert_warning("[{label}] SQL does not include a DELETE step using `@target_cohort_id` - re-running will duplicate rows")
  }

  required_cols <- c("cohort_definition_id", "subject_id", "cohort_start_date", "cohort_end_date")
  if (grepl("INSERT", sql, ignore.case = TRUE)) {
    missing_cols <- required_cols[!sapply(required_cols, function(col) grepl(col, sql, ignore.case = TRUE))]
    if (length(missing_cols) > 0) {
      cli::cli_alert_warning(
        "[{label}] INSERT statement missing required cohort column(s): {paste(missing_cols, collapse = ', ')}"
      )
    }
  }

  if (grepl("[A-Z][A-Z0-9_]{4,}\\.[a-z]", sql, perl = TRUE)) {
    cli::cli_alert_warning("[{label}] Possible hardcoded schema reference detected - consider using `@cdm_database_schema`")
  }

  invisible(NULL)
}




#' Update the Label, Category, and/or Tags of an Existing Cohort Manifest
#'
#' @description
#' Updates `label`, `category`, `tags`, or any combination on any cohort present in the manifest.
#' Changes are applied to both the in-memory object and the SQLite database.
#'
#' @param manifest A `CohortManifest` object.
#' @param cohortId Integer. The ID of the cohort to update.
#' @param label Character or `NULL`. New label. If `NULL`, the existing label is kept.
#' @param category Character or `NULL`. New category (e.g., 'target', 'outcome', 'exposure'). 
#'   If `NULL`, the existing category is kept.
#' @param tags Named list or `NULL`. New tags. If `NULL`, the existing tags are kept.
#'
#' @return Invisibly returns `NULL`.
#'
#' @export
updateCohortManifest <- function(manifest,
                                 cohortId,
                                 label = NULL,
                                 category = NULL,
                                 tags = NULL) {
  checkmate::assert_class(x = manifest, classes = "CohortManifest")
  checkmate::assert_int(x = cohortId, lower = 1)

  if (is.null(label) && is.null(category) && is.null(tags)) {
    cli::cli_abort("At least one of `label`, `category`, or `tags` must be provided.")
  }
  if (!is.null(label)) checkmate::assert_string(x = label, min.chars = 1)
  if (!is.null(category)) checkmate::assert_string(x = category, min.chars = 1)
  if (!is.null(tags))  checkmate::assert_list(x = tags, names = "named")

  cohort <- manifest$getCohortById(as.integer(cohortId))
  if (is.null(cohort)) {
    cli::cli_abort("No cohort with ID {cohortId} found in the manifest.")
  }

  if (!is.null(label)) cohort$label <- label
  if (!is.null(category)) cohort$category <- category
  if (!is.null(tags))  cohort$tags  <- tags

  set_parts <- character(0)
  params    <- list()

  if (!is.null(label)) {
    set_parts <- c(set_parts, "label = ?")
    params    <- c(params, list(label))
  }

  if (!is.null(category)) {
    set_parts <- c(set_parts, "category = ?")
    params    <- c(params, list(category))
  }

  if (!is.null(tags)) {
    tags_json <- jsonlite::toJSON(tags, auto_unbox = TRUE)
    set_parts <- c(set_parts, "tags = ?")
    params    <- c(params, list(tags_json))
  }

  params <- c(params, list(as.integer(cohortId)))

  sql <- paste(
    "UPDATE cohort_manifest SET",
    paste(set_parts, collapse = ", "),
    "WHERE id = ?"
  )

  conn <- DBI::dbConnect(RSQLite::SQLite(), manifest$getDbPath())
  on.exit(DBI::dbDisconnect(conn))

  DBI::dbExecute(conn, sql, params)

  changed <- character(0)
  if (!is.null(label)) changed <- c(changed, paste0("label \u2192 ", label))
  if (!is.null(category)) changed <- c(changed, paste0("category \u2192 ", category))
  if (!is.null(tags))  changed <- c(changed, paste0("tags \u2192 ", cohort$formatTagsAsString()))

  cli::cli_alert_success("Updated cohort {cohortId}: {paste(changed, collapse = ', ')}")

  invisible(NULL)
}


#' Update a Concept Set in the Manifest
#'
#' Updates metadata (label, category, and/or tags) for a concept set in the ConceptSetManifest.
#'
#' @param manifest A ConceptSetManifest object.
#' @param conceptSetId Integer. The ID of the concept set to update.
#' @param label Character. New label for the concept set. If NULL (default), label is not updated.
#' @param category Character. New category for the concept set. If NULL (default), category is not updated.
#'   Valid values: "drug_exposure", "condition_occurrence", "measurement", "procedure", "observation", "device_exposure", "visit_occurrence", "init".
#' @param tags List. New tags (named list) for the concept set. If NULL (default), tags are not updated.
#'
#' @return Invisibly returns NULL. Prints a success message if the update succeeds.
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   manifest <- loadConceptSetManifest()
#'   updateConceptSetManifest(manifest, 1, label = "Updated Label")
#'   updateConceptSetManifest(manifest, 2, category = "measurement")
#'   updateConceptSetManifest(manifest, 3, tags = list(source = "ATLAS", version = "2"))
#' }
updateConceptSetManifest <- function(manifest,
                                     conceptSetId,
                                     label = NULL,
                                     category = NULL,
                                     tags = NULL) {
  checkmate::assert_class(x = manifest, classes = "ConceptSetManifest")
  checkmate::assert_int(x = conceptSetId, lower = 1)

  if (is.null(label) && is.null(category) && is.null(tags)) {
    cli::cli_abort("At least one of `label`, `category`, or `tags` must be provided.")
  }
  if (!is.null(label)) checkmate::assert_string(x = label, min.chars = 1)
  if (!is.null(category)) {
    checkmate::assert_string(x = category, min.chars = 1)
    valid_categories <- c("drug_exposure", "condition_occurrence", "measurement", "procedure",
                          "observation", "device_exposure", "visit_occurrence", "init")
    checkmate::assert_choice(x = category, choices = valid_categories)
  }
  if (!is.null(tags)) checkmate::assert_list(x = tags, names = "named")

  conceptSet <- manifest$getConceptSetById(as.integer(conceptSetId))
  if (is.null(conceptSet)) {
    cli::cli_abort("No concept set with ID {conceptSetId} found in the manifest.")
  }

  if (!is.null(label)) conceptSet$label <- label
  if (!is.null(category)) conceptSet$category <- category
  if (!is.null(tags)) conceptSet$tags <- tags

  set_parts <- character(0)
  params    <- list()

  if (!is.null(label)) {
    set_parts <- c(set_parts, "label = ?")
    params    <- c(params, list(label))
  }

  if (!is.null(category)) {
    set_parts <- c(set_parts, "category = ?")
    params    <- c(params, list(category))
  }

  if (!is.null(tags)) {
    tags_json <- jsonlite::toJSON(tags, auto_unbox = TRUE)
    set_parts <- c(set_parts, "tags = ?")
    params    <- c(params, list(tags_json))
  }

  params <- c(params, list(as.integer(conceptSetId)))

  sql <- paste(
    "UPDATE concept_set_manifest SET",
    paste(set_parts, collapse = ", "),
    "WHERE id = ?"
  )

  conn <- DBI::dbConnect(RSQLite::SQLite(), manifest$getDbPath())
  on.exit(DBI::dbDisconnect(conn))

  DBI::dbExecute(conn, sql, params)

  changed <- character(0)
  if (!is.null(label)) changed <- c(changed, paste0("label \u2192 ", label))
  if (!is.null(category)) changed <- c(changed, paste0("category \u2192 ", category))
  if (!is.null(tags)) changed <- c(changed, paste0("tags \u2192 ", conceptSet$formatTagsAsString()))

  cli::cli_alert_success("Updated concept set {conceptSetId}: {paste(changed, collapse = ', ')}")

  invisible(NULL)
}


# ============================================================
# CONCEPT SET MANIFEST HELPERS
# ============================================================

#' Initialize a New Concept Set Manifest
#'
#' Creates a blank `conceptSetManifest.sqlite` database with the new schema.
#'
#' @param path Character. Path to the conceptSets folder. Defaults to `"inputs/conceptSets"`.
#'
#' @return A `ConceptSetManifest` R6 object (empty, ready for `$add*()` calls).
#'
#' @export
initConceptSetManifest <- function(path = "inputs/conceptSets") {
  dbPath <- fs::path(path, "conceptSetManifest.sqlite")

  if (file.exists(dbPath)) {
    cli::cli_alert_warning("Manifest already exists at {fs::path_rel(dbPath)}.")
    cli::cli_alert_info("Use loadConceptSetManifest() to load the existing manifest.")
    cli::cli_alert_info("Use resetConceptSetManifest() to delete and start fresh.")
    return(invisible(NULL))
  }

  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }

  csm <- ConceptSetManifest$new(dbPath = dbPath)
  cli::cli_alert_success("Initialized empty concept set manifest at {fs::path_rel(dbPath)}")
  cli::cli_alert_info("Add concept sets with $addConceptSetFile(), $addAtlasConceptSet(), or $importAtlasConceptSets()")

  return(csm)
}


#' Load Concept Set Manifest
#'
#' Loads a ConceptSetManifest R6 object from an existing SQLite database.
#' Scans the `json/` directory for new files not yet registered in the manifest
#' and auto-registers them.
#'
#' @param conceptSetsFolderPath Character. Path to the conceptSets folder.
#'   Defaults to `here::here("inputs/conceptSets")`.
#' @param executionSettings ExecutionSettings object. Optional.
#' @param verbose Logical. If TRUE (default), prints informative messages.
#'
#' @return ConceptSetManifest object.
#'
#' @export
loadConceptSetManifest <- function(conceptSetsFolderPath = here::here("inputs/conceptSets"),
                                   executionSettings = NULL,
                                   verbose = TRUE) {
  checkmate::assert_class(executionSettings, "ExecutionSettings", null.ok = TRUE)
  checkmate::assert_logical(verbose, len = 1)

  dbPath <- fs::path(conceptSetsFolderPath, "conceptSetManifest.sqlite")

  manifest <- ConceptSetManifest$new(dbPath = dbPath, executionSettings = executionSettings)

  json_dir <- fs::path(conceptSetsFolderPath, "json")

  if (dir.exists(json_dir)) {
    on_disk <- list.files(json_dir, pattern = "\\.json$", full.names = TRUE, recursive = TRUE)

    if (length(on_disk) > 0) {
      conn <- DBI::dbConnect(RSQLite::SQLite(), dbPath)
      on.exit(DBI::dbDisconnect(conn))

      registered_paths <- DBI::dbGetQuery(
        conn,
        "SELECT filePath FROM concept_set_manifest WHERE status = 'active'"
      )$filePath

      new_files <- on_disk[!(fs::path_rel(on_disk) %in% registered_paths)]

      if (length(new_files) > 0) {
        if (verbose) {
          cli::cli_alert_info("Registering {length(new_files)} new concept set file(s) found in {fs::path_rel(json_dir)}")
        }
        for (file_path in new_files) {
          label <- tools::file_path_sans_ext(basename(file_path))
          tryCatch({
            manifest$addConceptSetFile(filePath = file_path, label = label)
          }, error = function(e) {
            cli::cli_alert_warning("Skipping {label}: {e$message}")
          })
        }
      }
    }
  }

  if (verbose) {
    validation_status  <- manifest$validateManifest()
    missing_conceptsets <- validation_status[
      !is.na(validation_status$status) &
        validation_status$status == "active" &
        !validation_status$file_exists,
    ]

    if (nrow(missing_conceptsets) > 0) {
      cli::cli_rule("Missing Concept Set Files Detected")
      cli::cli_alert_warning("{nrow(missing_conceptsets)} concept set file(s) are missing:")
      for (i in seq_len(nrow(missing_conceptsets))) {
        cs_info <- missing_conceptsets[i, ]
        cli::cli_bullets(c("x" = "ID {cs_info$id}: {cs_info$label}"))
      }
      cli::cli_rule()
      cli::cli_bullets(c(
        "i" = "Use {.code manifest$validateManifest()} to see full status",
        "i" = "Use {.code manifest$cleanupMissing()} to remove missing concept sets"
      ))
    }
  }

  return(manifest)
}


#' Reset Concept Set Manifest
#'
#' Cleans up concept set manifest data at one of two scopes. All destructive
#' operations require the user to type \code{"yes"} at a confirmation prompt
#' (disable with \code{confirm = FALSE} for scripted use).
#'
#' Unlike cohort manifests, all concept set JSON files are user-owned sources
#' (nothing is auto-generated), so there is no "derived" tier.
#'
#' @section Scope options:
#' \describe{
#'   \item{\code{"manifest"} (default)}{Deletes only the SQLite database.
#'     JSON files in \code{json/} are preserved. On the next call to
#'     \code{loadConceptSetManifest()}, those files are automatically
#'     re-registered — no manual \code{$add*()} calls required.}
#'   \item{\code{"full"}}{Deletes the SQLite database, the \code{json/}
#'     folder, and \code{conceptSetsLoad.csv}. Complete wipe.}
#' }
#'
#' @param manifest A \code{ConceptSetManifest} R6 object. Optional; when
#'   provided the folder path is inferred automatically.
#' @param conceptSetsFolderPath Character. Path to the conceptSets folder.
#'   Inferred from \code{manifest} when provided; otherwise defaults to
#'   \code{here::here("inputs/conceptSets")}.
#' @param scope Character. One of \code{"manifest"} (default) or
#'   \code{"full"}.
#' @param confirm Logical. If \code{TRUE} (default), the user must type
#'   \code{"yes"} to proceed. Set to \code{FALSE} for non-interactive use.
#'
#' @return Invisibly returns NULL.
#'
#' @export
resetConceptSetManifest <- function(manifest = NULL,
                                    conceptSetsFolderPath = here::here("inputs/conceptSets"),
                                    scope = c("manifest", "full"),
                                    confirm = TRUE) {
  scope <- match.arg(scope)
  checkmate::assert_logical(confirm, len = 1)

  if (!is.null(manifest)) {
    checkmate::assert_r6(manifest, classes = "ConceptSetManifest")
    conceptSetsFolderPath <- dirname(manifest$getDbPath())
  }

  checkmate::assert_string(conceptSetsFolderPath)

  dbPath   <- fs::path(conceptSetsFolderPath, "conceptSetManifest.sqlite")
  json_dir <- fs::path(conceptSetsFolderPath, "json")
  load_csv <- fs::path(conceptSetsFolderPath, "conceptSetsLoad.csv")

  n_json <- if (dir.exists(json_dir)) length(list.files(json_dir, recursive = TRUE)) else 0L

  if (!file.exists(dbPath) && n_json == 0L) {
    cli::cli_alert_warning("Nothing to reset: manifest database and json/ folder not found.")
    return(invisible(NULL))
  }

  # ── Print summary of what will be deleted ────────────────────────────────
  cli::cli_rule("Concept Set Manifest Reset")

  if (scope == "manifest") {
    cli::cli_alert_danger("The following will be {.strong permanently deleted}:")
    cli::cli_bullets(c("x" = "Manifest database: {.file {fs::path_rel(dbPath)}}"))
    cli::cli_alert_info(
      "{n_json} JSON file(s) in {.file {fs::path_rel(json_dir)}} will be preserved."
    )
    cli::cli_alert_info(
      "Call {.code loadConceptSetManifest()} to automatically re-register them."
    )
  } else if (scope == "full") {
    cli::cli_alert_danger("The following will be {.strong permanently deleted}:")
    cli::cli_bullets(c(
      "x" = "Manifest database: {.file {fs::path_rel(dbPath)}}",
      "x" = "{n_json} JSON file(s) in {.file {fs::path_rel(json_dir)}}",
      "x" = "{.file {fs::path_rel(load_csv)}} (if present)"
    ))
  }

  if (confirm) {
    answer <- readline("Type 'yes' to confirm reset, anything else to cancel: ")
    if (!identical(trimws(tolower(answer)), "yes")) {
      cli::cli_alert_info("Reset cancelled.")
      return(invisible(NULL))
    }
  }

  # ── Execute deletions ─────────────────────────────────────────────────────

  if (file.exists(dbPath)) {
    file.remove(dbPath)
    cli::cli_alert_success("Deleted manifest database: {.file {fs::path_rel(dbPath)}}")
  }

  if (scope == "full") {
    if (dir.exists(json_dir)) {
      unlink(json_dir, recursive = TRUE)
      cli::cli_alert_success("Deleted {.file {fs::path_rel(json_dir)}} ({n_json} file(s)).")
    }
    if (file.exists(load_csv)) {
      file.remove(load_csv)
      cli::cli_alert_success("Deleted {.file {fs::path_rel(load_csv)}}.")
    }
    cli::cli_alert_info(
      "Full reset complete. Call {.code initConceptSetManifest()} to start fresh."
    )
  } else {
    cli::cli_alert_info(
      "Call {.code loadConceptSetManifest()} to rebuild from existing JSON files."
    )
  }

  invisible(NULL)
}


#' Create Blank Concept Sets Load File
#'
#' Creates a blank conceptSetsLoad.csv template file in the specified folder.
#'
#' @param conceptSetsFolderPath Character. Path to the conceptSets folder.
#'   Defaults to `here::here("inputs/conceptSets")`.
#'
#' @return Invisibly returns the file path.
#'
#' @export
createBlankConceptSetsLoadFile <- function(conceptSetsFolderPath = here::here("inputs/conceptSets")) {
  checkmate::assert_string(conceptSetsFolderPath)

  fs::dir_create(conceptSetsFolderPath)

  file_path <- fs::path(conceptSetsFolderPath, "conceptSetsLoad.csv")

  # Check if file already exists
  if (fs::file_exists(file_path)) {
    cli::cli_alert_warning("File already exists: {.file {fs::path_rel(file_path)}}")
    answer <- readline("Overwrite with blank template? (yes/no): ")
    if (!identical(trimws(tolower(answer)), "yes")) {
      cli::cli_alert_info("Operation cancelled. Existing file was not modified.")
      return(NULL)
    }
    cli::cli_alert_info("Overwriting existing file with blank template...")
  }

  template <- data.frame(
    atlasId = integer(1),
    label = character(1),
    category = character(1),
    subCategory = character(1),
    sourceCode = character(1),
    domain = character(1),
    file_name = character(1),
    stringsAsFactors = FALSE
  )

  file_path <- fs::path(conceptSetsFolderPath, "conceptSetsLoad.csv")
  readr::write_csv(template, file = file_path)

  cli::cli_rule("Blank Concept Sets Load File Created")
  cli::cli_text("File created at: {.file {fs::path_rel(file_path)}}")
  cli::cli_text("")
  cli::cli_h3("Column Guide:")
  cli::cli_ul(c(
    "{.field atlasId} - ATLAS concept set ID (numeric)",
    "{.field label} - Display name (e.g., 'Hypertension diagnoses')",
    "{.field category} - Broad category (e.g., 'Cardiovascular')",
    "{.field subCategory} - Optional sub-grouping",
    "{.field sourceCode} - TRUE/FALSE (usually FALSE for concept sets)",
    "{.field domain} - One of: drug_exposure, condition_occurrence, measurement, procedure, observation, visit_occurrence",
    "{.field file_name} - Path to JSON file (e.g., 'json/hypertension.json')"
  ))
  cli::cli_text("")
  cli::cli_h3("Next Steps:")
  cli::cli_ol(c(
    "Open {.file inputs/conceptSets/conceptSetsLoad.csv} in Excel or your text editor",
    "Fill in your concept set metadata",
    "Save the file",
    "Use {.code importAtlasConceptSets()} to import JSON definitions from ATLAS",
    "Use {.code loadConceptSetManifest()} to load into your study"
  ))

  invisible(file_path)
}


#' Import CIRCE Concept Sets from ATLAS
#'
#' @description
#' **Deprecated.** Use [ConceptSetManifest]`$importAtlasConceptSets()` instead.
#'
#' @param conceptSetsFolderPath Character. Path to conceptSets folder.
#' @param atlasConnection An ATLAS connection object.
#'
#' @return Invisibly returns the updated concept set load dataframe.
#'
#' @export
importAtlasConceptSets <- function(conceptSetsFolderPath = here::here("inputs/conceptSets"),
                                   atlasConnection) {
  lifecycle::deprecate_warn(
    when = "0.1.0",
    what = "importAtlasConceptSets()",
    details = c(
      "i" = "Use ConceptSetManifest$importAtlasConceptSets() instead:",
      "i" = "  manifest <- ConceptSetManifest$new(dbPath = '...')",
      "i" = "  manifest$importAtlasConceptSets(atlasConnection)"
    )
  )

  dbPath <- fs::path(conceptSetsFolderPath, "conceptSetManifest.sqlite")
  manifest <- ConceptSetManifest$new(dbPath = dbPath)
  conceptSetsLoadPath <- fs::path(conceptSetsFolderPath, "conceptSetsLoad.csv")
  result <- manifest$importAtlasConceptSets(
    atlasConnection = atlasConnection,
    conceptSetsLoadPath = conceptSetsLoadPath
  )

  return(invisible(result))
}

tableExists <- function(connection, schema, tableName, dbms) {
  tryCatch({
    query <- paste0("SELECT COUNT(*) FROM ", schema, ".", tableName, " WHERE 1=0")
    result <- DatabaseConnector::querySql(connection, query)
    return(TRUE)
  }, error = function(e) {
    return(FALSE)
  })
}


createMainCohortTableSql <- function(schema, tableName, dbms, tempEmulationSchema = NULL) {
  sql <- "CREATE TABLE @schema.@table_name (
    cohort_definition_id BIGINT,
    subject_id BIGINT,
    cohort_start_date DATE,
    cohort_end_date DATE
  );"

  sql <- SqlRender::render(
    sql = sql,
    schema = schema,
    table_name = tableName
  )

  sql <- SqlRender::translate(
    sql = sql,
    targetDialect = dbms,
    tempEmulationSchema = tempEmulationSchema
  )

  return(sql)
}


createInclusionTableSql <- function(schema, tableName, dbms) {
  sql <- "CREATE TABLE @schema.@table_name (
    cohort_definition_id BIGINT NOT NULL,
  	rule_sequence INT NOT NULL,
  	name VARCHAR(255) NULL,
  	description VARCHAR(1000) NULL
  );"

  sql <- SqlRender::render(
    sql = sql,
    schema = schema,
    table_name = tableName
  )

  sql <- SqlRender::translate(
    sql = sql,
    targetDialect = dbms
  )

  return(sql)
}


createInclusionResultTableSql <- function(schema, tableName, dbms) {
  sql <- "CREATE TABLE @schema.@table_name (
    cohort_definition_id BIGINT NOT NULL,
  	inclusion_rule_mask BIGINT NOT NULL,
  	person_count BIGINT NOT NULL,
  	mode_id INT
  );"

  sql <- SqlRender::render(
    sql = sql,
    schema = schema,
    table_name = tableName
  )

  sql <- SqlRender::translate(
    sql = sql,
    targetDialect = dbms
  )

  return(sql)
}


createInclusionStatsTableSql <- function(schema, tableName, dbms) {
  sql <- "CREATE TABLE @schema.@table_name (
    cohort_definition_id BIGINT NOT NULL,
  	rule_sequence INT NOT NULL,
  	person_count BIGINT NOT NULL,
  	gain_count BIGINT NOT NULL,
  	person_total BIGINT NOT NULL,
  	mode_id INT
  );"

  sql <- SqlRender::render(
    sql = sql,
    schema = schema,
    table_name = tableName
  )

  sql <- SqlRender::translate(
    sql = sql,
    targetDialect = dbms
  )

  return(sql)
}


createSummaryStatsTableSql <- function(schema, tableName, dbms) {
  sql <- "CREATE TABLE @schema.@table_name (
    cohort_definition_id BIGINT NOT NULL,
  	base_count BIGINT NOT NULL,
  	final_count BIGINT NOT NULL,
  	mode_id INT
  );"

  sql <- SqlRender::render(
    sql = sql,
    schema = schema,
    table_name = tableName
  )

  sql <- SqlRender::translate(
    sql = sql,
    targetDialect = dbms
  )

  return(sql)
}


createCensorStatsTableSql <- function(schema, tableName, dbms) {
  sql <- "CREATE TABLE @schema.@table_name (
    cohort_definition_id BIGINT NOT NULL,
    lost_count BIGINT NOT NULL
  );"

  sql <- SqlRender::render(
    sql = sql,
    schema = schema,
    table_name = tableName
  )

  sql <- SqlRender::translate(
    sql = sql,
    targetDialect = dbms
  )

  return(sql)
}


createChecksumTableSql <- function(schema, tableName, dbms) {
  sql <- "CREATE TABLE @schema.@table_name (
    cohort_definition_id BIGINT NOT NULL,
    checksum varchar(500) NOT NULL,
    start_time FLOAT,
    end_time FLOAT
  );"

  sql <- SqlRender::render(
    sql = sql,
    schema = schema,
    table_name = tableName
  )

  sql <- SqlRender::translate(
    sql = sql,
    targetDialect = dbms
  )

  return(sql)
}


#' Expand JSON Tags to Columns
#'
#' Takes a manifest dataframe (from `tabulateManifest()`, `queryConceptSetsByTag()`, etc.)
#' and pivots the JSON tags column into separate columns. Each tag key becomes a column name,
#' and the values populate the rows.
#'
#' @param df Data frame. A manifest output dataframe with a `tags` column containing
#'   JSON strings (e.g., from `ConceptSetManifest$tabulateManifest()` or
#'   `ConceptSetManifest$queryConceptSetsByTag()`).
#' @param dropTagsCol Logical. If TRUE, drops the original `tags` column after expansion.
#'   Defaults to TRUE.
#'
#' @return Data frame. The input dataframe with JSON tags expanded into separate columns.
#'   Rows with NA tags are preserved with NA values in the new columns.
#'
#' @details
#' This function:
#' 1. Parses each JSON string in the tags column using `jsonlite::fromJSON()`
#' 2. Extracts all unique keys across all JSON objects
#' 3. Creates new columns for each key
#' 4. Populates values, with NA for missing keys in any row
#' 5. Optionally drops the original JSON tags column
#'
#' **Example:**
#' Input dataframe:
#' ```
#' id | label | tags
#' 1  | CS1   | {"category":"drug","subCategory":"steroid","domain":"drug_exposure"}
#' 2  | CS2   | {"category":"covariate","domain":"condition_occurrence"}
#' ```
#'
#' Output dataframe:
#' ```
#' id | label | category  | subCategory | domain
#' 1  | CS1   | drug      | steroid     | drug_exposure
#' 2  | CS2   | covariate | NA          | condition_occurrence
#' ```
#'
#' @export
expandManifestTags <- function(df, dropTagsCol = TRUE) {
  checkmate::assert_data_frame(df)
  checkmate::assert_logical(dropTagsCol, len = 1)

  # grab tags column
  tags_col <- df$tags

  tags_list <- vector('list', length = nrow(df))
  for (i in seq_along(tags_list)) {
    # if tags column na then return empty list
    if (is.na(tags_col[i])) {
      tags_list[[i]] <- list()
    } else {
      # ow get the parse json to r list
      tags_list[[i]] <- tryCatch({
        jsonlite::fromJSON(tags_col[i], simplifyVector = FALSE)
      }, error = function(e) {
        cli::cli_alert_warning("Failed to parse JSON tag: {tags_col[i]}")
        return(list())
      })
    }
  }

  # Collect all unique keys
  all_keys <- unique(unlist(lapply(tags_list, names)))

  # Create new columns from tags
  for (key in all_keys) {
    df[[key]] <- sapply(tags_list, function(tag_obj) {
      if (key %in% names(tag_obj)) {
        tag_obj[[key]]
      } else {
        NA_character_
      }
    })
  }

  # Drop original tags column if requested
  if (dropTagsCol) {
    df$tags <- NULL
  }

  return(df)
}


getCohortTableNames <- function(cohortTable = "cohort",
                                cohortSampleTable = cohortTable,
                                cohortInclusionTable = paste0(cohortTable, "_inclusion"),
                                cohortInclusionResultTable = paste0(cohortTable, "_inclusion_result"),
                                cohortInclusionStatsTable = paste0(cohortTable, "_inclusion_stats"),
                                cohortSummaryStatsTable = paste0(cohortTable, "_summary_stats"),
                                cohortCensorStatsTable = paste0(cohortTable, "_censor_stats"),
                                cohortSubsetAttritionTable = paste0(cohortTable, "_subset_attrition"),
                                cohortChecksumTable = paste0(cohortTable, "_checksum")) {
  return(list(
    cohortTable = cohortTable,
    cohortSampleTable = cohortSampleTable,
    cohortInclusionTable = cohortInclusionTable,
    cohortInclusionResultTable = cohortInclusionResultTable,
    cohortInclusionStatsTable = cohortInclusionStatsTable,
    cohortSummaryStatsTable = cohortSummaryStatsTable,
    cohortCensorStatsTable = cohortCensorStatsTable,
    cohortSubsetAttritionTable = cohortSubsetAttritionTable,
    cohortChecksumTable = cohortChecksumTable
  ))
}


# ============================================================
# ATLAS IMPORT HELPERS
# ============================================================

#' Cascade stale status to downstream dependents
#'
#' Given a set of cohort IDs whose definitions changed, marks all transitive
#' dependent cohorts as 'stale' in the manifest database. Uses BFS through
#' the reverse dependency graph stored in cohort_manifest.depends_on.
#'
#' @param dbPath Character. Path to the manifest SQLite database.
#' @param cohort_ids Integer vector. The seed cohort IDs that changed.
#' @return Invisibly returns the integer vector of IDs marked stale.
#' @keywords internal
cascadeStaleDownstream <- function(dbPath, cohort_ids) {
  cohort_ids <- as.integer(cohort_ids)

  conn <- DBI::dbConnect(RSQLite::SQLite(), dbPath)
  on.exit(DBI::dbDisconnect(conn))

  rows <- DBI::dbGetQuery(
    conn,
    "SELECT id, depends_on FROM cohort_manifest
     WHERE status IN ('active', 'stale')"
  )

  if (nrow(rows) == 0) {
    return(invisible(integer(0)))
  }

  # Build reverse graph: parent_id -> vector of child_ids
  reverse_graph <- list()
  for (i in seq_len(nrow(rows))) {
    child_id <- rows$id[i]
    dep_raw  <- rows$depends_on[i]

    if (!is.na(dep_raw) && nchar(dep_raw) > 0) {
      parent_ids <- tryCatch(
        as.integer(jsonlite::fromJSON(dep_raw)),
        error = function(e) integer(0)
      )

      for (pid in parent_ids) {
        pid_str <- as.character(pid)
        reverse_graph[[pid_str]] <- c(reverse_graph[[pid_str]], child_id)
      }
    }
  }

  # BFS from seed cohort_ids through the reverse graph
  visited  <- integer(0)
  queue    <- cohort_ids

  while (length(queue) > 0) {
    current  <- queue[1]
    queue    <- queue[-1]
    curr_str <- as.character(current)

    children <- reverse_graph[[curr_str]]
    if (!is.null(children)) {
      new_children <- setdiff(children, visited)
      visited <- c(visited, new_children)
      queue   <- c(queue, new_children)
    }
  }

  if (length(visited) == 0) {
    return(invisible(integer(0)))
  }

  # Build parameterized IN clause with placeholders
  placeholders <- paste(rep("?", length(visited)), collapse = ", ")

  # Bulk update to stale
  DBI::dbExecute(
    conn,
    paste0(
      "UPDATE cohort_manifest SET status = 'stale', updated_at = CURRENT_TIMESTAMP",
      " WHERE id IN (", placeholders, ")"
    ),
    as.list(visited)
  )

  # Report
  labels <- DBI::dbGetQuery(
    conn,
    paste0("SELECT id, label FROM cohort_manifest WHERE id IN (", placeholders, ")"),
    as.list(visited)
  )
  for (i in seq_len(nrow(labels))) {
    cli::cli_alert_warning(
      "Marked stale: [{labels$id[i]}] {labels$label[i]}"
    )
  }

  invisible(visited)
}

list_tags_in_row <- function(row) {
  reserved_cols <- c("atlasId","label", "category", "file_name") # file_name is legacy
  tag_cols <- setdiff(names(row), reserved_cols)
  tags <- list() # atlasId and other columns become tags
  for (col in tag_cols) {
    val <- row[[col]]
    if (!is.na(val) && nchar(as.character(val)) > 0) {
      tags[[col]] <- as.character(val)
    }
  }
  return(tags)
}

check_which_cohorts_exist <- function(cm_atlas_subset, cohort_load) {
  # get the cm with atlas ids
  current_atlas_cm <- cm_atlas_subset |>
    dplyr::select(
      id, label, category, tags
    ) |> 
    dplyr::mutate(
      tags_list = purrr::map(tags, ~jsonlite::fromJSON(.x)),
      atlasId = purrr::map_int(tags_list, ~.x$atlasId),
      status = "active"
    ) |>
    dplyr::select(
      id, atlasId, label, category, status
    )
  
  # show which cohorts in the load file are new to the current manifest
  compare_cm <- cohort_load |>
    dplyr::left_join(
      current_atlas_cm |> dplyr::select(id, atlasId, status), by = c("atlasId")
    ) |>
    tidyr::replace_na(list(status = "new"))

  return(compare_cm)

}

# importOneAtlasCohort <- function(row, tag_cols, dbPath, atlasConnection, sqlite_conn) {
#   # Build tags from extra columns
#   tags <- list()
#   for (col in tag_cols) {
#     val <- row[[col]]
#     if (!is.na(val) && nchar(as.character(val)) > 0) {
#       tags[[col]] <- as.character(val)
#     }
#   }

#   row_label <- as.character(row$label)
#   row_atlas_id <- as.integer(row$atlasId)
#   row_category <- as.character(row$category)

#   # Check if a cohort with this label already exists
#   existing <- DBI::dbGetQuery(
#     sqlite_conn,
#     "SELECT id, label, file_path, hash FROM cohort_manifest WHERE label = ? AND status = 'active'",
#     list(row_label)
#   )

#   if (nrow(existing) > 0) {
#     # Fetch JSON from ATLAS and compare hashes
#     cohort_def <- atlasConnection$getCohortDefinition(cohortId = row_atlas_id)
#     expression_json <- cohort_def$expression[1]
#     new_hash <- rlang::hash(expression_json)

#     existing_id <- existing$id[1]
#     existing_path <- existing$file_path[1]

#     if (identical(new_hash, existing$hash[1])) {
#       cli::cli_alert_info("Skipping {row_label} (ID {existing_id}) — unchanged")
#       res <- list(id = existing_id, label = row_label, row_category = row_category, status = "skipped")
#       return(res)
#     }

#     # JSON changed — overwrite file and update manifest
#     cohorts_dir <- dirname(dbPath)
#     full_path <- fs::path(cohorts_dir, existing_path)
#     if (file.exists(full_path)) {
#       writeLines(expression_json, full_path)
#     } else {
#       output_name <- if (!is.null(cohort_def$saveName[1]) && nzchar(cohort_def$saveName[1])) {
#         cohort_def$saveName[1]
#       } else {
#         row_label
#       }
#       json_dir <- fs::path(cohorts_dir, "json")
#       if (!dir.exists(json_dir)) dir.create(json_dir, recursive = TRUE)
#       full_path <- fs::path(json_dir, paste0(output_name, ".json"))
#       writeLines(expression_json, full_path)
#       existing_path <- fs::path_rel(full_path)
#     }

#     DBI::dbExecute(
#       sqlite_conn,
#       "UPDATE cohort_manifest SET hash = ?, file_path = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
#       list(new_hash, existing_path, existing_id)
#     )
#     cascadeStaleDownstream(dbPath, existing_id)
#     cli::cli_alert_success("Updated {row_label} (ID {existing_id}) — JSON changed, file overwritten")
#     res <- list(id = existing_id, label = row_label, row_category = row_category, status = "updated")
#     return(res)
#   }

#   # New cohort — note: addAtlasCohort is called by the caller (the R6 method)
#   # who has access to the manifest object and its private methods.
#   # We return a marker that the caller will handle.
#   res <- list(id = NULL, label = row_label, status = "new", 
#               row = row, tags = tags, atlasConnection = atlasConnection,
#               row_atlas_id = row_atlas_id, row_category = row_category)
#   return(res)
# }
