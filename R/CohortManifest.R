
#' CohortManifest R6 Class
#'
#' An R6 class that manages a collection of CohortDef objects and maintains
#' metadata in a SQLite database.
#'
#' @details
#' The CohortManifest class manages multiple cohort definitions and stores their
#' metadata in a SQLite database located at inputs/cohorts/cohortManifest.sqlite.
#' Each CohortDef is assigned a sequential ID based on its position in the manifest.
#'
#' @param dbPath Character. Path to the SQLite database file. Defaults to
#'   \code{"inputs/cohorts/cohortManifest.sqlite"}.
#'
#' @export
CohortManifest <- R6::R6Class(
  classname = "CohortManifest",
  private = list(
    .manifest = NULL,
    .dbPath = NULL,
    .executionSettings = NULL,
    .atlasConnection = NULL,

    # Initialize the SQLite database
    init_manifest = function(dbPath) {
      # Create inputs/cohorts directory if it doesn't exist
      dbDir <- dirname(dbPath)
      if (!dir.exists(dbDir)) {
        dir.create(dbDir, recursive = TRUE, showWarnings = FALSE)
      }

      # Check if database file already exists
      db_exists <- file.exists(dbPath)

      conn <- DBI::dbConnect(RSQLite::SQLite(), dbPath)
      on.exit(DBI::dbDisconnect(conn))

      if (!db_exists) {
        cli::cli_alert_info("Initializing manifest at {dbPath}.")
      }

      # Create cohort table with new schema
      DBI::dbExecute(
        conn,
        "CREATE TABLE IF NOT EXISTS cohort_manifest (
          id INTEGER PRIMARY KEY,
          label TEXT NOT NULL,
          category TEXT NOT NULL,
          tags TEXT,
          file_path TEXT NOT NULL,
          hash TEXT NOT NULL,
          source_type TEXT NOT NULL,
          cohort_type TEXT NOT NULL,
          depends_on TEXT,
          dependency_rule TEXT,
          status TEXT DEFAULT 'active',
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          deleted_at DATETIME DEFAULT NULL
        )"
      )

      # Create unique indexes scoped to active records
      DBI::dbExecute(
        conn,
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_label_active
          ON cohort_manifest(label) WHERE status = 'active'"
      )

      DBI::dbExecute(
        conn,
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_filepath_active
          ON cohort_manifest(file_path) WHERE status = 'active'"
      )

      # suppress message since it will always exist
      # if (db_exists) {
      #   cli::cli_alert_warning("Manifest already exists at {dbPath}.")
      # }
    },

    # Load manifest entries from SQLite into in-memory list of CohortDef objects
    load_manifest_from_db = function() {
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      rows <- DBI::dbGetQuery(
        conn,
        "SELECT id, label, category, tags, file_path, hash, source_type, cohort_type
         FROM cohort_manifest
         WHERE status = 'active'"
      )

      if (nrow(rows) == 0) {
        private$.manifest <- list()
        invisible(NULL)
      }

      manifest <- list()
      for (i in seq_len(nrow(rows))) {
        row <- rows[i, ]

        # Parse tags from JSON
        tags <- if (!is.na(row$tags) && nchar(row$tags) > 0) {
          tryCatch(
            jsonlite::fromJSON(row$tags, simplifyVector = FALSE),
            error = function(e) list()
          )
        } else {
          list()
        }

        # Only create CohortDef if file exists (skip missing files with a warning)
        if (!file.exists(row$file_path)) {
          cli::cli_alert_warning("Cohort {row$id} ({row$label}): file missing at {row$file_path}")
          next
        }

        cd <- CohortDef$new(
          label = row$label,
          category = row$category,
          sourceType = row$source_type,
          tags = tags,
          filePath = row$file_path
        )
        cd$setId(as.integer(row$id))
        cd$setCohortType(row$cohort_type)

        manifest[[length(manifest) + 1]] <- cd
      }

      private$.manifest <- manifest
    },

    # Detect missing cohort files and update status in database
    detect_missing_cohorts = function() {
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))
      
      # Get all active cohorts from database
      db_records <- tryCatch({
        DBI::dbGetQuery(
          conn,
          "SELECT id, label, file_path, status FROM cohort_manifest WHERE status = 'active'"
        )
      }, error = function(e) {
        return(data.frame())
      })
      
      if (nrow(db_records) == 0) {
        return(NULL)
      }
      
      missing_cohorts <- list()
      
      for (i in seq_len(nrow(db_records))) {
        record <- db_records[i, ]
        if (!file.exists(record$file_path)) {
          missing_cohorts[[length(missing_cohorts) + 1]] <- record
        }
      }
      
      return(missing_cohorts)
    },

    # Validate that execution settings have been set
    validateExecutionSettings = function() {
      if (is.null(private$.executionSettings)) {
        stop(
          "This operation requires ExecutionSettings. ",
          "Use setExecutionSettings() to add database configuration before proceeding."
        )
      }
    },

    # ========== PRIVATE HELPERS FOR ADD METHODS ==========

    # Validate that a label is unique among active entries
    validate_label_unique = function(label) {
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      existing <- DBI::dbGetQuery(
        conn,
        "SELECT id FROM cohort_manifest WHERE label = ? AND status = 'active'",
        list(label)
      )

      if (nrow(existing) > 0) {
        cli::cli_abort("Label '{label}' is already in use by cohort {existing$id[1]}")
      }
    },

    # Validate that a file_path is unique among active entries
    validate_filepath_unique = function(file_path) {
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      existing <- DBI::dbGetQuery(
        conn,
        "SELECT id FROM cohort_manifest WHERE file_path = ? AND status = 'active'",
        list(file_path)
      )

      if (nrow(existing) > 0) {
        cli::cli_abort("File path '{file_path}' is already registered to cohort {existing$id[1]}")
      }
    },

    # Validate that parent cohort IDs exist and are active
    validate_parent_cohorts_exist = function(cohortIds) {
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      ids_str <- paste(cohortIds, collapse = ", ")
      existing <- DBI::dbGetQuery(
        conn,
        paste0("SELECT id FROM cohort_manifest WHERE id IN (", ids_str, ") AND status = 'active'")
      )

      missing_ids <- setdiff(as.integer(cohortIds), existing$id)
      if (length(missing_ids) > 0) {
        cli::cli_abort("Parent cohort ID(s) not found in active manifest: {paste(missing_ids, collapse = ', ')}")
      }
    },

    # Insert a new cohort into SQLite and refresh in-memory manifest
    # Returns the assigned cohort ID
    insert_cohort = function(label, category, tags, file_path, source_type, cohort_type,
                             depends_on = NULL, dependency_rule = NULL) {
      # Validate cohort_type vs depends_on consistency
      derived_types <- c("subset", "union", "complement", "composite", "oprior", "tprior", "censor")
      has_depends <- !is.null(depends_on) && length(depends_on) > 0

      if (cohort_type %in% c("circe", "custom") && has_depends) {
        cli::cli_abort(c(
          "{.val {cohort_type}} cohorts must not have dependencies.",
          i = "{.field depends_on} should be {.val NULL} for {.val {cohort_type}} cohorts."
        ))
      }

      if (cohort_type %in% derived_types && !has_depends) {
        cli::cli_abort(c(
          "{.val {cohort_type}} cohorts require at least one parent cohort.",
          i = "Provide parent cohort IDs via the {.field depends_on} parameter."
        ))
      }

      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      # Get next available ID
      max_id_result <- DBI::dbGetQuery(conn, "SELECT MAX(id) as max_id FROM cohort_manifest")
      next_id <- if (is.na(max_id_result$max_id[1])) 1L else as.integer(max_id_result$max_id[1]) + 1L

      # Compute hash from file
      if (file.exists(file_path)) {
        file_content <- readr::read_file(file_path)
        hash <- rlang::hash(file_content)
      } else {
        hash <- rlang::hash(label)
      }

      # Serialize tags to JSON
      if (length(tags) > 0) {
        tags_json <- jsonlite::toJSON(tags, auto_unbox = TRUE)
      } else {
       tags_json <-  NA_character_
      }

      # Serialize depends_on to JSON array
      if (!is.null(depends_on) && length(depends_on) > 0) {
        depends_on_json <- jsonlite::toJSON(as.integer(depends_on), auto_unbox = FALSE)
      } else {
        depends_on_json <- NA_character_
      }

      # Serialize dependency_rule to JSON
      if (!is.null(dependency_rule) && length(dependency_rule) > 0) {
        dep_rule_json <- jsonlite::toJSON(dependency_rule, auto_unbox = TRUE)
      } else {
        dep_rule_json <- NA_character_
      }

      DBI::dbExecute(
        conn,
        "INSERT INTO cohort_manifest (id, label, category, tags, file_path, hash, source_type, cohort_type, depends_on, dependency_rule, status, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
        list(next_id, label, category, tags_json, file_path, hash, source_type, cohort_type, depends_on_json, dep_rule_json)
      )

      # Refresh in-memory manifest
      private$load_manifest_from_db()

      return(next_id)
    },


    # Cascade 'stale' status to all transitive downstream dependents of the
    # given cohort IDs. Delegates to the standalone cascadeStaleDownstream().
    cascade_stale_downstream = function(cohort_ids) {
      cascadeStaleDownstream(private$.dbPath, cohort_ids)
    },

    # Update metadata for an existing cohort
    # Modifies label, category, or tags for a cohort entry in the manifest.
    # The file path remains immutable.
    update_cohort_def = function(cohortId, label = NULL, category = NULL, tags = NULL) {
      checkmate::assert_int(cohortId)

      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      # Check that cohort exists and is active
      cohort_row <- DBI::dbGetQuery(
        conn,
        "SELECT * FROM cohort_manifest WHERE id = ? AND status = 'active'",
        list(cohortId)
      )

      if (nrow(cohort_row) == 0) {
        cli::cli_abort("Cohort {cohortId} not found or is deleted")
      }

      # Prepare update values
      updates <- list()
      params <- list()

      if (!is.null(label)) {
        checkmate::assert_string(label, min.chars = 1)
        # Check label uniqueness (excluding self)
        existing <- DBI::dbGetQuery(
          conn,
          "SELECT id FROM cohort_manifest WHERE label = ? AND id != ? AND status = 'active'",
          list(label, cohortId)
        )
        if (nrow(existing) > 0) {
          cli::cli_abort("Label '{label}' is already in use by cohort {existing$id[1]}")
        }
        updates[["label"]] <- label
        params[[length(params) + 1]] <- label
      }

      if (!is.null(category)) {
        checkmate::assert_string(category, min.chars = 1)
        updates[["category"]] <- category
        params[[length(params) + 1]] <- category
      }

      if (!is.null(tags)) {
        checkmate::assert_list(tags, names = "named")
        tags_json <- if (length(tags) > 0) {
          jsonlite::toJSON(tags, auto_unbox = TRUE)
        } else {
          NA_character_
        }
        updates[["tags"]] <- tags_json
        params[[length(params) + 1]] <- tags_json
      }

      if (length(updates) == 0) {
        cli::cli_alert_info("No fields provided to update")
        invisible(NULL)
      }

      # Build update query
      set_clause <- paste(names(updates), "= ?", collapse = ", ")
      params[[length(params) + 1]] <- cohortId

      DBI::dbExecute(
        conn,
        paste0("UPDATE cohort_manifest SET ", set_clause, ", updated_at = CURRENT_TIMESTAMP WHERE id = ?"),
        params
      )

      # Refresh in-memory manifest
      private$load_manifest_from_db()

      cli::cli_alert_success("Updated cohort {cohortId}")
      invisible(NULL)
    }
  ),

  public = list(
    #' @description Initialize a new CohortManifest
    #'
    #' @param dbPath Character. Path to the SQLite database. Defaults to
    #'   "inputs/cohorts/cohortManifest.sqlite"
    initialize = function(dbPath = "inputs/cohorts/cohortManifest.sqlite") {
      private$.dbPath <- dbPath
      private$.manifest <- list()

      # Initialize SQLite (creates schema if needed)
      private$init_manifest(dbPath)

      # Load existing entries from SQLite into memory
      private$load_manifest_from_db()
    },

    #' Get the manifest as a list of CohortDef objects
    #'
    #' @return List. A list of CohortDef objects in the manifest, indexed by cohort ID.
    getManifest = function() {
      return(private$.manifest)
    },

    #' Review dependent cohorts and their dependency metadata
    #'
    #' @description
    #' Returns a summary tibble of all active derived cohorts (union, subset, complement,
    #' composite, oprior, tprior, censor) with parsed dependency information sourced
    #' directly from SQLite. Useful for quickly auditing what each derived cohort depends
    #' on and how it was built.
    #'
    #' @return A tibble with columns:
    #'   \itemize{
    #'     \item \code{id} - Cohort ID
    #'     \item \code{label} - Cohort label
    #'     \item \code{cohort_type} - One of 'union', 'subset', 'complement', 'composite',
    #'       'oprior', 'tprior', 'censor'
    #'     \item \code{category} - User-defined category
    #'     \item \code{parent_cohorts} - Human-readable parent list, e.g. "Label A (1), Label B (2)"
    #'     \item \code{rule_summary} - Compact summary of the dependency rule parameters
    #'     \item \code{created_at} - Timestamp of creation
    #'   }
    reviewDependentCohorts = function() {
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      # All active derived cohorts
      derived <- DBI::dbGetQuery(
        conn,
        "SELECT id, label, cohort_type, category, depends_on, dependency_rule, created_at
         FROM cohort_manifest
         WHERE status = 'active'
           AND cohort_type NOT IN ('circe', 'custom')
         ORDER BY id"
      )

      if (nrow(derived) == 0) {
        cli::cli_alert_info("No derived cohorts found in manifest.")
        return(tibble::tibble(
          id = integer(), label = character(), cohort_type = character(),
          category = character(), parent_cohorts = character(),
          rule_summary = character(), created_at = character()
        ))
      }

      # Build id -> label lookup
      all_labels <- DBI::dbGetQuery(conn, "SELECT id, label FROM cohort_manifest WHERE status = 'active'")
      label_map <- stats::setNames(all_labels$label, as.character(all_labels$id))

      # Helper: parse depends_on JSON -> "Label (id), ..."
      parse_parents <- function(depends_on_json) {
        if (is.na(depends_on_json) || nchar(depends_on_json) == 0) {
          return("None")
        }
        ids <- tryCatch(as.integer(jsonlite::fromJSON(depends_on_json)), error = function(e) integer(0))
        if (length(ids) == 0) {
          return("None")
        }
        parts <- sapply(ids, function(i) {
          lbl <- label_map[[as.character(i)]]
          if (is.null(lbl) || is.na(lbl)) paste0("(unknown: ", i, ")") else paste0(lbl, " (", i, ")")
        })
        paste(parts, collapse = ", ")
      }

      # Helper: parse dependency_rule JSON -> compact type-specific string
      parse_rule <- function(cohort_type, rule_json) {
        if (is.na(rule_json) || nchar(rule_json) == 0) {
          return("")
        }
        rule <- tryCatch(jsonlite::fromJSON(rule_json, simplifyVector = TRUE), error = function(e) list())
        if (length(rule) == 0) {
          return("")
        }
        switch(
          cohort_type,
          union = paste0("gapDays: ", rule$gapDays %||% 0),
          subset = paste(
            c(
              if (!is.null(rule$baseCohortId))   paste0("base: ",    label_map[[as.character(rule$baseCohortId)]]   %||% rule$baseCohortId),
              if (!is.null(rule$filterCohortId)) paste0("filter: ",  label_map[[as.character(rule$filterCohortId)]] %||% rule$filterCohortId),
              if (!is.null(rule$subsetLimit))    paste0("limit: ",   rule$subsetLimit),
              if (!is.null(rule$endDateType))    paste0("endDate: ", rule$endDateType)
            ),
            collapse = " | "
          ),
          complement = paste(
            c(
              if (!is.null(rule$baseCohortId))        paste0("base: ",       label_map[[as.character(rule$baseCohortId)]]        %||% rule$baseCohortId),
              if (!is.null(rule$populationCohortId))  paste0("population: ", label_map[[as.character(rule$populationCohortId)]]  %||% rule$populationCohortId)
            ),
            collapse = " | "
          ),
          composite = {
            n_ids <- if (!is.null(rule$cohortIds)) length(rule$cohortIds) else 0L
            paste0("minCohorts: ", rule$minCohorts %||% n_ids, " of ", n_ids)
          },
          oprior = paste(
            c(
              if (!is.null(rule$outcomeCohortId)) paste0("outcome: ", label_map[[as.character(rule$outcomeCohortId)]] %||% rule$outcomeCohortId),
              if (!is.null(rule$targetCohortId))  paste0("target: ",  label_map[[as.character(rule$targetCohortId)]]  %||% rule$targetCohortId),
              if (!is.null(rule$mode))            paste0("mode: ",    rule$mode),
              if (!is.null(rule$subsetLimit))     paste0("limit: ",   rule$subsetLimit),
              if (!is.null(rule$priorTimeWindowDays)) paste0("window: ", rule$priorTimeWindowDays, "d")
            ),
            collapse = " | "
          ),
          tprior = paste(
            c(
              if (!is.null(rule$targetCohortId))  paste0("target: ",  label_map[[as.character(rule$targetCohortId)]]  %||% rule$targetCohortId),
              if (!is.null(rule$outcomeCohortId)) paste0("outcome: ", label_map[[as.character(rule$outcomeCohortId)]] %||% rule$outcomeCohortId),
              if (!is.null(rule$mode))            paste0("mode: ",    rule$mode),
              if (!is.null(rule$subsetLimit))     paste0("limit: ",   rule$subsetLimit),
              if (!is.null(rule$priorTimeWindowDays)) paste0("window: ", rule$priorTimeWindowDays, "d")
            ),
            collapse = " | "
          ),
          censor = paste(
            c(
              if (!is.null(rule$targetCohortId))  paste0("target: ",  label_map[[as.character(rule$targetCohortId)]]  %||% rule$targetCohortId),
              if (!is.null(rule$censorCohortId))  paste0("censor: ",  label_map[[as.character(rule$censorCohortId)]]  %||% rule$censorCohortId)
            ),
            collapse = " | "
          ),
          ""
        )
      }

      result <- tibble::tibble(
        id           = derived$id,
        label        = derived$label,
        cohort_type  = derived$cohort_type,
        category     = derived$category,
        parent_cohorts = mapply(parse_parents, derived$depends_on, USE.NAMES = FALSE),
        rule_summary   = mapply(parse_rule, derived$cohort_type, derived$dependency_rule, USE.NAMES = FALSE),
        created_at   = derived$created_at
      )

      return(result)
    },

    #' @description Tabulate the manifest as a tibble
    #'
    #' @param filter Character. Controls which rows are returned. One of
    #'   \code{"active"} (default), \code{"deleted"}, or \code{"all"}.
    #'
    #' @return A tibble with columns: id, label, category, tags, file_path, hash,
    #'   source_type, cohort_type, status, created_at, deleted_at
    tabulateManifest = function(filter = c("active", "deleted", "stale", "all")) {
      filter <- match.arg(filter)

      where_clause <- switch(
        filter,
        active  = "WHERE status = 'active'",
        deleted = "WHERE status IN ('deleted', 'purged')",
        stale   = "WHERE status = 'stale'",
        all     = ""
      )

      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      sql <- paste(
        "SELECT id, label, category, tags, file_path, hash, source_type, cohort_type, status, created_at, deleted_at",
        "FROM cohort_manifest",
        where_clause,
        "ORDER BY id"
      )

      man <- DBI::dbGetQuery(conn, sql) |>
        tibble::as_tibble()
      return(man)
    },

    #' Review stale derived cohorts
    #'
    #' @description
    #' Returns a summary of all cohorts currently marked \code{'stale'} — meaning a parent
    #' cohort's SQL file has changed since the derived cohort was last executed. Stale cohorts
    #' are still valid SQL; they just need to be re-executed. \code{executeCohortGeneration()}
    #' will run them automatically regardless of checksum state.
    #'
    #' Use \code{resetCohortManifest(scope = "derived")} followed by re-running your build
    #' script if you need to change build parameters rather than just re-execute.
    #'
    #' @return A tibble with columns: id, label, cohort_type, category, depends_on, updated_at.
    #'   Returns \code{NULL} invisibly if no stale cohorts exist.
    reviewStaleCohorts = function() {
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      rows <- DBI::dbGetQuery(
        conn,
        "SELECT id, label, cohort_type, category, depends_on, updated_at
         FROM cohort_manifest
         WHERE status = 'stale'
         ORDER BY id"
      )

      if (nrow(rows) == 0) {
        cli::cli_alert_success("No stale cohorts found.")
        return(invisible(NULL))
      }

      cli::cli_rule("Stale Cohorts ({nrow(rows)} total)")
      cli::cli_alert_info(
        "These cohorts have a parent whose SQL file changed. They will be re-executed automatically by {.code executeCohortGeneration()}."
      )
      cli::cli_alert_info(
        "To change build parameters, run {.code resetCohortManifest(scope = 'derived')} and rebuild."
      )

      result <- tibble::tibble(
        id          = rows$id,
        label       = rows$label,
        cohort_type = rows$cohort_type,
        category    = rows$category,
        depends_on  = rows$depends_on,
        updated_at  = rows$updated_at
      )

      print(result)
      invisible(result)
    },

    #' Reload the in-memory manifest from the SQLite database
    #'
    #' @description
    #' Re-reads all active cohort records from SQLite and rebuilds the in-memory
    #' list of CohortDef objects. Useful after external changes to the database
    #' (e.g., after \code{resetCohortManifest(scope = "derived")}).
    #'
    #' @return Invisible self.
    reloadFromDb = function() {
      private$load_manifest_from_db()
      invisible(self)
    },

    #' Get the manifest path
    #'
    #' @return Character. The path to the SQLite database.
    getDbPath = function() {
      private$.dbPath
    },

    #' Get the execution settings
    #'
    #' @return Object. The execution settings object for DBMS cohort generation, or NULL if not set.
    getExecutionSettings = function() {
      private$.executionSettings
    },

    #' Set the execution settings
    #'
    #' @param executionSettings Object. Execution settings for DBMS cohort generation.
    setExecutionSettings = function(executionSettings) {
      private$.executionSettings <- executionSettings
    },

    #' Get the stored ATLAS connection
    #'
    #' @return The ATLAS connection object, or NULL if not set.
    getAtlasConnection = function() {
      private$.atlasConnection
    },

    #' Set an ATLAS connection for use by add/import methods
    #'
    #' Stores a connection so it does not need to be passed to
    #' `addAtlasCohort()` or `importAtlasCohorts()` on every call.
    #'
    #' @param atlasConnection An ATLAS connection object (from `getAtlasConnection()`).
    #'
    #' @return Invisible self for method chaining.
    setAtlasConnection = function(atlasConnection) {
      private$.atlasConnection <- atlasConnection
      invisible(self)
    },

    # ========== ADD METHODS ==========

    #' @description Add a single cohort from ATLAS
    #'
    #' Fetches a cohort JSON from ATLAS, saves it to `json/`, and registers
    #' the cohort in the manifest.
    #'
    #' @param atlasId Integer. The ATLAS cohort definition ID.
    #' @param label Character. Display name for the cohort.
    #' @param category Character. Required classification (e.g., 'target', 'outcome').
    #' @param tags Named list. Optional metadata tags.
    #' @param atlasConnection An ATLAS connection object (e.g., from ROhdsiWebApi::createConnectionDetails)
    #'   with a method `getCohortDefinition(cohortId)` that returns a list with an `expression` element.
    #'   If `NULL`, falls back to the connection stored via `$setAtlasConnection()`.
    #'
    #' @return Invisible integer. The assigned cohort ID.
    addAtlasCohort = function(atlasId, label, category, tags = list(), atlasConnection = NULL) {
      if (is.null(atlasConnection)) {
        atlasConnection <- private$.atlasConnection
      }

      if (is.null(atlasConnection)) {
        cli::cli_abort(c(
          "No ATLAS connection available.",
          i = "Supply {.arg atlasConnection} or call {.code $setAtlasConnection()} first."
        ))
      }

      checkmate::assert_int(atlasId)
      checkmate::assert_string(label, min.chars = 1)
      checkmate::assert_string(category, min.chars = 1)
      checkmate::assert_list(tags, names = "named")

      # Validate label uniqueness
      private$validate_label_unique(label)

      # Fetch cohort JSON from ATLAS via connection object
      tryCatch({
        cohort_def <- atlasConnection$getCohortDefinition(cohortId = atlasId)
        expression_json <- cohort_def$expression[1]
      }, error = function(e) {
        cli::cli_abort("Failed to fetch cohort {atlasId} from ATLAS: {e$message}")
      })

      # Save JSON to json/ directory
      cohorts_dir <- dirname(private$.dbPath)
      json_dir <- fs::path(cohorts_dir, "json")

      if (!dir.exists(json_dir)) {
        dir.create(json_dir, recursive = TRUE)
      } 

      # extract cohort name from definition to use as file name (fallback to label if not available)
      cohort_name <- ifelse(!is.null(cohort_def$saveName[1]) && cohort_def$saveName[1] != "", cohort_def$saveName[1], label)
      json_path <- fs::path(json_dir, paste0(cohort_name, ".json"))
      readr::write_lines(expression_json, json_path) # make line ending always \\n

      # Tag the route for provenance
      tags$route <- "atlas"
      tags$atlasId <- as.integer(atlasId) # add the atlas id as a tag

      # Register in manifest
      cohort_id <- private$insert_cohort(
        label = label,
        category = category,
        tags = tags,
        file_path = fs::path_rel(json_path),
        source_type = "circe",
        cohort_type = "circe"
      )

      cli::cli_alert_success("Added ATLAS cohort {cohort_id}: {label}")
      invisible(cohort_id)
    },

    #' @description Batch import cohorts from ATLAS via cohortsLoad.csv
    #'
    #' Reads a CSV file with columns `atlasId`, `label`, `category`
    #' (plus optional extra columns for tags) and imports each cohort from ATLAS.
    #'
    #' @param cohortsLoad a data frame requiring the columns atlasId, label and category used to bulk add cohorts to the manifest
    #' @param atlasConnection An ATLAS connection object with a `getCohortDefinition(cohortId)` method.
    #'   If `NULL`, falls back to the connection stored via `$setAtlasConnection()`.
    #'
    #' @return Invisible tibble of imported cohorts.
    importAtlasCohorts = function(cohortsLoad, atlasConnection = NULL) {
      if (is.null(atlasConnection)) {
        atlasConnection <- private$.atlasConnection
      }

      if (is.null(atlasConnection)) {
        cli::cli_abort(c(
          "No ATLAS connection available.",
          i = "Supply {.arg atlasConnection} or call {.code $setAtlasConnection()} first."
        ))
      }

         
      # Validate required columns
      required_cols <- c("atlasId", "label", "category")
      checkmate::assert_data_frame(cohortsLoad, min.cols = 3) 
      missing_cols <- setdiff(required_cols, names(cohortsLoad))
      if (length(missing_cols) > 0) {
        cli::cli_abort("cohortsLoad.csv missing required columns: {paste(missing_cols, collapse = ', ')}")
      }

      # Determine which cohorts are new and need to be loaded
      cm_atlas_subset <- self$queryCohortsByTagName(tagName = "atlasId")
      cohort_load_2 <- check_which_cohorts_exist(cm_atlas_subset, cohortsLoad)

      # Header
      cli::cli_rule("ATLAS Cohort Import")
      cli::cli_alert_info("Evaluating {nrow(cohortsLoad)} cohort(s) from load file")

      # Subset New Cohorts 
      new_cohorts <- cohort_load_2 |>
        dplyr::filter(status == "new")

      existing_cohorts <- cohort_load_2 |>
        dplyr::filter(status == "active")


      # Process new cohorts
      if(nrow(new_cohorts) > 0) {
        cli::cli_rule("Adding {nrow(new_cohorts)} new cohort(s)")
        for (i in seq_len(nrow(new_cohorts))) {
          row <- new_cohorts[i, ]
          additional_tags <- list_tags_in_row(row)
          # Delegate to addAtlasCohort for actual manifest insertion
              cohort_id <- self$addAtlasCohort(
                atlasId = row$atlasId,
                label = row$label,
                category = row$category,
                tags = additional_tags,
                atlasConnection = atlasConnection
              )
        }
      }

      # Process existing cohorts
      if (nrow(existing_cohorts) > 0) {
        cli::cli_rule("Existing cohort(s) in manifest ({nrow(existing_cohorts)})")
        for (i in seq_len(nrow(existing_cohorts))) {
          row <- existing_cohorts[i, ]
          cli::cli_alert_warning("  ID {row$id}: {row$label} (atlasId: {row$atlasId})")
        }
        
        cli::cli_alert_info("To check for ATLAS changes, run: {.code manifest$checkAtlasCohorts(atlasConnection)}")
        cli::cli_alert_info("To update ATLAS definitions, run: {.code manifest$updateAtlasCohorts(atlasConnection)}")
      }

      # Build and print final summary table
      summary_tbl <- cohort_load_2 |>
        dplyr::mutate(
          message = dplyr::case_when(
            status == "new" ~ "Successfully added to manifest",
            status == "active" ~ "Already in manifest",
            TRUE ~ "Unknown"
          )
        ) |>
        dplyr::select(dplyr::any_of(c("id", "label", "atlasId", "status", "message")))

      cli::cli_rule("Import Summary ({nrow(summary_tbl)} cohort(s) total)")
      print(summary_tbl)

      invisible(cohort_load_2)
    },

    #' @description Add a Capr cohort
    #'
    #' Takes a Capr Cohort object, exports it to JSON in `json/`, and registers
    #' the cohort in the manifest.
    #'
    #' @param caprCohort A Capr Cohort object (inherits from "Cohort").
    #' @param label Character. Display name for the cohort.
    #' @param category Character. Required classification.
    #' @param tags Named list. Optional metadata tags.
    #'
    #' @return Invisible integer. The assigned cohort ID.
    addCaprCohort = function(caprCohort, label, category, tags = list()) {
      if (!requireNamespace("Capr", quietly = TRUE)) {
        cli::cli_abort(c(
          "Package {.pkg Capr} is required for addCaprCohort().",
          "i" = "Install with: {.code remotes::install_github('ohdsi/Capr')}"
        )
        )
      }

      if (!inherits(caprCohort, "Cohort")) {
        cli::cli_abort("caprCohort must be a Capr Cohort object (inherits from 'Cohort')")
      }

      checkmate::assert_string(label, min.chars = 1)
      checkmate::assert_string(category, min.chars = 1)
      checkmate::assert_list(tags, names = "named")

      # Validate label uniqueness
      private$validate_label_unique(label)

      # Export Capr cohort to JSON
      cohorts_dir <- dirname(private$.dbPath)
      json_dir <- fs::path(cohorts_dir, "json")
      if (!dir.exists(json_dir)) dir.create(json_dir, recursive = TRUE)

      safe_label <- gsub("[^a-zA-Z0-9_-]", "_", label)
      json_path <- fs::path(json_dir, paste0(safe_label, ".json"))

      Capr::writeCohort(caprCohort, json_path)

      # Tag the route for provenance
      tags$route <- "capr"

      # Register in manifest
      cohort_id <- private$insert_cohort(
        label = label,
        category = category,
        tags = tags,
        file_path = fs::path_rel(json_path),
        source_type = "circe",
        cohort_type = "circe"
      )

      cli::cli_alert_success("Added Capr cohort {cohort_id}: {label}")
      invisible(cohort_id)
    },

    #' @description Add a custom SQL cohort
    #'
    #' Registers an existing SQL file in the manifest. The file must already exist
    #' on disk (typically in `sql/`).
    #'
    #' @param filePath Character. Path to the SQL file.
    #' @param label Character. Display name for the cohort.
    #' @param category Character. Required classification.
    #' @param tags Named list. Optional metadata tags.
    #' @param stopIfExists Logical. If TRUE (default), raises an error if the file
    #'   already exists on disk or is already registered in the manifest. If FALSE,
    #'   overwrites silently with a warning. Default: TRUE (fail-safe).
    #'
    #' @return Invisible integer. The assigned cohort ID.
    addSqlCohort = function(filePath, label, category, tags = list(), stopIfExists = TRUE) {
      checkmate::assert_file_exists(filePath)
      checkmate::assert_string(label, min.chars = 1)
      checkmate::assert_string(category, min.chars = 1)
      checkmate::assert_list(tags, names = "named")
      checkmate::assert_flag(stopIfExists)

      # Validate file is SQL
      ext <- tolower(tools::file_ext(filePath))
      if (ext != "sql") {
        cli::cli_abort("filePath must be a .sql file, got: .{ext}")
      }

      # Validate label uniqueness
      private$validate_label_unique(label)

      # Check file path: query manifest to see if already registered
      rel_path <- fs::path_rel(filePath)
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      existing_cohort <- DBI::dbGetQuery(
        conn,
        "SELECT id FROM cohort_manifest WHERE file_path = ? AND status = 'active'",
        list(rel_path)
      )

      if (nrow(existing_cohort) > 0) {
        if (isTRUE(stopIfExists)) {
          cli::cli_abort(c(
            "File path already registered in manifest (cohort {existing_cohort$id[1]})",
            i = "Set {.arg stopIfExists = FALSE} to replace registration"
          ))
        } else {
          cli::cli_warn("Replacing existing manifest entry for {.file {rel_path}}")
        }
      }

      # Run portability validation
      sql_content <- readr::read_file(filePath)
      .validateCustomSql(sql_content, label)

      # Register in manifest
      cohort_id <- private$insert_cohort(
        label = label,
        category = category,
        tags = tags,
        file_path = rel_path,
        source_type = "sql",
        cohort_type = "custom"
      )

      cli::cli_alert_success("Added SQL cohort {cohort_id}: {label}")
      invisible(cohort_id)
    },

    #' @description Add a Circe JSON cohort from disk
    #'
    #' Registers an existing Circe-compatible JSON file in the manifest.
    #' The file must already exist on disk (typically in `json/`).
    #' Validates that the JSON is valid Circe format using CirceR.
    #'
    #' @param filePath Character. Path to the Circe JSON file.
    #' @param label Character. Display name for the cohort.
    #' @param category Character. Required classification.
    #' @param tags Named list. Optional metadata tags.
    #'
    #' @return Invisible integer. The assigned cohort ID.
    addCirceCohort = function(filePath, label, category, tags = list()) {
      checkmate::assert_file_exists(filePath)
      checkmate::assert_string(label, min.chars = 1)
      checkmate::assert_string(category, min.chars = 1)
      checkmate::assert_list(tags, names = "named")

      # Validate file is JSON
      ext <- tolower(tools::file_ext(filePath))
      if (ext != "json") {
        cli::cli_abort("filePath must be a .json file, got: .{ext}")
      }

      # Validate label uniqueness
      private$validate_label_unique(label)

      # Validate file_path uniqueness
      rel_path <- fs::path_rel(filePath)
      private$validate_filepath_unique(rel_path)

      # Validate CIRCE compatibility
      json_content <- readr::read_file(filePath)
      tryCatch(
        CirceR::cohortExpressionFromJson(json_content),
        error = function(e) {
          cli::cli_abort(
            "JSON file is not valid CIRCE format: {filePath}{n}Error: {e$message}"
          )
        }
      )

      # Tag the route for provenance
      tags$route <- "manual"

      # Register in manifest
      cohort_id <- private$insert_cohort(
        label = label,
        category = category,
        tags = tags,
        file_path = rel_path,
        source_type = "circe",
        cohort_type = "circe"
      )

      cli::cli_alert_success("Added Circe cohort {cohort_id}: {label}")
      invisible(cohort_id)
    },

    #' @description Build a union cohort from existing cohorts
    #'
    #' Creates a derived cohort that is the union of specified parent cohorts.
    #' Delegates SQL generation to the internal builder function.
    #'
    #' @param label Character. Display name for the derived cohort.
    #' @param category Character. Required classification.
    #' @param tags Named list. Optional metadata tags.
    #' @param cohortIds Numeric vector (minimum 2). Cohort IDs to union.
    #' @param gapDays Integer. Bridge eras separated by up to this many days. Default: 0 (only
    #'   overlapping periods collapse).
    #' @param eraPadDays Integer. Expand each source period by this many days on each end before
    #'   collapsing. Applied to individual periods, not the collapsed result. Default: 0.
    #' @param minEraDays Integer. Drop collapsed eras shorter than this many days. Default: 0
    #'   (keep all eras).
    #' @param minCohorts Integer. Only include subjects appearing in at least this many distinct
    #'   source cohorts. Default: 1 (any subject from any cohort).
    #' @param washoutDays Integer. Require a clean period of at least this many days before a
    #'   new era can open. Subjects must have no source cohort membership for this period.
    #'   Default: 0.
    #' @param firstEraOnly Logical. Return only the first collapsed era per subject. Default: FALSE.
    #' @return Invisible integer. The assigned cohort ID.
    buildUnionCohort = function(
      label, 
      category, 
      tags = list(),
      cohortIds,
      gapDays = 0L,
      eraPadDays = 0L,
      minEraDays = 0L,
      minCohorts = 1L,
      washoutDays = 0L,
      firstEraOnly = FALSE
      ) {
      checkmate::assert_string(label, min.chars = 1)
      checkmate::assert_integerish(cohortIds, min.len = 2, unique = TRUE)
      checkmate::assert_string(category, min.chars = 1)
      checkmate::assert_list(tags, names = "named")
      checkmate::assert_integerish(x = gapDays, len = 1, lower = 0)
      checkmate::assert_integerish(x = eraPadDays, len = 1, lower = 0)
      checkmate::assert_integerish(x = minEraDays, len = 1, lower = 0)
      checkmate::assert_integerish(x = minCohorts, len = 1, lower = 1)
      checkmate::assert_integerish(x = washoutDays, len = 1, lower = 0)
      checkmate::assert_logical(x = firstEraOnly, len = 1)

      private$validate_label_unique(label)
      private$validate_parent_cohorts_exist(cohortIds)

      # Build dependency rule
      dependency_rule <- list(
        cohortIds = as.integer(cohortIds), 
        gapDays = gapDays,
        eraPadDays = eraPadDays,
        minEraDays = minEraDays,
        minCohorts = minCohorts,
        washoutDays = washoutDays,
        firstEraOnly = firstEraOnly
        )

      # Generate SQL via internal builder
      derived_dir <- make_derived_folder(dirname(private$.dbPath))
      sql_path <- write_derived_template(derived_dir, label, "createUnionCohort.sql",
        cohort_ids = paste(cohortIds, collapse = ", "),
        gap_days = gapDays,
        era_pad_days = eraPadDays,
        min_era_days = minEraDays,
        min_cohorts = minCohorts,
        washout_days = washoutDays,
        use_washout_days = ifelse(washoutDays > 0, TRUE, FALSE),
        first_era_only = firstEraOnly
      )

      # Register in manifest
      cohort_id <- private$insert_cohort(
        label = label,
        category = category,
        tags = tags,
        file_path = fs::path_rel(sql_path),
        source_type = "derived",
        cohort_type = "union",
        depends_on = as.integer(cohortIds),
        dependency_rule = dependency_rule
      )

      cli::cli_alert_success("Built union cohort {cohort_id}: {label} (depends on: {paste(cohortIds, collapse = ', ')})")
      invisible(cohort_id)
    },

    #' @description Build a subset cohort with temporal criteria
    #'
    #' Creates a derived cohort that subsets a base cohort using temporal
    #' relationship to a filter cohort.
    #'
    #' @param label Character. Display name.
    #' @param category Character. Required classification.
    #' @param tags Named list. Optional metadata tags.
    #' @param baseCohortId Integer. The cohort ID to subset.
    #' @param filterCohortId Integer. The cohort ID to use for temporal filtering.
    #' @param startWindow SubsetWindowOperator object. Defines the temporal window for the subset cohort start date
    #'   relative to the filter cohort event.
    #' @param endWindow SubsetWindowOperator object (optional, NULL allowed). Defines the temporal window for the 
    #'   subset cohort end date relative to the filter cohort event. If NULL, the filter cohort end date is not used.
    #' @param endDateType Character. Whether to use the base cohort end date ('base') or filter cohort end date ('filter')
    #'   as the cohort end date in the output subset cohort. Default: 'base'.
    #' @param subsetLimit Character. One of 'First', 'Last', or 'All'. Specifies which qualifying filter cohort event(s)
    #'   to retain per subject. 'First' keeps the earliest event, 'Last' keeps the most recent event, 'All' keeps all 
    #'   qualifying events. Default: 'First'.
    #'
    #' @return Invisible integer. The assigned cohort ID.
    buildSubsetCohortTemporal = function(
      label, 
      category,
      tags = list(),
      baseCohortId, 
      filterCohortId, 
      startWindow,
      endWindow = NULL,
      endDateType = "base",
      subsetLimit = "First"
    ) {
      checkmate::assert_string(label, min.chars = 1)
      checkmate::assert_int(baseCohortId)
      checkmate::assert_int(filterCohortId)
      checkmate::assert_string(category, min.chars = 1)
      checkmate::assert_class(startWindow, classes = "SubsetWindowOperator")
      checkmate::assert_class(endWindow, classes = "SubsetWindowOperator", null.ok = TRUE)
      checkmate::assert_choice(endDateType, choices = c("base", "filter"))
      checkmate::assert_choice(subsetLimit, choices = c("First", "Last", "All"))
      checkmate::assert_list(tags, names = "named")

      private$validate_label_unique(label)
      private$validate_parent_cohorts_exist(c(baseCohortId, filterCohortId))

      # Generate SQL snippets from SubsetWindowOperator objects
      start_window_sql <- startWindow$makeSubsetWindowSql()
      end_window_sql <- if (is.null(endWindow)) "" else endWindow$makeSubsetWindowSql()

      # Build dependency rule capturing full window parameters
      dependency_rule <- list(
        baseCohortId = as.integer(baseCohortId),
        filterCohortId = as.integer(filterCohortId),
        startWindow = list(
          subsetCohortWindowAnchor = startWindow$subsetCohortWindowAnchor,
          startDays = startWindow$startDays,
          endDays = startWindow$endDays,
          baseCohortWindowAnchor = startWindow$baseCohortWindowAnchor
        ),
        endWindow = if (is.null(endWindow)) NULL else list(
          subsetCohortWindowAnchor = endWindow$subsetCohortWindowAnchor,
          startDays = endWindow$startDays,
          endDays = endWindow$endDays,
          baseCohortWindowAnchor = endWindow$baseCohortWindowAnchor
        ),
        endDateType = endDateType,
        subsetLimit = subsetLimit
      )

      # Generate SQL from template
      derived_dir <- make_derived_folder(dirname(private$.dbPath))
      sql_path <- write_derived_template(derived_dir, label, "createSubsetCohort_Cohort.sql",
        base_cohort_id = baseCohortId,
        filter_cohort_id = filterCohortId,
        start_window = start_window_sql,
        end_window = end_window_sql,
        subset_limit = subsetLimit,
        end_date_type = endDateType
      )

      parent_ids <- unique(c(baseCohortId, filterCohortId))

      cohort_id <- private$insert_cohort(
        label = label,
        category = category,
        tags = tags,
        file_path = fs::path_rel(sql_path),
        source_type = "derived",
        cohort_type = "subset",
        depends_on = as.integer(parent_ids),
        dependency_rule = dependency_rule
      )

      cli::cli_alert_success("Built subset cohort {cohort_id}: {label}")
      invisible(cohort_id)
    },

    #' @description Build a complement cohort
    #'
    #' Creates a derived cohort containing all subjects from the population cohort who
    #' do NOT appear in any (or all) of the exclude cohorts.
    #'
    #' @param label Character. Display name.
    #' @param populationCohortId Integer. ID of the population (base) cohort.
    #' @param excludeCohortIds Integer vector (min length 1). IDs of cohorts whose
    #'   subjects should be excluded from the population.
    #' @param category Character. Required classification.
    #' @param complementType Character. One of \code{"exclude_any"} (default) or
    #'   \code{"exclude_all"}. \code{"exclude_any"} removes subjects present in ANY
    #'   exclude cohort; \code{"exclude_all"} removes subjects only if they appear
    #'   in ALL exclude cohorts.
    #' @param tags Named list. Optional metadata tags.
    #'
    #' @return Invisible integer. The assigned cohort ID.
    buildComplementCohort = function(
      label, 
      category, 
      tags = list(),
      populationCohortId, 
      excludeCohortIds,
      complementType = "exclude_any"
    ) {
      checkmate::assert_string(label, min.chars = 1)
      checkmate::assert_int(populationCohortId)
      checkmate::assert_integerish(excludeCohortIds, min.len = 1, unique = TRUE)
      checkmate::assert_string(category, min.chars = 1)
      checkmate::assert_choice(complementType, choices = c("exclude_any", "exclude_all"))
      checkmate::assert_list(tags, names = "named")

      if (populationCohortId %in% excludeCohortIds) {
        cli::cli_abort("populationCohortId {populationCohortId} cannot also appear in excludeCohortIds")
      }

      private$validate_label_unique(label)
      private$validate_parent_cohorts_exist(c(populationCohortId, as.integer(excludeCohortIds)))

      dependency_rule <- list(
        populationCohortId = as.integer(populationCohortId),
        excludeCohortIds = as.integer(excludeCohortIds),
        complementType = complementType
      )

      derived_dir <- make_derived_folder(dirname(private$.dbPath))
      sql_path <- write_derived_template(derived_dir, label, "createComplementCohort.sql",
        population_cohort_id = populationCohortId,
        exclude_cohort_ids = paste(as.integer(excludeCohortIds), collapse = ", "),
        exclude_cohort_ids_count = length(excludeCohortIds),
        complement_type = complementType
      )

      parent_ids <- unique(c(as.integer(populationCohortId), as.integer(excludeCohortIds)))

      cohort_id <- private$insert_cohort(
        label = label,
        category = category,
        tags = tags,
        file_path = fs::path_rel(sql_path),
        source_type = "derived",
        cohort_type = "complement",
        depends_on = parent_ids,
        dependency_rule = dependency_rule
      )

      cli::cli_alert_success("Built complement cohort {cohort_id}: {label}")
      invisible(cohort_id)
    },

    #' @description Build a custom dependent cohort from a user-supplied SQL file
    #'
    #' Registers an existing `.sql` file as a derived cohort with explicit
    #' dependencies on manifest cohorts. Unlike `addSqlCohort()` (which treats
    #' the file as a base cohort), this method copies the SQL into the
    #' `derived/` directory and sets `depends_on`, so the skip-logic
    #' uses dependency-aware hashing (see Phase 1.1).
    #'
    #' @param filePath Character. Path to the user's `.sql` file.
    #'   The file is **copied** into the `derived/` directory — the original
    #'   is not referenced after registration.
    #' @param label Character. Display name (must be unique in manifest).
    #' @param category Character. Required classification.
    #' @param cohortIds Integer vector (min. 1). Parent cohort IDs this SQL
    #'   depends on. All must exist in the manifest.
    #' @param tags Named list. Optional metadata tags.
    #'
    #' @return Invisible integer. The assigned cohort ID.
    buildCustomDependentCohort = function(filePath, label, category, cohortIds, tags = list()) {
      checkmate::assert_file_exists(filePath)
      checkmate::assert_string(label, min.chars = 1)
      checkmate::assert_string(category, min.chars = 1)
      checkmate::assert_integerish(cohortIds, min.len = 1, unique = TRUE)
      checkmate::assert_list(tags, names = "named")

      # Validate file is SQL
      ext <- tolower(tools::file_ext(filePath))
      if (ext != "sql") {
        cli::cli_abort("filePath must be a .sql file, got: .{ext}")
      }

      # Validate label uniqueness
      private$validate_label_unique(label)

      # Validate parent cohorts exist
      private$validate_parent_cohorts_exist(cohortIds)

      # Run portability validation
      sql_content <- readr::read_file(filePath)
      .validateCustomSql(sql_content, label)

      # Copy SQL to derived/ directory
      derived_dir <- make_derived_folder(dirname(private$.dbPath))
      safe_label <- gsub("[^a-zA-Z0-9_-]", "_", label)
      dest_path <- fs::path(derived_dir, paste0(safe_label, ".sql"))
      fs::file_copy(filePath, dest_path, overwrite = TRUE)

      # Register in manifest
      # Uses cohort_type = "custom" with depends_on — Phase 1.1 skip-logic
      # handles this via length(parent_ids) > 0
      cohort_id <- private$insert_cohort(
        label = label,
        category = category,
        tags = tags,
        file_path = fs::path_rel(dest_path),
        source_type = "custom",
        cohort_type = "custom",
        depends_on = as.integer(cohortIds)
      )

      cli::cli_alert_success(
        "Built custom dependent cohort {cohort_id}: {label} (depends on: {paste(cohortIds, collapse = ', ')})"
      )
      invisible(cohort_id)
    },

    #' @description Build a composite cohort
    #'
    #' Creates a derived cohort that requires membership in multiple cohorts
    #' (intersection logic).
    #'
    #' @param label Character. Display name.
    #' @param category Character. Required classification.
    #' @param tags Named list. Optional metadata tags.
    #' @param criteriaCohortIds Integer vector. The cohort IDs to include in the composite
    #'   (e.g., c(1, 2, 3) for Type 1 diabetes, Type 2 diabetes, and secondary diabetes).
    #' @param minEventCount Integer. Minimum number of distinct cohort events required for a subject
    #'   to qualify for the composite. Default: 1 (any subject with at least 1 event qualifies).
    #' @param eventSelection Character. One of 'First', 'Last', or 'All'. Specifies which event(s) to
    #'   retain as the cohort_start_date and cohort_end_date in the output:
    #'   - 'First': Keep the earliest event (earliest index date)
    #'   - 'Last': Keep the most recent event
    #'   - 'All': Keep all qualifying events per subject (may result in multiple rows per subject)
    #'   Default: 'First'.
    #' 
    #'
    #' @return Invisible integer. The assigned cohort ID.
    buildCompositeCohort = function(
        label, 
        category, 
        tags = list(),
        criteriaCohortIds, 
        eventSelection = "First", 
        minEventCount = 1L
        ) {
      checkmate::assert_string(label, min.chars = 1)
      checkmate::assert_integerish(criteriaCohortIds, min.len = 2, unique = TRUE)
      checkmate::assert_string(category, min.chars = 1)
      checkmate::assert_list(tags, names = "named")
      checkmate::assert_choice(x = eventSelection, choices = c("First", "Last", "All"))
      checkmate::assert_integerish(minEventCount, lower = 1, upper = length(criteriaCohortIds))

      private$validate_label_unique(label)
      private$validate_parent_cohorts_exist(criteriaCohortIds)

      dependency_rule <- list(
        criteriaCohortIds = as.integer(criteriaCohortIds),
        eventSelection = eventSelection,
        minEventCount = as.integer(minEventCount)
      )

      derived_dir <- make_derived_folder(dirname(private$.dbPath))
      cohort_ids_str <- paste(criteriaCohortIds, collapse = ",")
      sql_path <- write_derived_template(derived_dir, label, "createCompositeCohort.sql",
        criteria_cohort_ids = cohort_ids_str,
        minimum_event_count = minEventCount,
        event_selection = eventSelection
      )

      cohort_id <- private$insert_cohort(
        label = label,
        category = category,
        tags = tags,
        file_path = fs::path_rel(sql_path),
        source_type = "derived",
        cohort_type = "composite",
        depends_on = as.integer(criteriaCohortIds),
        dependency_rule = dependency_rule
      )

      cli::cli_alert_success("Built composite cohort {cohort_id}: {label}")
      invisible(cohort_id)
    },

    #' @description Build a demographic subset cohort
    #'
    #' Creates a derived cohort that subsets a base cohort by filtering on
    #' person-level demographic attributes (age, gender, race, ethnicity).
    #'
    #' @param label Character. Display name (e.g., "CKD - Males 40-75").
    #' @param baseCohortId Integer. ID of the base cohort to subset.
    #' @param category Character. Required classification.
    #' @param minAge Integer or NULL. Minimum age at cohort start. Default: NULL (no minimum).
    #' @param maxAge Integer or NULL. Maximum age at cohort start. Default: NULL (no maximum).
    #' @param genderConceptIds Integer vector or NULL. Gender concept IDs to include.
    #'   Common values: 8507 = Male, 8532 = Female. Default: NULL (all genders).
    #' @param raceConceptIds Integer vector or NULL. Race concept IDs to include. Default: NULL.
    #' @param ethnicityConceptIds Integer vector or NULL. Ethnicity concept IDs to include. Default: NULL.
    #' @param tags Named list. Optional metadata tags.
    #'
    #' @return Invisible integer. The assigned cohort ID.
    buildDemographicCohort = function(label, baseCohortId, category,
                                      minAge = NULL, maxAge = NULL,
                                      genderConceptIds = NULL,
                                      raceConceptIds = NULL,
                                      ethnicityConceptIds = NULL,
                                      tags = list()) {
      checkmate::assert_string(label, min.chars = 1)
      checkmate::assert_int(baseCohortId)
      checkmate::assert_string(category, min.chars = 1)
      checkmate::assert_integerish(minAge, len = 1, lower = 0, null.ok = TRUE)
      checkmate::assert_integerish(maxAge, len = 1, lower = 0, null.ok = TRUE)
      checkmate::assert_integerish(genderConceptIds, min.len = 1, null.ok = TRUE)
      checkmate::assert_integerish(raceConceptIds, min.len = 1, null.ok = TRUE)
      checkmate::assert_integerish(ethnicityConceptIds, min.len = 1, null.ok = TRUE)
      checkmate::assert_list(tags, names = "named")

      private$validate_label_unique(label)
      private$validate_parent_cohorts_exist(baseCohortId)

      # Convert NULLs to "" for SqlRender conditional blocks
      sql_min_age            <- if (is.null(minAge))            "" else as.integer(minAge)
      sql_max_age            <- if (is.null(maxAge))            "" else as.integer(maxAge)
      sql_gender_ids         <- if (is.null(genderConceptIds))  "" else paste(as.integer(genderConceptIds),  collapse = ",")
      sql_race_ids           <- if (is.null(raceConceptIds))    "" else paste(as.integer(raceConceptIds),    collapse = ",")
      sql_ethnicity_ids      <- if (is.null(ethnicityConceptIds)) "" else paste(as.integer(ethnicityConceptIds), collapse = ",")

      dependency_rule <- list(
        baseCohortId       = as.integer(baseCohortId),
        minAge             = if (!is.null(minAge)) as.integer(minAge) else NULL,
        maxAge             = if (!is.null(maxAge)) as.integer(maxAge) else NULL,
        genderConceptIds   = if (!is.null(genderConceptIds))   as.integer(genderConceptIds)   else NULL,
        raceConceptIds     = if (!is.null(raceConceptIds))     as.integer(raceConceptIds)     else NULL,
        ethnicityConceptIds = if (!is.null(ethnicityConceptIds)) as.integer(ethnicityConceptIds) else NULL
      )

      cohorts_dir <- dirname(private$.dbPath)
      derived_dir <- fs::path(cohorts_dir, "derived")
      if (!dir.exists(derived_dir)) dir.create(derived_dir, recursive = TRUE)

      safe_label <- gsub("[^a-zA-Z0-9_-]", "_", label)
      sql_path <- fs::path(derived_dir, paste0(safe_label, ".sql"))

      template_path <- system.file("sql", "createSubsetCohort_Person.sql", package = "picard")
      rendered_sql <- readr::read_file(template_path) |>
        SqlRender::render(
          base_cohort_id        = baseCohortId,
          min_age               = sql_min_age,
          max_age               = sql_max_age,
          gender_concept_ids    = sql_gender_ids,
          race_concept_ids      = sql_race_ids,
          ethnicity_concept_ids = sql_ethnicity_ids
        )
      writeLines(rendered_sql, sql_path)

      cohort_id <- private$insert_cohort(
        label           = label,
        category        = category,
        tags            = tags,
        file_path       = fs::path_rel(sql_path),
        source_type     = "derived",
        cohort_type     = "subset",
        depends_on      = as.integer(baseCohortId),
        dependency_rule = dependency_rule
      )

      cli::cli_alert_success("Built demographic cohort {cohort_id}: {label}")
      invisible(cohort_id)
    },

    #' @description Split a base cohort into stratified sub-cohorts
    #'
    #' Splits a single base cohort into N named stratum cohorts plus an automatic
    #' \strong{Unclassified} cohort containing subjects that match none of the named
    #' strata. Each stratum is registered as a separate manifest entry with
    #' \code{cohort_type = "subset"}.
    #'
    #' @param baseCohortId Integer. The cohort definition ID to split.
    #' @param strata Named list. Each element is either a named list of demographic
    #'   filters (keys: \code{genderConceptIds}, \code{raceConceptIds},
    #'   \code{ethnicityConceptIds}, \code{minAge}, \code{maxAge}) or a character
    #'   string SQL WHERE condition referencing \code{bc} (cohort table) and \code{p}
    #'   (person table). Names become cohort labels.
    #' @param labelPrefix Character or NULL. If provided, prepended to each stratum name
    #'   with a \code{" - "} separator.
    #' @param category Character. Category applied to every stratum cohort. Default: \code{"derived"}.
    #' @param tags Named list. Optional metadata tags applied to every stratum cohort.
    #'
    #' @return Invisibly returns a named list of assigned cohort IDs, keyed by cohort label.
    buildStratifiedCohorts = function(baseCohortId, strata, labelPrefix = NULL,
                                      category = "derived", tags = list()) {
      checkmate::assert_int(baseCohortId)
      checkmate::assert_list(strata, min.len = 1, names = "named")
      checkmate::assert_string(labelPrefix, null.ok = TRUE)
      checkmate::assert_string(category, min.chars = 1)
      checkmate::assert_list(tags, names = "named")

      private$validate_parent_cohorts_exist(baseCohortId)

      # Validate each stratum entry
      for (nm in names(strata)) {
        s <- strata[[nm]]
        if (!is.list(s) && !is.character(s)) {
          cli::cli_abort("Stratum '{nm}' must be a named list (demographic) or a character SQL condition.")
        }
        if (is.character(s) && length(s) != 1) {
          cli::cli_abort("Stratum '{nm}' character condition must be a single string.")
        }
      }

      # Build SQL condition for each named stratum
      stratum_conditions <- lapply(strata, .stratum_to_sql_condition)

      # Append Unclassified stratum — negation of every named condition
      negated <- paste0("NOT (", unlist(stratum_conditions), ")")
      stratum_conditions[["Unclassified"]] <- paste(negated, collapse = "\n    AND ")

      cohorts_dir <- dirname(private$.dbPath)
      derived_dir <- fs::path(cohorts_dir, "derived")
      if (!dir.exists(derived_dir)) dir.create(derived_dir, recursive = TRUE)

      template_path <- system.file("sql", "createStratifiedCohort_Stratum.sql", package = "picard")
      template_sql <- readr::read_file(template_path)

      sanitise_name <- function(nm) gsub("[^A-Za-z0-9_]", "_", tolower(nm))

      result <- list()
      cli::cli_rule("Building stratified cohorts from base cohort {baseCohortId}")

      for (nm in names(stratum_conditions)) {
        condition    <- stratum_conditions[[nm]]
        cohort_label <- if (!is.null(labelPrefix)) paste0(labelPrefix, " - ", nm) else nm
        is_unclassified <- nm == "Unclassified"

        rendered_sql <- SqlRender::render(
          template_sql,
          base_cohort_id       = as.integer(baseCohortId),
          stratum_where_clause = condition,
          warnOnMissingParameters = FALSE
        )

        file_name <- sprintf("stratified_%d_%s", as.integer(baseCohortId), sanitise_name(nm))
        sql_path  <- fs::path(derived_dir, paste0(file_name, ".sql"))
        writeLines(rendered_sql, sql_path)

        dependency_rule <- list(
          baseCohortId      = as.integer(baseCohortId),
          stratumName       = nm,
          stratumDefinition = if (is_unclassified) NULL else strata[[nm]],
          isUnclassified    = is_unclassified
        )

        cohort_id <- private$insert_cohort(
          label           = cohort_label,
          category        = category,
          tags            = tags,
          file_path       = fs::path_rel(sql_path),
          source_type     = "derived",
          cohort_type     = "subset",
          depends_on      = as.integer(baseCohortId),
          dependency_rule = dependency_rule
        )

        result[[cohort_label]] <- cohort_id
        cli::cli_alert_success("Registered stratum {cohort_id}: {cohort_label}")
      }

      cli::cli_rule("Done — {length(result)} strata registered (includes Unclassified)")
      invisible(result)
    },

    # ========== QUERY METHODS ==========

    #' Query cohorts by IDs
    #'
    #' @param ids Integer vector. One or more cohort IDs.
    #'
    #' @return Data frame. A subset of the manifest with columns id, label, tags, filePath, hash, timestamp for matching cohorts, or NULL if none found.
    queryCohortsByIds = function(ids) {
      checkmate::assert_integerish(x = ids, min.len = 1)
      ids <- as.integer(ids)

      matching_cohorts <- list()

      for (cohort in private$.manifest) {
        if (cohort$getId() %in% ids) {
          matching_cohorts[[length(matching_cohorts) + 1]] <- cohort
        }
      }

      if (length(matching_cohorts) == 0) {
        cli::cli_alert_warning("No cohorts found with IDs: {paste(ids, collapse = ', ')}")
        return(NULL)
      }

      # Get data from database
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      ids_str <- paste(ids, collapse = ", ")
      manifest_df <- DBI::dbGetQuery(
        conn,
        paste0("SELECT id, label, category, tags, file_path, hash, source_type, created_at 
                FROM cohort_manifest WHERE id IN (", ids_str, ") AND status = 'active'")
      )

      if (nrow(manifest_df) == 0) {
        return(NULL)
      }

      return(tibble::as_tibble(manifest_df))
    },

    #' Query cohorts by tag
    #'
    #' @param tagStrings Character vector. One or more tags in the format "name: value"
    #'   (e.g., "category: primary"). When multiple tags are supplied, the \code{match}
    #'   argument controls whether a cohort must satisfy any or all of them.
    #' @param match Character. "any" (default) returns cohorts matching at least one tag;
    #'   "all" returns only cohorts matching every tag.
    #'
    #' @return Tibble with columns: id, label, category, tags, file_path, hash, source_type, created_at.
    queryCohortsByTag = function(tagStrings, match = c("any", "all")) {
      checkmate::assert_character(x = tagStrings, min.len = 1, min.chars = 1)
      match <- match.arg(match)

      # Parse each tag string into name/value pairs
      parsed_tags <- lapply(tagStrings, function(ts) {
        tag_parts <- strsplit(ts, ":\\s*")[[1]]
        if (length(tag_parts) != 2) {
          cli::cli_abort("Tag must be in the format 'name: value': {ts}")
        }
        list(name = trimws(tag_parts[1]), value = trimws(tag_parts[2]))
      })

      matching_cohorts <- list()

      # Search through manifest for matching tags
      for (cohort in private$.manifest) {
        cohort_tags <- cohort$tags
        tag_hits <- sapply(parsed_tags, function(pt) {
          !is.null(cohort_tags) &&
            pt$name %in% names(cohort_tags) &&
            cohort_tags[[pt$name]] == pt$value
        })

        include <- if (match == "any") any(tag_hits) else all(tag_hits)

        if (include) {
          matching_cohorts[[length(matching_cohorts) + 1]] <- cohort
        }
      }

      if (length(matching_cohorts) == 0) {
        match_desc <- paste(tagStrings, collapse = " | ")
        cli::cli_alert_warning("No cohorts found matching ({match}): {match_desc}")
        return(NULL)
      }

      # Get matching cohort IDs and query database
      matching_ids <- sapply(matching_cohorts, function(c) c$getId())
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      ids_str <- paste(matching_ids, collapse = ", ")
      manifest_df <- DBI::dbGetQuery(
        conn,
        paste0("SELECT id, label, category, tags, file_path, hash, source_type, created_at 
                FROM cohort_manifest WHERE id IN (", ids_str, ") AND status = 'active'")
      )

      if (nrow(manifest_df) == 0) {
        return(NULL)
      }

      manifest_df <- tibble::as_tibble(manifest_df)

      return(manifest_df)
    },

    #' Query cohorts by label
    #'
    #' @param labels Character vector. One or more labels to search for.
    #'   A cohort is included when it matches at least one of the supplied labels (OR logic).
    #' @param matchType Character. Either "exact" for exact match or "pattern" for pattern matching.
    #'   Defaults to "exact".
    #'
    #' @return Tibble with columns: id, label, category, tags, file_path, hash, source_type, created_at.
    queryCohortsByLabel = function(labels, matchType = c("exact", "pattern")) {
      checkmate::assert_character(x = labels, min.len = 1, min.chars = 1)
      matchType <- match.arg(matchType)

      matching_cohorts <- list()

      # Search through manifest for matching labels (any-match across supplied labels)
      for (cohort in private$.manifest) {
        cohort_label <- cohort$label

        label_hits <- sapply(labels, function(lbl) {
          if (matchType == "exact") {
            cohort_label == lbl
          } else {
            grepl(lbl, cohort_label, ignore.case = TRUE)
          }
        })

        if (any(label_hits)) {
          matching_cohorts[[length(matching_cohorts) + 1]] <- cohort
        }
      }

      if (length(matching_cohorts) == 0) {
        match_desc <- paste(labels, collapse = " | ")
        cli::cli_alert_warning("No cohorts found with {matchType} label match: {match_desc}")
        return(NULL)
      }

      # Get matching cohort IDs and query database
      matching_ids <- sapply(matching_cohorts, function(c) c$getId())
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      ids_str <- paste(matching_ids, collapse = ", ")
      manifest_df <- DBI::dbGetQuery(
        conn,
        paste0("SELECT id, label, category, tags, file_path, hash, source_type, created_at 
                FROM cohort_manifest WHERE id IN (", ids_str, ") AND status = 'active'")
      )

      if (nrow(manifest_df) == 0) {
        return(NULL)
      }

      return(tibble::as_tibble(manifest_df))
    },

    #' Query cohorts by category
    #'
    #' @param category Character vector. One or more category to search for.
    #'   A cohort is included when it matches at least one of the supplied category (OR logic).
    #' @param matchType Character. Either "exact" for exact match or "pattern" for pattern matching.
    #'   Defaults to "exact".
    #'
    #' @return Tibble with columns: id, label, category, tags, file_path, hash, source_type, created_at.
    queryCohortsByCategory = function(category, matchType = c("exact", "pattern")) {
      checkmate::assert_character(x = category, min.len = 1, min.chars = 1)
      matchType <- match.arg(matchType)

      matching_cohorts <- list()

      # Search through manifest for matching category (any-match across supplied category)
      for (cohort in private$.manifest) {
        cohort_label <- cohort$category

        label_hits <- sapply(category, function(lbl) {
          if (matchType == "exact") {
            cohort_label == lbl
          } else {
            grepl(lbl, cohort_label, ignore.case = TRUE)
          }
        })

        if (any(label_hits)) {
          matching_cohorts[[length(matching_cohorts) + 1]] <- cohort
        }
      }

      if (length(matching_cohorts) == 0) {
        match_desc <- paste(category, collapse = " | ")
        cli::cli_alert_warning("No cohorts found with {matchType} label match: {match_desc}")
        return(NULL)
      }

      # Get matching cohort IDs and query database
      matching_ids <- sapply(matching_cohorts, function(c) c$getId())
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      ids_str <- paste(matching_ids, collapse = ", ")
      manifest_df <- DBI::dbGetQuery(
        conn,
        paste0("SELECT id, label, category, tags, file_path, hash, source_type, created_at 
                FROM cohort_manifest WHERE id IN (", ids_str, ") AND status = 'active'")
      )

      if (nrow(manifest_df) == 0) {
        return(NULL)
      }

      return(tibble::as_tibble(manifest_df))
    },

    #' Query cohorts by category
    #'
    #' @param tagName Character vector. The name of tags to query
    #'
    #' @return Tibble with columns: id, label, category, tags, file_path, hash, source_type, created_at.
    queryCohortsByTagName = function(tagName) {
      checkmate::assert_character(x = tagName, min.len = 1, min.chars = 1)

      tcm <- self$tabulateManifest() |> 
        dplyr::mutate(
          tags_list = purrr::map(tags, ~jsonlite::fromJSON(.x))
        ) |>
        dplyr::filter(
          purrr::map_lgl(tags_list, ~tagName %in% names(.))
        ) |>
        dplyr::select(-c(tags_list))

      return(tcm)
    },

    #' @description Get number of cohorts in manifest
    #'
    #' @return Integer. The number of cohorts.
    nCohorts = function() {
      length(private$.manifest)
    },

    #' Get a specific cohort by ID
    #'
    #' @param id Integer. The cohort ID.
    #'
    #' @return CohortDef. The CohortDef object with matching ID, or NULL if not found.
    getCohortById = function(id) {
      checkmate::assert_int(x = id)

      for (cohort in private$.manifest) {
        if (cohort$getId() == id) {
          return(cohort)
        }
      }

      cli::cli_alert_warning("Cohort with ID {id} not found")
      return(NULL)
    },

    #' Get cohorts by tag
    #'
    #' @param tagStrings Character vector. One or more tags in the format "name: value"
    #'   (e.g., "category: primary"). When multiple tags are supplied, the \code{match}
    #'   argument controls whether a cohort must satisfy any or all of them.
    #' @param match Character. "any" (default) returns cohorts matching at least one tag;
    #'   "all" returns only cohorts matching every tag.
    #'
    #' @return List. A list of CohortDef objects with matching tags, or NULL if none found.
    getCohortsByTag = function(tagStrings, match = c("any", "all")) {
      checkmate::assert_character(x = tagStrings, min.len = 1, min.chars = 1)
      match <- match.arg(match)

      # Parse each tag string into name/value pairs
      parsed_tags <- lapply(tagStrings, function(ts) {
        tag_parts <- strsplit(ts, ":\\s*")[[1]]
        if (length(tag_parts) != 2) {
          cli::cli_abort("Tag must be in the format 'name: value': {ts}")
        }
        list(name = trimws(tag_parts[1]), value = trimws(tag_parts[2]))
      })

      matching_cohorts <- list()

      # Search through manifest for matching tags
      for (cohort in private$.manifest) {
        cohort_tags <- cohort$tags
        tag_hits <- sapply(parsed_tags, function(pt) {
          !is.null(cohort_tags) &&
            pt$name %in% names(cohort_tags) &&
            cohort_tags[[pt$name]] == pt$value
        })

        include <- if (match == "any") any(tag_hits) else all(tag_hits)

        if (include) {
          matching_cohorts[[length(matching_cohorts) + 1]] <- cohort
        }
      }

      if (length(matching_cohorts) == 0) {
        match_desc <- paste(tagStrings, collapse = " | ")
        cli::cli_alert_warning("No cohorts found matching ({match}): {match_desc}")
        return(NULL)
      }

      return(matching_cohorts)
    },

    #' Get cohorts by label
    #'
    #' @param labels Character vector. One or more labels to search for.
    #'   A cohort is included when it matches at least one of the supplied labels (OR logic).
    #' @param matchType Character. Either "exact" for exact match or "pattern" for pattern matching.
    #'   Defaults to "exact".
    #'
    #' @return List. A list of CohortDef objects with matching labels, or NULL if none found.
    getCohortsByLabel = function(labels, matchType = c("exact", "pattern")) {
      checkmate::assert_character(x = labels, min.len = 1, min.chars = 1)
      matchType <- match.arg(matchType)

      matching_cohorts <- list()

      # Search through manifest for matching labels (any-match across supplied labels)
      for (cohort in private$.manifest) {
        cohort_label <- cohort$label

        label_hits <- sapply(labels, function(lbl) {
          if (matchType == "exact") {
            cohort_label == lbl
          } else {
            grepl(lbl, cohort_label, ignore.case = TRUE)
          }
        })

        if (any(label_hits)) {
          matching_cohorts[[length(matching_cohorts) + 1]] <- cohort
        }
      }

      if (length(matching_cohorts) == 0) {
        match_desc <- paste(labels, collapse = " | ")
        cli::cli_alert_warning("No cohorts found with {matchType} label match: {match_desc}")
        return(NULL)
      }

      return(matching_cohorts)
    },

    # ========== MANAGEMENT METHODS ==========

    #' @description Update a cohort label
    #'
    #' @param cohortId Integer. The cohort ID to update.
    #' @param newLabel Character. The new label for the cohort.
    #'
    #' @return Invisible NULL.
    updateCohortLabel = function(cohortId, newLabel) {
      checkmate::assert_int(cohortId, lower = 1)
      checkmate::assert_string(newLabel, min.chars = 1)
      private$update_cohort_def(cohortId = cohortId, label = newLabel)
      invisible(NULL)
    },

    #' @description Update a cohort category
    #'
    #' @param cohortId Integer. The cohort ID to update.
    #' @param newCategory Character. The new category for the cohort.
    #'
    #' @return Invisible NULL.
    updateCohortCategory = function(cohortId, newCategory) {
      checkmate::assert_int(cohortId, lower = 1)
      checkmate::assert_string(newCategory, min.chars = 1)
      private$update_cohort_def(cohortId = cohortId, category = newCategory)
      invisible(NULL)
    },

    #' @description Update cohort tags
    #'
    #' @param cohortId Integer. The cohort ID to update.
    #' @param newTags Named list. The new tags for the cohort.
    #'
    #' @return Invisible NULL.
    updateCohortTags = function(cohortId, newTags) {
      checkmate::assert_int(cohortId, lower = 1)
      checkmate::assert_list(newTags, names = "named")
      private$update_cohort_def(cohortId = cohortId, tags = newTags)
      invisible(NULL)
    },

    #' @description Auto-detect changes to ATLAS cohorts in remote repository
    #'
    #' Queries the manifest for all active ATLAS cohorts (identified by `atlasId` in tags),
    #' fetches their current definitions from ATLAS, computes hashes, and compares against
    #' the stored local hash. Provides a read-only summary of which cohorts have changed
    #' in ATLAS since import. No modifications are made.
    #'
    #' @details
    #' This is the detection phase of the ATLAS maintenance workflow. Use this to identify
    #' which ATLAS cohorts have changed, then optionally call `updateAtlasCohorts()` to
    #' apply updates. Changes are detected by comparing expression JSON hashes.
    #'
    #' @param atlasConnection An ATLAS connection object  with a method `getCohortDefinition(cohortId)` 
    #'   that returns a list with an `expression` element.
    #'   If `NULL` (default), uses the connection stored via `$setAtlasConnection()`.
    #'   If no connection is available, raises an error.
    #'
    #' @return Invisible tibble with columns:
    #'   \itemize{
    #'     \item \code{id} - Cohort ID in manifest
    #'     \item \code{label} - Cohort label
    #'     \item \code{atlasId} - ATLAS cohort definition ID
    #'     \item \code{hasChanged} - Logical; TRUE if remote hash differs from local
    #'     \item \code{localHash} - Hash of stored JSON
    #'     \item \code{remoteHash} - Hash of current ATLAS JSON
    #'   }
    checkAtlasCohorts = function(atlasConnection = NULL) {

      if (is.null(atlasConnection)) {
        atlasConnection <- private$.atlasConnection
      }

      if (is.null(atlasConnection)) {
        cli::cli_abort(c(
          "No ATLAS connection available.",
          i = "Supply {.arg atlasConnection} or call {.code $setAtlasConnection()} first."
        ))
      }

      cm_atlas_subset <- self$queryCohortsByTagName(tagName = "atlasId") |>
        dplyr::mutate(
          tags_list = purrr::map(tags, ~jsonlite::fromJSON(.x)),
          atlasId = purrr::map_int(tags_list, ~.x$atlasId)
        ) |>
        dplyr::select(
          id, atlasId, label, category, hash, file_path
        )
      
      if (is.null(cm_atlas_subset) || nrow(cm_atlas_subset) == 0) {
        cli::cli_alert_info("No ATLAS cohorts found in manifest")
        invisible(NULL)
      }

      res <- vector('list', length = nrow(cm_atlas_subset))
      # go through each atlas cohort row and check if any change to the definition
      for (i in seq_len(nrow(cm_atlas_subset))) {
        row_atlas_id <- cm_atlas_subset$atlasId[i]
        row_label <- cm_atlas_subset$label[i]
        existing_id <- cm_atlas_subset$id[i]
        current_hash <- cm_atlas_subset$hash[i]
        row_file_path <- cm_atlas_subset$file_path[i]

        # Fetch JSON from ATLAS and compare hashes
        tryCatch({
          cohort_def <- atlasConnection$getCohortDefinition(row_atlas_id)
        }, error = function(e) {
          cli::cli_warn("Failed to fetch atlasId {row_atlas_id}: {e$message}")
          return(NULL)
        })

        expression_json <- c(cohort_def$expression[1], "\n") |> paste(collapse = "") # make sure matches file read
        remote_hash <- rlang::hash(expression_json)
        has_changed <- !identical(remote_hash, current_hash)

        if (has_changed) {
          cli::cli_alert_warning("{row_label} (ID {existing_id}): CHANGED")
        } else {
          cli::cli_alert_success("{row_label} (ID {existing_id}): Unchanged")
        }

        res[[i]] <- data.frame(
          id = existing_id,
          label = row_label,
          atlasId = row_atlas_id,
          filePath = row_file_path,
          hasChanged = has_changed,
          localHash = current_hash,
          remoteHash = remote_hash
        )
      }

      res_final <- do.call('rbind', res) |>
        tibble::as_tibble()

      cli::cli_rule("ATLAS Change Detection Summary ({nrow(res_final)} cohort(s) checked)")
      print(res_final)

      invisible(res_final)

    },
    #' @description Update ATLAS cohorts with remote definitions
    #'
    #' Fetches current definitions from ATLAS for specified cohorts and updates the stored JSON files
    #' and manifest entries. This is the modification phase that applies changes detected by checkAtlasChanges().
    #'
    #' @details
    #' This method updates ATLAS cohorts that have changed in the remote repository. It:
    #' - Fetches current definitions from ATLAS
    #' - Updates JSON files on disk
    #' - Recomputes and stores hashes
    #' - Updates the manifest database
    #'
    #' Use `checkAtlasChanges()` first to identify which cohorts have changed, then call this method
    #' to apply updates.
    #'
    #' @param atlasConnection An ATLAS connection object with a method `getCohortDefinition(cohortId)`.
    #'   If `NULL` (default), uses the connection stored via `$setAtlasConnection()`.
    #'
    #' @return invisible of the tibble of atlas changes to update
    updateAtlasCohorts = function(atlasConnection = NULL) {
      if (is.null(atlasConnection)) {
        atlasConnection <- private$.atlasConnection
      }

      if (is.null(atlasConnection)) {
        cli::cli_abort(c(
          "No ATLAS connection available.",
          i = "Supply {.arg atlasConnection} or call {.code $setAtlasConnection()} first."
        ))
      }

      # check for changes
      check_atlas_changes <- self$checkAtlasCohorts(atlasConnection) |>
        dplyr::filter(hasChanged)

      if (nrow(check_atlas_changes) == 0) {
        cli::cli_alert_info("No changed ATLAS cohorts found. All {nrow(check_atlas_changes)} cohort(s) are current.")
        invisible(NULL)
      }

      # get sqlite
      dbPath <- private$.dbPath
      sqlite_conn <- DBI::dbConnect(RSQLite::SQLite(), dbPath)
      on.exit(DBI::dbDisconnect(sqlite_conn))

      # Header
      cli::cli_rule("ATLAS Cohort Update")
      cli::cli_alert_info("Updating {nrow(check_atlas_changes)} cohort(s)")


      res <- vector('list', length = nrow(check_atlas_changes))
      # go through each atlas cohort row and check if any change to the definition
      for (i in seq_len(nrow(check_atlas_changes))) {
        row_atlas_id <- check_atlas_changes$atlasId[i]
        row_label <- check_atlas_changes$label[i]
        existing_path <- check_atlas_changes$filePath[i]
        existing_id <- check_atlas_changes$id[i]

        # Fetch JSON from ATLAS and compare hashes
        tryCatch({
          cohort_def <- atlasConnection$getCohortDefinition(row_atlas_id)
        }, error = function(e) {
          cli::cli_warn("Failed to fetch atlasId {row_atlas_id}: {e$message}")
          return(NULL)
        })
        expression_json <- cohort_def$expression[1]
        expression_json_file <- c(expression_json, "\n") |> paste(collapse = "") # make sure matches file read line ending
        new_hash <- rlang::hash(expression_json_file)


        # Save JSON to json/ directory
        cohorts_dir <- dirname(dbPath)
        json_dir <- fs::path(cohorts_dir, "json")

        # extract cohort name from definition to use as file name (fallback to label if not available)
        json_file_path <- fs::path_file(existing_path)
        json_path <- fs::path(json_dir, json_file_path)
        readr::write_lines(expression_json, json_path) # make line ending always \\n

        #update the manifest sqlite
        DBI::dbExecute(
          sqlite_conn,
          "UPDATE cohort_manifest SET hash = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
          list(new_hash, existing_id)
        )

        #update in-memory manifest TODO
        #private$.manifest

        cli::cli_alert_success("Updated {row_label} (ID {existing_id})")
        # cascade dependency  
        cascadeStaleDownstream(dbPath, existing_id)

      }

      invisible(check_atlas_changes)



    },

    #' @description Generate a status report for the manifest
    #'
    #' Prints a summary table showing all active cohorts with their dependencies
    #' and source types. Useful for auditing the manifest structure.
    #'
    #' @return Invisible tibble with columns: id, label, category, source_type, depends_on, status.
    statusReport = function() {
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      report <- DBI::dbGetQuery(
        conn,
        "SELECT id, label, category, source_type, depends_on, status FROM cohort_manifest WHERE status = 'active' ORDER BY id"
      )

      if (nrow(report) == 0) {
        cli::cli_alert_info("No active cohorts in manifest")
        invisible(tibble::tibble())
      }

      # Parse depends_on JSON for display
      report$depends_on <- sapply(report$depends_on, function(x) {
        if (is.na(x) || x == "") {
          "—"
        } else {
          tryCatch(
            paste(jsonlite::fromJSON(x), collapse = ", "),
            error = function(e) x
          )
        }
      })

      report_tbl <- tibble::as_tibble(report)

      cli::cli_h1("Cohort Manifest Status Report")
      print(report_tbl)

      invisible(report_tbl)
    },

    #' @description Print a friendly view of the CohortManifest
    #'
    #' Displays key metadata about the manifest and its contents.
    print = function() {
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      active_count <- DBI::dbGetQuery(conn, "SELECT COUNT(*) as n FROM cohort_manifest WHERE status = 'active'")$n
      deleted_count <- DBI::dbGetQuery(conn, "SELECT COUNT(*) as n FROM cohort_manifest WHERE status = 'deleted'")$n
      total_count <- active_count + deleted_count

      cat("CohortManifest\n")
      cat("  Database:", private$.dbPath, "\n")
      cat("  Total cohorts: ", total_count, "\n", sep = "")
      cat("  Active: ", active_count, "\n", sep = "")
      cat("  Deleted: ", deleted_count, "\n", sep = "")

      if (active_count > 0) {
        cat("\n  Active cohorts:\n")
        active <- DBI::dbGetQuery(
          conn,
          "SELECT id, label, category, source_type FROM cohort_manifest WHERE status = 'active' ORDER BY id LIMIT 10"
        )
        for (i in seq_len(nrow(active))) {
          cat(sprintf("    [%d] %s (%s / %s)\n", active$id[i], active$label[i], active$category[i], active$source_type[i]))
        }
        if (active_count > 10) {
          cat("    ... and", active_count - 10, "more\n")
        }
      }

      invisible(self)
    },

    #' Create cohort tables in the database
    #'
    #' @description
    #' Creates the necessary cohort tables in the target database using the execution settings.
    #' First checks if tables already exist before attempting creation.
    #'
    #' @details
    #' Requires that executionSettings has been set and includes:
    #' - A database connection (via getConnection()
    #' - workDatabaseSchema for the target schema
    #' - cohortTable with the desired table name
    #' - tempEmulationSchema if needed for the database platform
    #'
    #' @return Invisible NULL. Creates tables in the database and prints status messages.
    createCohortTables = function() {
      # Validate execution settings are available
      private$validateExecutionSettings()

      # Get execution parameters
      settings <- private$.executionSettings
      conn <- settings$getConnection()
      if (is.null(conn)) {
        settings$connect()
        conn <- settings$getConnection()
      }
      on.exit(settings$disconnect())
      
      schema <- settings$workDatabaseSchema
      if (is.null(schema) || is.na(schema)) {
        stop("workDatabaseSchema must be set in execution settings")
      }

      cohort_table <- settings$cohortTable
      if (is.null(cohort_table) || is.na(cohort_table)) {
        stop("cohortTable must be set in execution settings")
      }

      temp_schema <- settings$tempEmulationSchema
      dbms <- settings$getDbms()

      # Get cohort table names
      table_names <- getCohortTableNames(
        cohortTable = cohort_table,
        cohortSampleTable = cohort_table,
        cohortInclusionTable = paste0(cohort_table, "_inclusion"),
        cohortInclusionResultTable = paste0(cohort_table, "_inclusion_result"),
        cohortInclusionStatsTable = paste0(cohort_table, "_inclusion_stats"),
        cohortSummaryStatsTable = paste0(cohort_table, "_summary_stats"),
        cohortCensorStatsTable = paste0(cohort_table, "_censor_stats")
      )

      cli::cli_rule("Creating Cohort Tables")
      cli::cli_alert_info("Database: {settings$databaseName}")
      cli::cli_alert_info("Schema: {schema}")
      cli::cli_alert_info("Main table: {cohort_table}")

      tables_to_create <- list(
        main = list(name = cohort_table, type = "main"),
        inclusion = list(name = table_names$cohortInclusionTable, type = "inclusion"),
        inclusion_result = list(name = table_names$cohortInclusionResultTable, type = "inclusion_result"),
        inclusion_stats = list(name = table_names$cohortInclusionStatsTable, type = "inclusion_stats"),
        summary_stats = list(name = table_names$cohortSummaryStatsTable, type = "summary_stats"),
        censor_stats = list(name = table_names$cohortCensorStatsTable, type = "censor_stats"),
        checksum = list(name = table_names$cohortChecksumTable, type = "checksum")
      )

      # Check for existing tables and create missing ones
      for (table_info in tables_to_create) {
        table_name <- table_info$name
        table_type <- table_info$type

        # Check if table exists
        if (tableExists(conn, schema, table_name, dbms)) {
          cli::cli_alert_warning("{table_type} table already exists: {table_name}")
        } else {
          # Create the table
          if (table_type == "main") {
            sql <- createMainCohortTableSql(schema, table_name, dbms, temp_schema)
          } else if (table_type == "inclusion") {
            sql <- createInclusionTableSql(schema, table_name, dbms)
          } else if (table_type == "inclusion_result") {
            sql <- createInclusionResultTableSql(schema, table_name, dbms)
          } else if (table_type == "inclusion_stats") {
            sql <- createInclusionStatsTableSql(schema, table_name, dbms)
          } else if (table_type == "summary_stats") {
            sql <- createSummaryStatsTableSql(schema, table_name, dbms)
          } else if (table_type == "censor_stats") {
            sql <- createCensorStatsTableSql(schema, table_name, dbms)
          } else if (table_type == "checksum") {
            sql <- createChecksumTableSql(schema, table_name, dbms)
          }

          tryCatch({
            DatabaseConnector::executeSql(conn, sql, progressBar = FALSE, reportOverallTime = FALSE)
            cli::cli_alert_success("Created {table_type} table: {table_name}")
          }, error = function(e) {
            cli::cli_alert_danger("Failed to create {table_type} table {table_name}: {e$message}")
          })
        }
      }

      cli::cli_rule()
      cli::cli_alert_success("Cohort tables setup complete")

      invisible(NULL)
    },

    #' Drop cohort tables from the database
    #'
    #' @description
    #' Drops cohort tables from the target database. Can drop all standard cohort tables or specific tables.
    #' This is useful for cleaning up or resetting the cohort generation environment.
    #'
    #' @details
    #' Requires that executionSettings has been set and includes:
    #' - A database connection (via getConnection()
    #' - workDatabaseSchema for the target schema
    #' - cohortTable with the desired table name
    #'
    #' @param tableTypes Character vector. Types of tables to drop. Options: "cohort", "inclusion", 
    #'   "inclusion_result", "inclusion_stats", "summary_stats", "censor_stats", "checksum".
    #'   If NULL (default), drops all table types.
    #'
    #' @return Invisible NULL. Drops tables from the database and prints status messages.
    dropCohortTables = function(tableTypes = NULL) {
      # Validate execution settings
      settings <- private$.executionSettings
      if (is.null(settings)) {
        stop("Execution settings must be set before dropping cohort tables")
      }

      # Get execution parameters
      conn <- settings$getConnection()
      if (is.null(conn)) {
        settings$connect()
        conn <- settings$getConnection()
      }
      on.exit(settings$disconnect())

      schema <- settings$workDatabaseSchema
      if (is.null(schema) || is.na(schema)) {
        stop("workDatabaseSchema must be set in execution settings")
      }

      cohort_table <- settings$cohortTable
      if (is.null(cohort_table) || is.na(cohort_table)) {
        stop("cohortTable must be set in execution settings")
      }

      dbms <- settings$getDbms()

      # Get cohort table names
      table_names <- getCohortTableNames(
        cohortTable = cohort_table,
        cohortSampleTable = cohort_table,
        cohortInclusionTable = paste0(cohort_table, "_inclusion"),
        cohortInclusionResultTable = paste0(cohort_table, "_inclusion_result"),
        cohortInclusionStatsTable = paste0(cohort_table, "_inclusion_stats"),
        cohortSummaryStatsTable = paste0(cohort_table, "_summary_stats"),
        cohortCensorStatsTable = paste0(cohort_table, "_censor_stats")
      )

      # Define all available tables
      all_tables <- list(
        cohort = list(name = cohort_table, type = "cohort"),
        inclusion = list(name = table_names$cohortInclusionTable, type = "inclusion"),
        inclusion_result = list(name = table_names$cohortInclusionResultTable, type = "inclusion_result"),
        inclusion_stats = list(name = table_names$cohortInclusionStatsTable, type = "inclusion_stats"),
        summary_stats = list(name = table_names$cohortSummaryStatsTable, type = "summary_stats"),
        censor_stats = list(name = table_names$cohortCensorStatsTable, type = "censor_stats"),
        checksum = list(name = table_names$cohortChecksumTable, type = "checksum")
      )

      # Filter tables to drop
      if (is.null(tableTypes)) {
        # Drop all tables
        tables_to_drop <- all_tables
      } else {
        # Validate and filter requested table types
        valid_types <- c("cohort", "inclusion", "inclusion_result", "inclusion_stats", "summary_stats", "censor_stats", "checksum")
        invalid_types <- setdiff(tableTypes, valid_types)

        if (length(invalid_types) > 0) {
          stop("Invalid table types: ", paste(invalid_types, collapse = ", "),
               "\nValid options: ", paste(valid_types, collapse = ", ")
          )
        }

        tables_to_drop <- all_tables[tableTypes]
      }

      cli::cli_rule("Dropping Cohort Tables")
      cli::cli_alert_info("Database: {settings$databaseName}")
      cli::cli_alert_info("Schema: {schema}")

      dropped_count <- 0
      not_found_count <- 0

      # Drop each table
      for (table_info in tables_to_drop) {
        table_name <- table_info$name
        table_type <- table_info$type

        # Check if table exists
        if (tableExists(conn, schema, table_name, dbms)) {
          # Build DROP TABLE statement
          sql <- paste0("DROP TABLE ", schema, ".", table_name)

          tryCatch({
            DatabaseConnector::executeSql(conn, sql, progressBar = FALSE, reportOverallTime = FALSE)
            cli::cli_alert_success("Dropped {table_type} table: {table_name}")
            dropped_count <- dropped_count + 1
          }, error = function(e) {
            cli::cli_alert_danger("Failed to drop {table_type} table {table_name}: {e$message}")
          })
        } else {
          cli::cli_alert_warning("{table_type} table does not exist: {table_name}")
          not_found_count <- not_found_count + 1
        }
      }

      cli::cli_rule()
      cli::cli_alert_success("Dropped {dropped_count} table(s)")
      if (not_found_count > 0) {
        cli::cli_alert_info("{not_found_count} table(s) did not exist")
      }

      invisible(NULL)
    },

    #' Sync the manifest against cohort files on disk
    #'
    #' @description
    #' Scans the \code{json/} and \code{sql/} subdirectories of the cohorts folder, reconciles
    #' them against the SQLite manifest, and updates both the database and the in-memory list:
    #' \itemize{
    #'   \item Active manifest records whose file no longer exists are soft-deleted.
    #'   \item Existing files whose SQL hash has changed are updated in the manifest.
    #'   \item Orphaned files on disk not in manifest are automatically deleted.
    #' }
    #' Only the \code{json/} and \code{sql/} source directories are scanned — derived cohorts
    #' managed via \code{build*()} methods are not touched.
    #'
    #' @param strict_mode Logical. If TRUE (default), automatically removes orphaned files found
    #'   on disk. If FALSE, only warns about them without deletion. Default: TRUE.
    #'
    #' @return Data frame with columns: id, label, action
    #'   (\code{"hash_updated"}, \code{"missing_flagged"}, \code{"unchanged"}, 
    #'    \code{"auto_removed_orphan"}).
    syncManifest = function(strict_mode = TRUE) {
      checkmate::assert_flag(strict_mode)
      
      cohorts_folder <- dirname(private$.dbPath)
      json_dir <- file.path(cohorts_folder, "json")
      sql_dir  <- file.path(cohorts_folder, "sql")

      # Collect all source files currently on disk
      on_disk <- c()

      if (dir.exists(json_dir)) {
        on_disk <- c(on_disk, list.files(json_dir, pattern = "\\.json$",
                                          full.names = TRUE, recursive = TRUE))
      }

      if (dir.exists(sql_dir)) {
        on_disk <- c(on_disk, list.files(sql_dir, pattern = "\\.sql$",
                                          full.names = TRUE, recursive = TRUE))
      }

      on_disk_rel <- fs::path_rel(on_disk)

      # Pull current active source records from the SQLite manifest
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      db_records <- DBI::dbGetQuery(
        conn,
        "SELECT id, label, category, tags, file_path, hash, source_type, cohort_type, status
         FROM cohort_manifest
         WHERE cohort_type IN ('circe', 'custom')"
      )

      results <- data.frame(
        id     = integer(),
        label  = character(),
        action = character(),
        stringsAsFactors = FALSE
      )

      cli::cli_rule("Syncing Manifest")

      # ── Step 1: Check files already in the manifest ──────────────────────────
      for (i in seq_len(nrow(db_records))) {
        rec        <- db_records[i, ]
        rec_id     <- rec$id
        rec_label  <- rec$label
        rec_status <- rec$status
        file_path  <- rec$file_path

        if (rec_status == "active" && !file.exists(file_path)) {
          # File has gone missing — soft-delete
          DBI::dbExecute(
            conn,
            "UPDATE cohort_manifest SET status = 'deleted', deleted_at = CURRENT_TIMESTAMP WHERE id = ?",
            list(rec_id)
          )
          # Remove from in-memory list
          private$.manifest <- Filter(function(c) c$getId() != rec_id, private$.manifest)
          cli::cli_alert_warning("Missing: {rec_label} (ID {rec_id}) — marked as deleted")
          results <- rbind(results, data.frame(id = rec_id, label = rec_label,
                                                action = "missing_flagged", stringsAsFactors = FALSE))
          next
        }

        if (!file.exists(file_path)) {
          next  # Already deleted/purged record with missing file — skip
        }

        # Recompute hash and compare
        tryCatch({
          tmp_def <- CohortDef$new(
            label = rec_label,
            category = if (!is.na(rec$category) && nchar(rec$category) > 0) rec$category else "derived",
            sourceType = if (!is.na(rec$source_type) && nchar(rec$source_type) > 0) rec$source_type else "derived",
            tags = list(),
            filePath = file_path
          )
          new_hash <- tmp_def$getFileHash()

          if (new_hash != rec$hash) {
            DBI::dbExecute(
              conn,
              "UPDATE cohort_manifest SET hash = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
              list(new_hash, rec_id)
            )
            # Update in-memory entry if present
            for (cohort in private$.manifest) {
              if (cohort$getId() == rec_id) {
                tmp_def$setId(as.integer(rec_id))
                tmp_def$setCohortType(rec$cohort_type)
                if (!is.na(rec$tags) && rec$tags != "") {
                  tmp_def$tags <- jsonlite::fromJSON(rec$tags, simplifyVector = FALSE)
                }
                private$.manifest[[which(sapply(private$.manifest, function(c) c$getId() == rec_id))]] <- tmp_def
                break
              }
            }
            cli::cli_alert_warning("Hash updated: {rec_label} (ID {rec_id})")
            results <- rbind(results, data.frame(id = rec_id, label = rec_label,
                                                  action = "hash_updated", stringsAsFactors = FALSE))

            # Cascade stale to all derived cohorts that depend on this one
            private$cascade_stale_downstream(rec_id)
          } else {
            results <- rbind(results, data.frame(id = rec_id, label = rec_label,
                                                  action = "unchanged", stringsAsFactors = FALSE))
          }
        }, error = function(e) {
          cli::cli_alert_danger("Error checking {rec_label}: {e$message}")
        })
      }

      # ── Step 2: Auto-remove orphaned files not in manifest ──────────────────
      existing_rel <- db_records$file_path
      orphaned_files <- on_disk[!(on_disk_rel %in% existing_rel)]

      if (length(orphaned_files) > 0) {
        if (strict_mode) {
          cli::cli_rule("Removing {length(orphaned_files)} orphaned file(s) from disk")
          
          for (f in orphaned_files) {
            f_rel <- fs::path_rel(f)
            tryCatch({
              unlink(f)
              cli::cli_alert_success("Deleted orphaned file: {f_rel}")
              results <- rbind(results, data.frame(id = NA_integer_, 
                                                    label = tools::file_path_sans_ext(basename(f_rel)),
                                                    action = "auto_removed_orphan", 
                                                    stringsAsFactors = FALSE))
            }, error = function(e) {
              cli::cli_alert_warning("Could not delete orphaned file {f_rel}: {e$message}")
            })
          }
        } else {
          # Warn-only mode (for testing or audit trails)
          cli::cli_alert_warning("{length(orphaned_files)} orphaned file(s) on disk not in manifest:")
          for (f in utils::head(orphaned_files, 5)) {
            f_rel <- fs::path_rel(f)
            cli::cli_bullets(c("!" = "{f_rel}"))
          }
          if (length(orphaned_files) > 5) {
            cli::cli_bullets(c("!" = "... and {length(orphaned_files) - 5} more"))
          }
          cli::cli_alert_info("Set {.code strict_mode = TRUE} to auto-remove these files.")
        }
      }

      # ── Summary ──────────────────────────────────────────────────────────────
      n_hash_updated <- sum(results$action == "hash_updated")
      n_missing <- sum(results$action == "missing_flagged")
      n_orphan_removed <- sum(results$action == "auto_removed_orphan")
      n_same    <- sum(results$action == "unchanged")
      
      cli::cli_rule()
      cli::cli_alert_success(
        "Sync complete — Updated: {n_hash_updated} | Missing: {n_missing} | Orphaned removed: {n_orphan_removed} | Unchanged: {n_same}"
      )

      return(results)
    },

    #' Clean cohort data from the DBMS for deleted manifest entries
    #'
    #' @description
    #' For every cohort with \code{status = 'deleted'} in the SQLite manifest, deletes
    #' the corresponding rows from the DBMS cohort table and checksum table, then marks
    #' the manifest record as \code{status = 'purged'} so it is not processed again.
    #'
    #' @details
    #' Requires that \code{executionSettings} has been set with a valid database connection,
    #' \code{workDatabaseSchema}, and \code{cohortTable}.
    #'
    #' @return Data frame with columns: id, label.
    cleanCohortTable = function() {
      private$validateExecutionSettings()

      settings <- private$.executionSettings
      conn_db <- settings$getConnection()
      if (is.null(conn_db)) {
        settings$connect()
        conn_db <- settings$getConnection()
      }
      on.exit(settings$disconnect())

      cohort_schema <- settings$workDatabaseSchema
      if (is.null(cohort_schema) || is.na(cohort_schema)) {
        cli::cli_abort("workDatabaseSchema must be set in execution settings")
      }

      cohort_table <- settings$cohortTable
      if (is.null(cohort_table) || is.na(cohort_table)) {
        cli::cli_abort("cohortTable must be set in execution settings")
      }

      table_names <- getCohortTableNames(cohortTable = cohort_table)
      checksum_table <- table_names$cohortChecksumTable

      # Get all deleted cohort IDs from SQLite
      conn_sqlite <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn_sqlite), add = TRUE)

      deleted_records <- DBI::dbGetQuery(
        conn_sqlite,
        "SELECT id, label FROM cohort_manifest WHERE status = 'deleted'"
      )

      if (nrow(deleted_records) == 0) {
        cli::cli_alert_info("No deleted cohorts to clean from DBMS")
        return(data.frame(id = integer(), label = character(),
                          stringsAsFactors = FALSE))
      }

      cli::cli_rule("Cleaning Cohort Table")
      cli::cli_alert_info("Purging {nrow(deleted_records)} deleted cohort(s) from DBMS")

      results <- data.frame(
        id               = integer(),
        label            = character(),
        stringsAsFactors = FALSE
      )

      for (i in seq_len(nrow(deleted_records))) {
        rec   <- deleted_records[i, ]
        cid   <- rec$id
        label <- rec$label

        cohort_del <- 0L
        chksum_del <- 0L

        # Delete from cohort table
        tryCatch({
          del_sql <- SqlRender::translate(
            SqlRender::render(
              "DELETE FROM @schema.@table WHERE cohort_definition_id = @id;",
              schema = cohort_schema, table = cohort_table, id = cid
            ),
            targetDialect = settings$getDbms()
          )
          DatabaseConnector::executeSql(conn_db, del_sql,
                                        progressBar = FALSE, reportOverallTime = FALSE)
          # Approximate rows deleted via cohort counts query
          count_sql <- SqlRender::translate(
            SqlRender::render(
              "SELECT COUNT(*) AS n FROM @schema.@table WHERE cohort_definition_id = @id;",
              schema = cohort_schema, table = cohort_table, id = cid
            ),
            targetDialect = settings$getDbms()
          )
          cohort_del <- 0L  # rows already gone; record as 0 post-delete
        }, error = function(e) {
          cli::cli_alert_danger("Failed to clean cohort table for ID {cid}: {e$message}")
        })

        # Delete from checksum table
        tryCatch({
          chk_sql <- SqlRender::translate(
            SqlRender::render(
              "DELETE FROM @schema.@table WHERE cohort_definition_id = @id;",
              schema = cohort_schema, table = checksum_table, id = cid
            ),
            targetDialect = settings$getDbms()
          )
          DatabaseConnector::executeSql(conn_db, chk_sql,
                                        progressBar = FALSE, reportOverallTime = FALSE)
          chksum_del <- 0L
        }, error = function(e) {
          cli::cli_alert_danger("Failed to clean checksum table for ID {cid}: {e$message}")
        })

        # Mark as purged in SQLite
        DBI::dbExecute(
          conn_sqlite,
          "UPDATE cohort_manifest SET status = 'purged', deleted_at = CURRENT_TIMESTAMP WHERE id = ?",
          list(cid)
        )

        cli::cli_alert_success("Purged cohort {cid}: {label}")
        results <- rbind(results, data.frame(
          id               = cid,
          label            = label,
          stringsAsFactors = FALSE
        ))
      }

      cli::cli_rule()
      cli::cli_alert_success("Purged {nrow(results)} cohort(s) from DBMS")

      return(results)
    },

    #' @description
    #' Generates cohorts in the manifest in the target database using the execution settings.
    #' Checks dependency ordering and regenerates dependent cohorts when parents change.
    #' Checks the hash of each cohort definition and skips generation if the hash matches what's
    #' already stored in the cohort_checksum table. If hashes differ or the cohort is not yet in
    #' the checksum table, regenerates and updates the hash.
    #'
    #' @details
    #' Execution flow:
    #' 1. Build dependency graph from all CohortDef objects
    #' 2. Validate no circular dependencies (error if found)
    #' 3. Topologically sort cohorts by dependencies (parents before children)
    #' 4. For each cohort in topological order:
    #'    - circe cohorts: check SQL hash (existing logic)
    #'    - dependent cohorts: compute dependency hash from parent hashes + rule
    #' 5. Render and execute SQL (circe uses SqlRender parameters, dependent uses metadata JSON)
    #' 6. Record checksums and dependency hashes in database
    #' 7. Report results with cohort_type, depends_on, dependency_status columns
    #'
    #' Requires that executionSettings has been set and includes:
    #' - A database connection (via getConnection()
    #' - cdmDatabaseSchema (where the OMOP CDM data resides)
    #' - workDatabaseSchema (where cohort results are written)
    #' - cohortTable (destination table name)
    #' - tempEmulationSchema if needed for the database platform
    #'
    #' @return Data frame with execution results including:
    #'   - cohort_id: ID of the generated cohort
    #'   - label: Label of the cohort
    #'   - cohort_type: 'circe', 'subset', 'union', or 'complement'
    #'   - depends_on: Comma-separated parent cohort IDs (empty for circe cohorts)
    #'   - execution_time_min: Time taken to generate (0 for skipped)
    #'   - status: 'Success', 'Skipped - already generated', 'Dependency skipped', or error message
    #'   - dependency_status: 'Not applicable' for circe, 'Parent changed' or 'Unchanged' for dependent
    executeCohortGeneration = function() {

      # ==== Prep Execution Settings ===== #
      # Validate execution settings are available
      private$validateExecutionSettings()

      # Get connection
      settings <- private$.executionSettings
      conn <- settings$getConnection()
      if (is.null(conn)) {
        settings$connect()
        conn <- settings$getConnection()
      }
      on.exit(settings$disconnect())

      # get dbms
      dbms <- settings$getDbms()

      # Get checksum table name
      table_names <- getCohortTableNames(cohortTable = settings$cohortTable)
      checksum_table <- table_names$cohortChecksumTable

      cli::cli_rule("Generating Cohorts")
      cli::cli_alert_info("Database: {settings$databaseName}")
      cli::cli_alert_info("CDM Schema: {settings$cdmDatabaseSchema}")
      cli::cli_alert_info("Cohort Schema: {settings$workDatabaseSchema}")
      cli::cli_alert_info("Cohort Table: {settings$cohortTable}")
      cli::cli_alert_info("Generating {length(private$.manifest)} cohorts...\n")

      # ==== Check DEPENDENCY GRAPH BUILDING & INITIALIZE ===== #
      # Build dependency graph
      dependency_graph <- build_dependency_graph(dbPath = private$.dbPath)
      # Validate no circular dependencies
      validate_no_cycles(dependency_graph)
      # Get topological sort (execution order: parents before children)
      sorted_cohort_ids <- topological_sort(dependency_graph)
      cli::cli_alert_info("Execution order determined by dependencies")

      # Initialize results data frame with enhanced columns
      results_df <- data.frame(
        cohort_id = integer(),
        label = character(),
        cohort_type = character(),
        depends_on = character(),
        execution_time_min = numeric(),
        status = character(),
        dependency_status = character(),
        stringsAsFactors = FALSE
      )

      # Cache for storing hashes of each cohort (used for computing dependency hashes)
      cohort_hashes <- list()

      # Open SQLite connection once for dependency lookups inside the loop
      sqlite_conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(sqlite_conn), add = TRUE)
      # see if checksum table is empty
      is_checksum_empty <- is_the_checksum_empty(
        db_conn = conn,
        cohort_schema = settings$workDatabaseSchema,
        checksum_table = checksum_table
      )

      # ===== START LOOP ========= #
      # Generate each cohort in topological order
      for (idx in seq_along(sorted_cohort_ids)) {

        # grab cohorts one at a time
        cohort_id <- sorted_cohort_ids[idx]
        cohort <- self$getCohortById(cohort_id)
        cohort_label <- cohort$label
        cohort_type <- cohort$getCohortType()

        if (is.null(cohort)) {
          cli::cli_alert_danger("Cohort {cohort_id} not found in manifest")
          next
        }

        ## Phase 1: Check Skip Status

        # get skip info
        skip_info <- evaluate_cohort_skip_status(
          cohort = cohort,
          sqlite_conn = sqlite_conn,
          cohort_schema = settings$workDatabaseSchema,
          checksum_table = checksum_table,
          conn = conn,
          is_checksum_empty = is_checksum_empty,
          cohort_hashes = cohort_hashes,
          dbPath = private$.dbPath
        )
        # resolve if should skip
        if (skip_info$should_skip) {
          cli::cli_alert_info("Skipping cohort {cohort_id}: {cohort_label} ({cohort_type})")
          new_row <- data.frame(
            cohort_id = cohort_id, 
            label = cohort_label, 
            cohort_type = cohort_type,
            depends_on = skip_info$depends_on_str, 
            execution_time_min = 0,
            status = "Skipped - already generated",
            dependency_status = skip_info$dependency_status,
            stringsAsFactors = FALSE
          )
          results_df <- rbind(results_df, new_row)
          if (cohort_type %in% c("circe", "custom")) {
            cohort_hashes[[as.character(cohort_id)]] <- cohort$getHash()
          } else {
            cohort_hashes[[as.character(cohort_id)]] <- compute_dependency_hash(
              private$.dbPath, cohort, cohort_hashes
            )
          }
          next
        }

        ## Phase 2: Generate Single Cohort

        # Generate the cohort
        cli::cli_alert_info("Generating cohort {cohort_id}: {cohort_label} ({cohort_type})...")
        result <- generate_single_cohort(
          cohort = cohort, 
          cohort_id = cohort_id,
          db_conn = conn, 
          settings = settings,
          table_names = table_names, 
          sqlite_conn = sqlite_conn,
          is_stale = skip_info$is_stale, 
          stored_hash = skip_info$stored_hash,
          cohort_hashes = cohort_hashes, 
          dbPath = private$.dbPath
        )

        cohort_hashes <- result$cohort_hashes
        results_df <- rbind(results_df, result$result_row)
        if (grepl("^Error:", result$result_row$status)) {
          if (idx < length(sorted_cohort_ids)) {
            for (j in (idx + 1):length(sorted_cohort_ids)) {
              rem_id <- sorted_cohort_ids[j]
              rem_cohort <- self$getCohortById(rem_id)
              if (!is.null(rem_cohort)) {
                results_df <- rbind(results_df, data.frame(
                  cohort_id = rem_id, label = rem_cohort$label,
                  cohort_type = rem_cohort$getCohortType(),
                  depends_on = "", execution_time_min = NA_real_,
                  status = "Not generated", dependency_status = "Not applicable",
                  stringsAsFactors = FALSE))
              }
            }
          }
          cli::cli_alert_info("Stopping cohort generation due to error at cohort {cohort_id}")
          break
        }
      }
      # Step 3: report result 
      res <- report_cohort_results(results_df)
      return(res)
        
    },

    #' @description Retrieve cohort counts from the database
    #'
    #' Retrieves entry and subject counts for cohorts from the cohort table in the target database.
    #' Can retrieve counts for all cohorts or a specific subset. Enriches the results with metadata
    #' (label and tags) from the CohortDef objects in the manifest.
    #'
    #' @param cohortIds Integer vector. Optional. Specific cohort IDs to retrieve counts for.
    #'   If NULL (default), returns counts for all cohorts.
    #'
    #' @return Data frame with columns:
    #'   - cohort_id: The cohort definition ID
    #'   - label: The cohort label from the CohortDef object
    #'   - tags: The cohort tags formatted as a string
    #'   - cohort_entries: Total number of cohort records
    #'   - cohort_subjects: Number of distinct subjects in the cohort
    #'
    retrieveCohortCounts = function(cohortIds = NULL) {
      # Validate execution settings are available
      private$validateExecutionSettings()

      # Get connection
      settings <- private$.executionSettings
      conn <- settings$getConnection()
      if (is.null(conn)) {
        settings$connect()
        conn <- settings$getConnection()
      }
      on.exit(settings$disconnect())

      # Get execution parameters
      cohort_schema <- settings$workDatabaseSchema
      if (is.null(cohort_schema) || is.na(cohort_schema)) {
        stop("workDatabaseSchema must be set in execution settings")
      }

      cohort_table <- settings$cohortTable
      if (is.null(cohort_table) || is.na(cohort_table)) {
        stop("cohortTable must be set in execution settings")
      }

      dbms <- settings$getDbms()

      # Build SQL query
      # When cohortIds is NULL, retrieve counts for ALL cohort IDs in the table
      where_clause <- ""
      if (!is.null(cohortIds)) {
        checkmate::assert_integerish(cohortIds)
        cohort_ids_str <- paste0(cohortIds, collapse = ", ")
        where_clause <- paste0("\n        WHERE cohort_definition_id IN (", cohort_ids_str, ")")
      } else {
        # Explicitly retrieve all cohort IDs from the table
        cli::cli_alert_info("Retrieving counts for all cohorts in {cohort_table}")
      }

      sql <- paste0(
        "SELECT
          cohort_definition_id AS cohort_id,
          COUNT(*) AS cohort_entries,
          COUNT(DISTINCT subject_id) AS cohort_subjects
        FROM ", cohort_schema, ".", cohort_table, where_clause, "
        GROUP BY cohort_definition_id
        ORDER BY cohort_definition_id"
      )

      # Execute query
      tryCatch({
        results <- DatabaseConnector::querySql(conn, sql)
        
        # Convert column names to lowercase for consistency
        colnames(results) <- tolower(colnames(results))
        
        # Ensure proper data types
        results$cohort_id <- as.integer(results$cohort_id)
        results$cohort_entries <- as.integer(results$cohort_entries)
        results$cohort_subjects <- as.integer(results$cohort_subjects)
        
        # Initialize columns for metadata
        results$label <- character(nrow(results))
        results$tags <- character(nrow(results))
        
        # Join metadata from CohortDef objects
        for (i in seq_len(nrow(results))) {
          cohort_id <- results$cohort_id[i]
          cohort <- self$getCohortById(cohort_id)
          if (!is.null(cohort)) {
            results$label[i] <- cohort$label
            results$tags[i] <- cohort$formatTagsAsString()
          }
        }
        
        # Reorder columns: cohort_id, label, tags, cohort_entries, cohort_subjects
        results <- results[, c("cohort_id", "label", "tags", "cohort_entries", "cohort_subjects")]
        
        return(results)
      }, error = function(e) {
        cli::cli_alert_danger("Failed to retrieve cohort counts: {e$message}")
        return(NULL)
      })
    },

    #' @description Validate manifest and return status of all cohorts
    #'
    #' @return A tibble with columns: id, label, status (active/missing/deleted), deleted_at, file_exists
    validateManifest = function() {
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))
      
      # Get all cohorts from database (including deleted ones)
      db_records <- tryCatch({
        DBI::dbGetQuery(
          conn,
          "SELECT id, label, filePath, status, deleted_at FROM cohort_manifest ORDER BY id"
        )
      }, error = function(e) {
        cli::cli_alert_danger("Failed to query manifest: {e$message}")
        return(data.frame())
      })
      
      if (nrow(db_records) == 0) {
        return(tibble::tibble(id = integer(), label = character(), status = character(), 
                              deleted_at = character(), file_exists = logical()))
      }
      
      # Add file_exists column
      db_records$file_exists <- sapply(db_records$filePath, file.exists)
      
      # Convert to tibble and select columns
      result <- tibble::tibble(
        id = db_records$id,
        label = db_records$label,
        status = db_records$status,
        deleted_at = db_records$deleted_at,
        file_exists = db_records$file_exists
      )
      
      return(result)
    },

    #' @description Get summary status of manifest
    #'
    #' @return List with elements: active_count, missing_count, deleted_count, next_available_id
    getManifestStatus = function() {
      status_df <- self$validateManifest()
      
      if (nrow(status_df) == 0) {
        return(list(
          active_count = 0L,
          missing_count = 0L,
          deleted_count = 0L,
          next_available_id = 1L
        ))
      }
      
      active_count <- sum(status_df$status == "active", na.rm = TRUE)
      missing_count <- sum(status_df$status == "active" & !status_df$file_exists, na.rm = TRUE)
      deleted_count <- sum(status_df$status == "deleted", na.rm = TRUE)
      next_id <- max(status_df$id, na.rm = TRUE) + 1L
      
      return(list(
        active_count = active_count,
        missing_count = missing_count,
        deleted_count = deleted_count,
        next_available_id = next_id
      ))
    },

    #' @description Delete a cohort from manifest and file system
    #'
    #' Marks a cohort as deleted in the manifest and removes its file from the file 
    #' system (json/ or sql/ directory). The SQLite record is preserved with 
    #' status='deleted' for audit trail purposes.
    #' 
    #' When a manifest is loaded, only active cohorts are loaded into memory.
    #' This enforces strict 1:1 correspondence between active manifest entries
    #' and files on disk.
    #'
    #' @param id Integer. The cohort ID to delete.
    #' @param confirm Logical. If FALSE (default), prompts for interactive confirmation.
    #'   Pass TRUE to skip the prompt (suitable for scripts).
    #' @param dropFromDBMS Logical. If TRUE, also deletes the cohort from the DBMS
    #'   cohort table and checksum table. Requires `executionSettings` to be set.
    #'   Default: FALSE (filesystem/manifest cleanup only).
    #'
    #' @return Invisible NULL.
    deleteCohort = function(id, confirm = FALSE, dropFromDBMS = FALSE) {
      checkmate::assert_int(id)
      checkmate::assert_flag(confirm)
      checkmate::assert_flag(dropFromDBMS)
      
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))
      
      # Retrieve cohort record
      cohort_row <- DBI::dbGetQuery(
        conn,
        "SELECT id, label, file_path FROM cohort_manifest WHERE id = ?",
        list(id)
      )

      if (nrow(cohort_row) == 0) {
        cli::cli_alert_danger("Cohort {id} not found in manifest")
        invisible(NULL)
      }
      
      label     <- cohort_row$label[1]
      file_path <- cohort_row$file_path[1]
      status    <- cohort_row$status[1]

       # Validate DBMS requirements if requested
      if (dropFromDBMS && is.null(private$.executionSettings)) {
        cli::cli_abort(c(
          "dropFromDBMS = TRUE requires executionSettings.",
          i = "Call {.code $setExecutionSettings()} first."
        ))
      }

       # Build confirmation message
      if (dropFromDBMS) {
        extra_msg <- " and DBMS tables"
      }  else {
        extra_msg <- ""
      }

      # Request confirmation if not already confirmed
      if (!confirm) {
        cli::cli_alert_warning(
          "This will permanently delete cohort {id} ({label}) from the manifest and file system."
        )
        response <- readline("Type 'yes' to confirm: ")
        if (!grepl("^yes$", trimws(tolower(response)))) {
          cli::cli_alert_info("Cancelled.")
          return(invisible(NULL))
        }
      }

      # Delete file from disk if it exists and path is not empty
      file_deleted <- FALSE
      if (!is.na(file_path) && nchar(trimws(file_path)) > 0 && file.exists(file_path)) {
        tryCatch({
          unlink(file_path)
          cli::cli_alert_success("Deleted file: {file_path}")
          file_deleted <- TRUE
        }, error = function(e) {
          cli::cli_alert_warning("Could not delete file {file_path}: {e$message}")
        })
      } else if (is.na(file_path) || nchar(trimws(file_path)) == 0) {
        # Derived cohorts or special cases with no file_path
        cli::cli_alert_info("No file to delete (derived or special cohort)")
      } else if (!file.exists(file_path)) {
        cli::cli_alert_warning("File not found on disk: {file_path} (manifest will be cleaned)")
      }

      # Mark as deleted in SQLite (soft delete with audit trail)
      tryCatch({
        DBI::dbExecute(
          conn,
          "UPDATE cohort_manifest SET status = 'deleted', deleted_at = CURRENT_TIMESTAMP WHERE id = ?",
          list(id)
        )
      }, error = function(e) {
        cli::cli_alert_danger("Failed to mark cohort as deleted: {e$message}")
        return(invisible(NULL))
      })


    # Remove from DBMS cohort table and checksum table if requested
      if (dropFromDBMS) {
        settings    <- private$.executionSettings
        conn_db     <- settings$getConnection()
        if (is.null(conn_db)) {
          settings$connect()
          conn_db <- settings$getConnection()
        }
        on.exit(settings$disconnect(), add = TRUE)

        cohort_schema  <- settings$workDatabaseSchema
        cohort_table   <- settings$cohortTable
        checksum_table <- getCohortTableNames(cohortTable = cohort_table)$cohortChecksumTable
        dbms           <- settings$getDbms()

        tryCatch({
          del_sql <- SqlRender::translate(
            SqlRender::render(
              "DELETE FROM @schema.@table WHERE cohort_definition_id = @id;",
              schema = cohort_schema, table = cohort_table, id = id
            ),
            targetDialect = dbms
          )
          DatabaseConnector::executeSql(conn_db, del_sql, progressBar = FALSE, reportOverallTime = FALSE)
          cli::cli_alert_success("Removed cohort {id} from {cohort_schema}.{cohort_table}")
        }, error = function(e) {
          cli::cli_alert_warning("Could not remove from cohort table: {e$message}")
        })

        tryCatch({
          chk_sql <- SqlRender::translate(
            SqlRender::render(
              "DELETE FROM @schema.@table WHERE cohort_definition_id = @id;",
              schema = cohort_schema, table = checksum_table, id = id
            ),
            targetDialect = dbms
          )
          DatabaseConnector::executeSql(conn_db, chk_sql, progressBar = FALSE, reportOverallTime = FALSE)
          cli::cli_alert_success("Removed cohort {id} from {cohort_schema}.{checksum_table}")
        }, error = function(e) {
          cli::cli_alert_warning("Could not remove from checksum table: {e$message}")
        })
      }
      # Remove from in-memory manifest TODO
      cli::cli_alert_success("Marked cohort {id}: {label} as deleted (file removed from disk{extra_msg})")
      invisible(NULL)
    },

    #' @description Clean up missing cohorts from manifest
    #'
    #' @param keep_trace Logical. If TRUE, marks missing as deleted with timestamp (soft delete).
    #'   If FALSE, permanently removes from database (hard delete). Defaults to TRUE.
    #'
    #' @description Build a cohort of outcome events with prior target exposure
    #'
    #' Creates a derived cohort based on the temporal relationship between an
    #' outcome cohort and a target (exposure) cohort. Filters outcome events that
    #' have (or lack) a prior target event, optionally within a time window.
    #'
    #' @param label Character. Display name (e.g., "GI Bleed - Prior NSAID").
    #' @param category Character. Required classification.
    #' @param tags Named list. Optional metadata tags.
    #' @param outcomeCohortId Integer. The cohort definition ID for the outcome
    #'   (e.g., GI bleed).
    #' @param targetCohortId Integer. The cohort definition ID for the target
    #'   (e.g., NSAID use).
    #' @param mode Character. One of 'prior' or 'no_prior':
    #'   - 'prior': Retain outcome events where a prior target event exists.
    #'   - 'no_prior': Retain outcome events where no prior target event exists.
    #'   Default: 'prior'.
    #' @param priorTimeWindowDays Integer or NULL. If provided (e.g., 365), only
    #'   consider target events within this many days before the outcome start.
    #'   NULL or 0 means all time. Default: NULL.
    #' @param subsetLimit Character. One of 'First', 'Last', or 'All'. Controls
    #'   which prior target event anchors the match when multiple exist:
    #'   - 'First': Keep the earliest prior target event (default).
    #'   - 'Last': Keep the most recent prior target event.
    #'   - 'All': Keep all prior target events (one output row per pair).
    #'   Default: 'First'.
    #'
    #' @return Invisible integer. The assigned cohort ID.
    buildOPriorT = function(
      label,
      category,
      tags = list(),
      outcomeCohortId,
      targetCohortId,
      mode = "prior",
      priorTimeWindowDays = NULL,
      subsetLimit = "First"
    ) {
      checkmate::assert_string(label, min.chars = 1)
      checkmate::assert_string(category, min.chars = 1)
      checkmate::assert_list(tags, names = "named")
      checkmate::assert_int(outcomeCohortId)
      checkmate::assert_int(targetCohortId)
      checkmate::assert_choice(mode, choices = c("prior", "no_prior"))
      checkmate::assert_integerish(priorTimeWindowDays, len = 1, null.ok = TRUE)
      checkmate::assert_choice(subsetLimit, choices = c("First", "Last", "All"))

      private$validate_label_unique(label)
      private$validate_parent_cohorts_exist(c(outcomeCohortId, targetCohortId))

      dependency_rule <- list(
        outcomeCohortId = as.integer(outcomeCohortId),
        targetCohortId = as.integer(targetCohortId),
        mode = mode,
        priorTimeWindowDays = if (!is.null(priorTimeWindowDays)) as.integer(priorTimeWindowDays) else NULL,
        subsetLimit = subsetLimit
      )

      derived_dir <- make_derived_folder(dirname(private$.dbPath))
      sql_path <- write_derived_template(derived_dir, label, "createOPriorT.sql",
        outcome_cohort_id = outcomeCohortId,
        target_cohort_id = targetCohortId,
        mode = mode,
        use_prior_time_window = !is.null(priorTimeWindowDays),
        prior_time_window_days = if (is.null(priorTimeWindowDays)) 0L else as.integer(priorTimeWindowDays),
        subset_limit = subsetLimit
      )

      cohort_id <- private$insert_cohort(
        label = label,
        category = category,
        tags = tags,
        file_path = fs::path_rel(sql_path),
        source_type = "derived",
        cohort_type = "oprior",
        depends_on = as.integer(c(outcomeCohortId, targetCohortId)),
        dependency_rule = dependency_rule
      )

      cli::cli_alert_success("Built O-prior-T cohort {cohort_id}: {label} ({mode})")
      invisible(cohort_id)
    },

    #' @description Build a cohort of target events with prior outcome occurrence
    #'
    #' Creates a derived cohort based on the temporal relationship between a
    #' target (exposure) cohort and an outcome cohort. Filters target events that
    #' have (or lack) a prior outcome event, optionally within a time window.
    #'
    #' This is the reverse direction of \code{buildOPriorT()}: instead of
    #' filtering outcome by prior target, filter target by prior outcome.
    #'
    #' @param label Character. Display name (e.g., "NSAID - Prior GI Bleed").
    #' @param category Character. Required classification.
    #' @param tags Named list. Optional metadata tags.
    #' @param targetCohortId Integer. The cohort definition ID for the target
    #'   (e.g., NSAID use).
    #' @param outcomeCohortId Integer. The cohort definition ID for the outcome
    #'   (e.g., GI bleed).
    #' @param mode Character. One of 'prior' or 'no_prior':
    #'   - 'prior': Retain target events where a prior outcome exists.
    #'   - 'no_prior': Retain target events where no prior outcome exists.
    #'   Default: 'prior'.
    #' @param priorTimeWindowDays Integer or NULL. If provided (e.g., 365), only
    #'   consider outcome events within this many days before the target start.
    #'   NULL or 0 means all time. Default: NULL.
    #' @param subsetLimit Character. One of 'First', 'Last', or 'All'. Controls
    #'   which prior outcome event anchors the match when multiple exist:
    #'   - 'First': Keep the earliest prior outcome event (default).
    #'   - 'Last': Keep the most recent prior outcome event.
    #'   - 'All': Keep all prior outcome events (one output row per pair).
    #'   Default: 'First'.
    #'
    #' @return Invisible integer. The assigned cohort ID.
    buildTPriorO = function(
      label,
      category,
      tags = list(),
      targetCohortId,
      outcomeCohortId,
      mode = "prior",
      priorTimeWindowDays = NULL,
      subsetLimit = "First"
    ) {
      checkmate::assert_string(label, min.chars = 1)
      checkmate::assert_string(category, min.chars = 1)
      checkmate::assert_list(tags, names = "named")
      checkmate::assert_int(targetCohortId)
      checkmate::assert_int(outcomeCohortId)
      checkmate::assert_choice(mode, choices = c("prior", "no_prior"))
      checkmate::assert_integerish(priorTimeWindowDays, len = 1, null.ok = TRUE)
      checkmate::assert_choice(subsetLimit, choices = c("First", "Last", "All"))

      private$validate_label_unique(label)
      private$validate_parent_cohorts_exist(c(targetCohortId, outcomeCohortId))

      dependency_rule <- list(
        targetCohortId = as.integer(targetCohortId),
        outcomeCohortId = as.integer(outcomeCohortId),
        mode = mode,
        priorTimeWindowDays = if (!is.null(priorTimeWindowDays)) as.integer(priorTimeWindowDays) else NULL,
        subsetLimit = subsetLimit
      )

      derived_dir <- make_derived_folder(dirname(private$.dbPath))
      sql_path <- write_derived_template(derived_dir, label, "createTPriorO.sql",
        target_cohort_id = targetCohortId,
        outcome_cohort_id = outcomeCohortId,
        mode = mode,
        use_prior_time_window = !is.null(priorTimeWindowDays),
        prior_time_window_days = if (is.null(priorTimeWindowDays)) 0L else as.integer(priorTimeWindowDays),
        subset_limit = subsetLimit
      )

      cohort_id <- private$insert_cohort(
        label = label,
        category = category,
        tags = tags,
        file_path = fs::path_rel(sql_path),
        source_type = "derived",
        cohort_type = "tprior",
        depends_on = as.integer(c(targetCohortId, outcomeCohortId)),
        dependency_rule = dependency_rule
      )

      cli::cli_alert_success("Built T-prior-O cohort {cohort_id}: {label} ({mode})")
      invisible(cohort_id)
    },

    #' @description Censor a target cohort based on a censoring event
    #'
    #' Truncates the cohort_end_date of each target cohort record to the earliest
    #' censoring event that occurs between the cohort_start_date and cohort_end_date.
    #' If no censoring event occurs, the original cohort_end_date is preserved.
    #'
    #' Typical use cases:
    #' - Censor a drug exposure cohort at the date of death
    #' - Censor a disease cohort at the date of disease exacerbation
    #' - Censor a treatment cohort at the date of a procedure (e.g., surgery)
    #'
    #' @param label Character. Display name (e.g., "NSAID Use - Censored at Death").
    #' @param category Character. Required classification.
    #' @param tags Named list. Optional metadata tags.
    #' @param targetCohortId Integer. The cohort definition ID for the cohort to censor.
    #' @param censorCohortId Integer. The cohort definition ID for the censoring event.
    #'
    #' @return Invisible integer. The assigned cohort ID.
    buildCensorCohort = function(
      label,
      category,
      tags = list(),
      targetCohortId,
      censorCohortId
    ) {
      checkmate::assert_string(label, min.chars = 1)
      checkmate::assert_string(category, min.chars = 1)
      checkmate::assert_list(tags, names = "named")
      checkmate::assert_int(targetCohortId)
      checkmate::assert_int(censorCohortId)

      private$validate_label_unique(label)
      private$validate_parent_cohorts_exist(c(targetCohortId, censorCohortId))

      dependency_rule <- list(
        targetCohortId = as.integer(targetCohortId),
        censorCohortId = as.integer(censorCohortId)
      )
      # make and check derived folder
      derived_dir <- make_derived_folder(dirname(private$.dbPath))

      # make rendered sql
      sql_path <- write_derived_template (
        derived_dir = derived_dir,
        label = label,
        template_name = "createCensorCohort.sql",
        target_cohort_id = targetCohortId,
        censor_cohort_id = censorCohortId
      )

      cohort_id <- private$insert_cohort(
        label = label,
        category = category,
        tags = tags,
        file_path = fs::path_rel(sql_path),
        source_type = "derived",
        cohort_type = "censor",
        depends_on = as.integer(c(targetCohortId, censorCohortId)),
        dependency_rule = dependency_rule
      )

      cli::cli_alert_success("Built censor cohort {cohort_id}: {label}")
      invisible(cohort_id)
    },
    #' @description clean up missing files from manifest
    #' @param keep_trace Logical. soft delete with trace
    #' @return Invisibly returns NULL. Displays summary of cleanup actions.
    cleanupMissing = function(keep_trace = TRUE) {
      status_df <- self$validateManifest()
      
      # Find missing active cohorts (file doesn't exist but status is active)
      missing_mask <- status_df$status == "active" & !status_df$file_exists
      missing_cohorts <- status_df[missing_mask, ]
      
      if (nrow(missing_cohorts) == 0) {
        cli::cli_alert_success("No missing cohorts to clean up")
        invisible(NULL)
      }
      
      cli::cli_rule("Cleaning Up Missing Cohorts")
      cli::cli_alert_info("Found {nrow(missing_cohorts)} missing cohort file(s)")
      
      for (i in seq_len(nrow(missing_cohorts))) {
        cohort_id <- missing_cohorts$id[i]
        label <- missing_cohorts$label[i]
        
        if (keep_trace) {
          self$deleteCohort(cohort_id, reason = "missing file")
        } else {
          self$removeCohort(cohort_id, deleteFile = FALSE, confirm = TRUE)
        }
      }
      
      cleanup_method <- ifelse(keep_trace, "soft deleted (with trace)", "hard deleted (permanently)")
      cli::cli_alert_success("Cleanup complete: {nrow(missing_cohorts)} cohort(s) {cleanup_method}")
      
      invisible(NULL)
    }
  )
)
