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
  cli::cli_alert_info("Add cohorts with $addAtlasCohort(), $addCaprCohort(), $addSqlCohort(), or $importAtlasCohorts()")

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

  if (verbose) {
    n_cohorts <- length(cm$getManifest())
    cli::cli_alert_success("Loaded cohort manifest: {n_cohorts} active cohort(s)")
  }

  if (verbose) {
    .warn_untracked_files(cohortsFolderPath, cm)
  }

  return(cm)
}


#' @noRd
.warn_untracked_files <- function(cohortsFolderPath, cm) {
  manifest_files <- vapply(cm$getManifest(), function(cd) cd$getFilePath(), character(1))

  json_dir    <- fs::path(cohortsFolderPath, "json")
  sql_dir     <- fs::path(cohortsFolderPath, "sql")
  derived_dir <- fs::path(cohortsFolderPath, "derived")

  all_files <- character(0)
  if (dir.exists(json_dir)) {
    all_files <- c(all_files, list.files(json_dir, pattern = "\\.(json|sql)$", full.names = TRUE, recursive = TRUE))
  }
  if (dir.exists(sql_dir)) {
    all_files <- c(all_files, list.files(sql_dir, pattern = "\\.sql$", full.names = TRUE, recursive = TRUE))
  }
  if (dir.exists(derived_dir)) {
    all_files <- c(all_files, list.files(derived_dir, pattern = "\\.sql$", full.names = TRUE, recursive = TRUE))
  }

  all_files_rel <- fs::path_rel(all_files)
  untracked <- all_files_rel[!all_files_rel %in% manifest_files]

  if (length(untracked) > 0) {
    cli::cli_alert_warning("{length(untracked)} file(s) on disk not in manifest:")
    for (f in utils::head(untracked, 5)) {
      cli::cli_bullets(c("!" = "{f}"))
    }
    if (length(untracked) > 5) {
      cli::cli_bullets(c("!" = "... and {length(untracked) - 5} more"))
    }
    cli::cli_alert_info("Use $addAtlasCohort(), $addSqlCohort(), or $importAtlasCohorts() to register them.")
  }
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
#'     folder. Source files in \code{json/} and \code{sql/} are preserved and
#'     can be re-registered after \code{initCohortManifest()}.}
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
                                confirm = TRUE) {
  scope <- match.arg(scope)
  checkmate::assert_logical(confirm, len = 1)

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
    cli::cli_alert_danger("The following will be {.strong permanently deleted}:")
    cli::cli_bullets(c(
      "x" = "Manifest database: {.file {fs::path_rel(dbPath)}}",
      "x" = "{n_derived} derived file(s) in {.file {fs::path_rel(derived_dir)}}"
    ))
    cli::cli_alert_info(
      "Source files in {.file json/} ({n_json} file(s)) and {.file sql/} ({n_sql} file(s)) will be preserved."
    )
    cli::cli_alert_info(
      "After reset, call {.code initCohortManifest()} then re-register cohorts with {.code $add*()} methods."
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
      return(invisible(NULL))
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
    if (dir.exists(derived_dir)) {
      unlink(derived_dir, recursive = TRUE)
      cli::cli_alert_success("Deleted {.file {fs::path_rel(derived_dir)}} ({n_derived} file(s)).")
    }
    cli::cli_alert_info(
      "Call {.code initCohortManifest()} then re-register cohorts with {.code $addAtlasCohort()}, {.code $addSqlCohort()}, etc."
    )

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

  template <- data.frame(
    atlasId = integer(1),
    label = character(1),
    category = character(1),
    subCategory = character(1),
    file_name = character(1),
    stringsAsFactors = FALSE
  )

  file_path <- fs::path(cohortsFolderPath, "cohortsLoad.csv")
  readr::write_csv(template, file = file_path)

  cli::cli_rule("Blank Cohorts Load File Created")
  cli::cli_text("File created at: {.file {fs::path_rel(file_path)}}")
  cli::cli_text("")
  cli::cli_h3("Column Guide:")
  cli::cli_ul(c(
    "{.field atlasId} - ATLAS cohort ID (numeric)",
    "{.field label} - Display name (e.g., 'Type 2 Diabetes patients')",
    "{.field category} - Broad category (e.g., 'Disease Populations')",
    "{.field subCategory} - Optional sub-grouping",
    "{.field file_name} - Path to JSON file (e.g., 'json/t2dm_patients.json')"
  ))
  cli::cli_text("")
  cli::cli_h3("Next Steps:")
  cli::cli_ol(c(
    "Open {.file inputs/cohorts/cohortsLoad.csv} in Excel or your text editor",
    "Fill in your cohort metadata",
    "Save the file",
    "Use {.code importAtlasCohorts()} to import JSON definitions from ATLAS",
    "Use {.code loadCohortManifest()} to load into your study"
  ))

  invisible(file_path)
}


#' Function to parse tags string from database into a named list
#'
#' @param tags_str Character. Tags string in format "name: value | name: value"
#'
#' @return List. Named list of tags
#'
#' @keywords internal
parseTagsString <- function(tags_str) {
  if (is.na(tags_str) || tags_str == "") {
    return(list())
  }

  tag_pairs <- strsplit(tags_str, " \\| ")[[1]]

  tags_list <- list()
  for (pair in tag_pairs) {
    parts <- strsplit(pair, ":\\s*")[[1]]
    if (length(parts) == 2) {
      tag_name  <- trimws(parts[1])
      tag_value <- trimws(parts[2])
      tags_list[[tag_name]] <- tag_value
    }
  }

  return(tags_list)
}


#' Import CIRCE Cohort Definitions from ATLAS
#'
#' @description
#' Imports CIRCE JSON cohort definitions from ATLAS and registers them in the manifest.
#' This is a wrapper around [CohortManifest]`$importAtlasCohorts()`.
#'
#' @note Deprecated. Use [CohortManifest]`$importAtlasCohorts()` directly.
#'
#' @param atlasConnection An ATLAS connection object.
#' @param manifestPath Character. Path to the cohort manifest database.
#' @param cohortsLoadPath Character. Path to the CSV file containing cohort metadata.
#'
#' @return Invisibly returns a tibble with import results.
#'
#' @export
importAtlasCohorts <- function(atlasConnection,
                               manifestPath = here::here("inputs/cohorts/cohortManifest.sqlite"),
                               cohortsLoadPath = here::here("inputs/cohorts/cohortsLoad.csv")) {
  lifecycle::deprecate_warn(
    "0.1.0",
    "importAtlasCohorts()",
    details = c(
      "i" = "Use CohortManifest$importAtlasCohorts() method directly:",
      "i" = "  manifest <- CohortManifest$new(dbPath = '...')",
      "i" = "  manifest$importAtlasCohorts(atlasConnection, cohortsLoadPath)"
    )
  )

  if (file.exists(manifestPath)) {
    manifest <- CohortManifest$new(dbPath = manifestPath)
  } else {
    cohorts_folder <- dirname(manifestPath)
    if (!dir.exists(cohorts_folder)) {
      dir.create(cohorts_folder, recursive = TRUE, showWarnings = FALSE)
    }
    manifest <- CohortManifest$new(dbPath = manifestPath)
  }

  results <- manifest$importAtlasCohorts(
    atlasConnection = atlasConnection,
    cohortsLoadPath = cohortsLoadPath
  )

  return(invisible(results))
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
     WHERE status = 'active'
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


#' Visualize Cohort Dependencies (Deprecated)
#'
#' @description
#' **Deprecated.** Use [plotCohortGraph()] for a mermaid dependency diagram and
#' [CohortManifest]`$reviewDependentCohorts()` for a tabular dependency summary.
#'
#' @param manifest A CohortManifest object.
#' @param outputPath Character. Optional path to save the markdown report. Defaults to NULL.
#'
#' @return Character. The markdown report content (invisibly).
#'
#' @export
visualizeCohortDependencies <- function(manifest, outputPath = NULL) {
  lifecycle::deprecate_warn(
    "0.0.3",
    "visualizeCohortDependencies()",
    details = paste(
      "Use plotCohortGraph(manifest) for a mermaid dependency diagram.",
      "Use manifest$reviewDependentCohorts() for a tabular dependency summary."
    )
  )

  checkmate::assert_r6(manifest, classes = "CohortManifest")
  checkmate::assert_character(outputPath, len = 1, null.ok = TRUE)

  cohort_list <- manifest$getManifest()

  if (length(cohort_list) == 0) {
    cli::cli_alert_warning("No cohorts found in manifest")
    return(invisible(NULL))
  }

  total_cohorts       <- length(cohort_list)
  cohort_types        <- sapply(cohort_list, function(c) c$getCohortType())
  type_counts         <- table(cohort_types)
  base_cohort_count   <- ifelse("circe" %in% names(type_counts), type_counts[["circe"]], 0)
  dependent_cohort_count <- total_cohorts - base_cohort_count

  # Read dependency data from SQLite
  conn <- DBI::dbConnect(RSQLite::SQLite(), manifest$getDbPath())
  on.exit(DBI::dbDisconnect(conn))

  dep_rows <- DBI::dbGetQuery(
    conn,
    "SELECT id, depends_on FROM cohort_manifest WHERE status = 'active'"
  )
  deps_lookup <- stats::setNames(dep_rows$depends_on, as.character(dep_rows$id))

  parse_parents <- function(cid) {
    dep_json <- deps_lookup[[as.character(cid)]]
    if (is.null(dep_json) || is.na(dep_json) || nchar(dep_json) == 0) {
      return(integer(0))
    }
    tryCatch(as.integer(jsonlite::fromJSON(dep_json)), error = function(e) integer(0))
  }

  # Mermaid diagram
  node_defs <- character()
  edge_defs <- character()

  for (cohort in cohort_list) {
    cid   <- cohort$getId()
    clbl  <- cohort$label
    ctype <- cohort$getCohortType()
    nid   <- paste0("c", cid)

    node_shape <- switch(
      ctype,
      circe  = paste0('["', clbl, '"]'),
      subset = paste0('("',  clbl, '")'),
      union  = paste0('{{"', clbl, '"}}'),
      paste0('{{{{"', clbl, '"}}}}')
    )
    node_defs <- c(node_defs, paste0(nid, node_shape))

    for (pid in parse_parents(cid)) {
      edge_defs <- c(edge_defs, paste0("c", pid, " --> ", nid))
    }
  }

  mermaid_diagram <- paste(c("graph TD", node_defs, edge_defs), collapse = "\n")

  # Summary table rows
  cohort_rows <- character()
  for (cohort in cohort_list) {
    cid   <- cohort$getId()
    pids  <- parse_parents(cid)
    dep_str <- if (length(pids) == 0) "None" else paste(pids, collapse = ", ")
    cohort_rows <- c(cohort_rows, paste0(
      "| ", cid, " | ", cohort$label, " | ", cohort$getCohortType(), " | ", dep_str, " |"
    ))
  }

  report <- paste0(
    "# Cohort Dependency Report\n\n",
    "**Generated**: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n",
    "## Overview\n\n",
    "| Metric | Count |\n",
    "|--------|-------|\n",
    "| Total Cohorts | ", total_cohorts, " |\n",
    "| Base Cohorts (CIRCE) | ", base_cohort_count, " |\n",
    "| Dependent Cohorts | ", dependent_cohort_count, " |\n",
    "\n",
    "### Cohort Type Breakdown\n\n",
    paste(sapply(names(type_counts), function(t) paste0("- **", t, "**: ", type_counts[[t]])), collapse = "\n"),
    "\n\n",
    "## Dependency Diagram\n\n",
    "```mermaid\n", mermaid_diagram, "\n```\n\n",
    "**Legend:**\n",
    "- \u25ad Rectangle: CIRCE (base) cohort\n",
    "- \u25ef Circle: Subset cohort\n",
    "- \u25c7 Diamond: Union cohort\n",
    "- \u2b21 Hexagon: Complement cohort\n\n",
    "## Cohort Summary Table\n\n",
    "| ID | Label | Type | Depends On |\n",
    "|----|----|------|----------|\n",
    paste(cohort_rows, collapse = "\n"),
    "\n\n",
    "---\n",
    "*Report generated by picard dependency visualizer*\n"
  )

  if (!is.null(outputPath)) {
    if (!dir.exists(outputPath)) {
      dir.create(outputPath, recursive = TRUE, showWarnings = FALSE)
    }
    output_file <- fs::path(outputPath, "cohort_dependencies.md")
    readr::write_file(report, file = output_file)
    cli::cli_alert_success("Dependency report saved to: {fs::path_rel(output_file)}")
  }

  invisible(report)
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


#' Define (Enrich) a Custom SQL Cohort in the Manifest
#'
#' @description
#' Enriches a cohort that has already been discovered by [loadCohortManifest()] with
#' a user-friendly label, tags, and the `"custom"` cohort type.
#'
#' @param manifest A [CohortManifest] R6 object.
#' @param label Character. The user-friendly display name.
#' @param tags Named list. Optional metadata tags. Defaults to `list()`.
#' @param cohortId Integer. The cohort ID in the manifest. Provide either `cohortId`
#'   or `sqlFilePath`, not both.
#' @param sqlFilePath Character. Path to the SQL file. Provide either `sqlFilePath`
#'   or `cohortId`, not both.
#'
#' @return Invisibly returns `NULL`.
#'
#' @export
defineCustomCohort <- function(manifest,
                               label,
                               tags = list(),
                               cohortId = NULL,
                               sqlFilePath = NULL) {
  checkmate::assert_class(x = manifest, classes = "CohortManifest")
  checkmate::assert_string(x = label, min.chars = 1)
  checkmate::assert_list(x = tags, names = "named")

  has_id   <- !is.null(cohortId)
  has_path <- !is.null(sqlFilePath)

  if (has_id && has_path) {
    cli::cli_abort("Provide either `cohortId` or `sqlFilePath`, not both.")
  }
  if (!has_id && !has_path) {
    cli::cli_abort("One of `cohortId` or `sqlFilePath` must be provided.")
  }
  if (has_id) checkmate::assert_int(x = cohortId, lower = 1)
  if (has_path) checkmate::assert_string(x = sqlFilePath, min.chars = 1)

  cohort <- NULL

  if (has_id) {
    cohort <- manifest$getCohortById(as.integer(cohortId))
    if (is.null(cohort)) {
      cli::cli_abort("No cohort with ID {cohortId} found in the manifest.")
    }
  } else {
    norm_target <- normalizePath(sqlFilePath, mustWork = FALSE)
    for (cd in manifest$getManifest()) {
      norm_fp <- normalizePath(cd$getFilePath(), mustWork = FALSE)
      if (norm_fp == norm_target || fs::path_rel(cd$getFilePath()) == fs::path_rel(sqlFilePath)) {
        cohort <- cd
        break
      }
    }
    if (is.null(cohort)) {
      cli::cli_abort("No cohort with file path '{sqlFilePath}' found in the manifest.")
    }
  }

  cohort_id  <- cohort$getId()
  cohort_sql <- cohort$getSql()
  if (!is.null(cohort_sql) && nchar(cohort_sql) > 0) {
    .validateCustomSql(cohort_sql, label)
  }

  cohort$label <- label
  cohort$tags  <- tags
  cohort$setCohortType("custom")

  conn <- DBI::dbConnect(RSQLite::SQLite(), manifest$getDbPath())
  on.exit(DBI::dbDisconnect(conn))

  tags_str <- cohort$formatTagsAsString()

  DBI::dbExecute(
    conn,
    "UPDATE cohort_manifest SET label = ?, tags = ?, cohort_type = 'custom' WHERE id = ?",
    list(label, tags_str, cohort_id)
  )

  cli::cli_alert_success("Defined custom cohort {cohort_id}: {label}")
  if (length(tags) > 0) {
    cli::cli_alert_info("Tags: {tags_str}")
  }

  invisible(NULL)
}


#' Update the Label and/or Tags of an Existing Manifest Cohort
#'
#' @description
#' Updates `label`, `tags`, or both on any cohort present in the manifest.
#' Changes are applied to both the in-memory object and the SQLite database.
#'
#' @param manifest A `CohortManifest` object.
#' @param cohortId Integer. The ID of the cohort to update.
#' @param label Character or `NULL`. New label. If `NULL`, the existing label is kept.
#' @param tags Named list or `NULL`. New tags. If `NULL`, the existing tags are kept.
#'
#' @return Invisibly returns `NULL`.
#'
#' @export
updateCohortMetadata <- function(manifest,
                                 cohortId,
                                 label = NULL,
                                 tags = NULL) {
  checkmate::assert_class(x = manifest, classes = "CohortManifest")
  checkmate::assert_int(x = cohortId, lower = 1)

  if (is.null(label) && is.null(tags)) {
    cli::cli_abort("At least one of `label` or `tags` must be provided.")
  }
  if (!is.null(label)) checkmate::assert_string(x = label, min.chars = 1)
  if (!is.null(tags))  checkmate::assert_list(x = tags, names = "named")

  cohort <- manifest$getCohortById(as.integer(cohortId))
  if (is.null(cohort)) {
    cli::cli_abort("No cohort with ID {cohortId} found in the manifest.")
  }

  if (!is.null(label)) cohort$label <- label
  if (!is.null(tags))  cohort$tags  <- tags

  set_parts <- character(0)
  params    <- list()

  if (!is.null(label)) {
    set_parts <- c(set_parts, "label = ?")
    params    <- c(params, list(label))
  }

  if (!is.null(tags)) {
    tags_str  <- cohort$formatTagsAsString()
    set_parts <- c(set_parts, "tags = ?")
    params    <- c(params, list(tags_str))
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
  if (!is.null(tags))  changed <- c(changed, paste0("tags \u2192 ", cohort$formatTagsAsString()))

  cli::cli_alert_success("Updated cohort {cohortId}: {paste(changed, collapse = ', ')}")

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


#' Launch Interactive Concept Set Load Editor (Deprecated)
#'
#' @description
#' **Deprecated.** The interactive Shiny editor has been discontinued.
#' Use [createBlankConceptSetsLoadFile()] and edit the CSV directly.
#'
#' @param conceptSetsFolderPath Character. Path to conceptSets folder.
#'
#' @return NULL invisibly.
#'
#' @export
#' @keywords internal
#' @noRd
launchConceptSetsLoadEditor <- function(conceptSetsFolderPath = here::here("inputs/conceptSets")) {
  lifecycle::deprecate_soft(
    when = "3.0.0",
    what = "launchConceptSetsLoadEditor()",
    details = c(
      "The interactive Shiny editor has been discontinued.",
      i = "To create concept set metadata, use this workflow:",
      "  1. Run createBlankConceptSetsLoadFile() to create a template",
      "  2. Edit inputs/conceptSets/conceptSetsLoad.csv directly in Excel",
      "  3. Use conceptSetManifest$importAtlasConceptSets() to import"
    )
  )
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
