#' ConceptSetManifest R6 Class
#'
#' An R6 class that manages a collection of ConceptSetDef objects and maintains
#' metadata in a SQLite database.
#'
#' @details
#' The ConceptSetManifest class manages multiple concept set definitions and stores their
#' metadata in a SQLite database located at inputs/conceptSets/conceptSetManifest.sqlite.
#' Each ConceptSetDef is assigned a sequential ID based on its position in the manifest.
#'
#' @param dbPath Character. Path to the SQLite database file. Defaults to
#'   \code{"inputs/conceptSets/conceptSetManifest.sqlite"}.
#'
#' @export
ConceptSetManifest <- R6::R6Class(
  classname = "ConceptSetManifest",
  private = list(
    .manifest = NULL,
    .dbPath = NULL,
    .executionSettings = NULL,
    .atlasConnection = NULL,

    # Initialize the SQLite database schema (creates if needed, migrates if upgrading)
    init_manifest = function(dbPath) {
      # Create directory if it doesn't exist
      dbDir <- dirname(dbPath)
      if (!dir.exists(dbDir)) {
        dir.create(dbDir, recursive = TRUE, showWarnings = FALSE)
      }

      conn <- DBI::dbConnect(RSQLite::SQLite(), dbPath)
      on.exit(DBI::dbDisconnect(conn))

      # Create concept set table if it doesn't exist
      DBI::dbExecute(
        conn,
        "CREATE TABLE IF NOT EXISTS concept_set_manifest (
          id INTEGER PRIMARY KEY,
          label TEXT NOT NULL,
          category TEXT NOT NULL,
          tags TEXT,
          file_path TEXT NOT NULL,
          hash TEXT NOT NULL,
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
          ON concept_set_manifest(label) WHERE status = 'active'"
      )

      DBI::dbExecute(
        conn,
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_filepath_active
          ON concept_set_manifest(file_path) WHERE status = 'active'"
      )

      # Run schema migration to add missing columns if upgrading
      private$migrate_schema(conn)
    },

    # Load active concept sets from SQLite into the in-memory manifest list
    load_manifest_from_db = function() {
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      db_records <- DBI::dbGetQuery(
        conn,
        "SELECT id, label, category, tags, file_path, hash FROM concept_set_manifest WHERE status = 'active' ORDER BY id"
      )

      private$.manifest <- list()

      if (nrow(db_records) == 0) {
        invisible(NULL)
      }

      for (i in seq_len(nrow(db_records))) {
        rec <- db_records[i, ]
        file_path <- private$resolve_file_path(rec$file_path)

        if (!file.exists(file_path)) {
          cli::cli_alert_warning("Concept set file missing, skipping: {rec$label} ({rec$file_path})")
          next
        }

        tryCatch({
          cs_def <- ConceptSetDef$new(label = rec$label, filePath = file_path, category = rec$category)
          cs_def$setId(as.integer(rec$id))

          if (!is.na(rec$tags) && nchar(rec$tags) > 0) {
            cs_def$tags <- jsonlite::fromJSON(rec$tags, simplifyVector = FALSE)
          }

          private$.manifest[[length(private$.manifest) + 1]] <- cs_def
        }, error = function(e) {
          cli::cli_alert_danger("Error loading concept set {rec$label}: {e$message}")
        })
      }

      invisible(NULL)
    },

    # Insert a new concept set record into SQLite and refresh the in-memory manifest
    insert_concept_set = function(label, category, tags, file_path) {
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      # Auto-increment ID (never reuse IDs, even for deleted rows)
      max_id_result <- DBI::dbGetQuery(conn, "SELECT MAX(id) as max_id FROM concept_set_manifest")
      next_id <- if (is.na(max_id_result$max_id[1])) 1L else as.integer(max_id_result$max_id[1]) + 1L

      # Compute hash from file content
      hash <- if (file.exists(file_path)) {
        rlang::hash(readr::read_file(file_path))
      } else {
        rlang::hash(label)
      }

      # Serialize tags to JSON
      tags_json <- if (length(tags) > 0) {
        jsonlite::toJSON(tags, auto_unbox = TRUE)
      } else {
        NA_character_
      }

      rel_path <- fs::path_rel(file_path)

      DBI::dbExecute(
        conn,
        "INSERT INTO concept_set_manifest (id, label, category, tags, file_path, hash, status,created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
        list(next_id, label, category, tags_json, rel_path, hash)
      )

      private$load_manifest_from_db()
      return(next_id)
    },

    # Suggest source vocabularies based on domain
    suggest_source_vocabs_for_domain = function(domain) {
      vocab_map <- list(
        condition_occurrence = c("ICD10CM", "ICD9CM"),
        procedure = c("HCPCS", "CPT4"),
        measurement = c("LOINC"),
        drug_exposure = c("NDC"),
        observation = c("ICD9CM", "ICD10CM", "HCPCS", "CPT4", "LOINC", "NDC"),
        device_exposure = c("NDC"),
        visit_occurrence = c("ICD10CM", "ICD9CM", "HCPCS", "CPT4"),
        init = c("ICD10CM")
      )
      
      if (domain %in% names(vocab_map)) {
        return(vocab_map[[domain]])
      } else {
        return(NULL)
      }
    },

    # Schema migration: add status and deleted_at columns if they don't exist
    # TODO remove in more stable version of picard
    migrate_schema = function(conn) {
      # Check if status column exists
      schema_info <- DBI::dbGetQuery(conn, "PRAGMA table_info(concept_set_manifest)")
      col_names <- schema_info$name
      
      if (!("status" %in% col_names)) {
        tryCatch({
          DBI::dbExecute(conn, "ALTER TABLE concept_set_manifest ADD COLUMN status TEXT DEFAULT 'active'")
          cli::cli_alert_success("Schema migration: Added 'status' column")
        }, error = function(e) {
          cli::cli_alert_warning("Schema migration for status column failed: {e$message}")
        })
      }
      
      if (!("deleted_at" %in% col_names)) {
        tryCatch({
          DBI::dbExecute(conn, "ALTER TABLE concept_set_manifest ADD COLUMN deleted_at DATETIME DEFAULT NULL")
          cli::cli_alert_success("Schema migration: Added 'deleted_at' column")
        }, error = function(e) {
          cli::cli_alert_warning("Schema migration for deleted_at column failed: {e$message}")
        })
      }
      
      if (!("category" %in% col_names)) {
        tryCatch({
          DBI::dbExecute(conn, "ALTER TABLE concept_set_manifest ADD COLUMN category TEXT NOT NULL DEFAULT 'init'")
          cli::cli_alert_success("Schema migration: Added 'category' column")
        }, error = function(e) {
          cli::cli_alert_warning("Schema migration for category column failed: {e$message}")
        })
      }
    },

    # Resolve a stored (potentially relative) file path to an absolute path.
    # Stored paths are relative to the working directory at manifest-creation time,
    # which is expected to be the project root. Absolute paths are returned unchanged.
    resolve_file_path = function(stored_path) {
      fs::path_abs(stored_path)
    },

    # Detect missing concept set files and update status in database
    detect_missing_conceptsets = function() {
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))
      
      # Get all active concept sets from database
      db_records <- tryCatch({
        DBI::dbGetQuery(
          conn,
          "SELECT id, label, file_path, status FROM concept_set_manifest WHERE status = 'active'"
        )
      }, error = function(e) {
        return(data.frame())
      })
      
      if (nrow(db_records) == 0) {
        return(NULL)
      }
      
      missing_conceptsets <- list()
      
      for (i in seq_len(nrow(db_records))) {
        record <- db_records[i, ]
        if (!file.exists(private$resolve_file_path(record$filePath))) {
          missing_conceptsets[[length(missing_conceptsets) + 1]] <- record
        }
      }
      
      return(missing_conceptsets)
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

    # Combine multiple Capr ConceptSet objects into a unified concept set
    # Flattens and categorizes concepts: include, include+descendants, exclude, exclude+descendants
    combine_capr_concept_sets = function(caprList, combinedLabel) {
      if (!requireNamespace("Capr", quietly = TRUE)) {
        cli::cli_abort("Package Capr is required to combine concept sets")
      }
      
      # Initialize empty dataframe with expected columns
      csDf <- data.frame(
        conceptId = integer(),
        conceptName = character(),
        domainId = character(),
        vocabularyId = character(),
        standardConcept = character(),
        includeDescendants = logical(),
        isExcluded = logical(),
        includeMapped = logical(),
        stringsAsFactors = FALSE
      )
      
      # Combine all Capr objects into a single dataframe
      for (caprCs in caprList) {
        cs <- tryCatch(
          Capr:::as.data.frame(caprCs),
          error = function(e) {
            cli::cli_warn("Failed to convert Capr object: {e$message}")
            return(NULL)
          }
        )
        if (!is.null(cs)) {
          csDf <- rbind(csDf, cs)
        }
      }
      
      if (nrow(csDf) == 0) {
        cli::cli_abort("No concepts found in the provided concept sets")
      }
      
      # Categorize concepts
      concepts <- c()
      desc <- c()
      excl <- c()
      excl_desc <- c()
      
      for (j in seq_len(nrow(csDf))) {
        include_desc <- csDf$includeDescendants[j]
        is_excl <- csDf$isExcluded[j]
        concept_id <- csDf$conceptId[j]
        
        if (include_desc && !is_excl) {
          desc <- c(desc, concept_id)
        } else if (is_excl && !include_desc) {
          excl <- c(excl, concept_id)
        } else if (is_excl && include_desc) {
          excl_desc <- c(excl_desc, concept_id)
        } else if (!is_excl && !include_desc) {
          concepts <- c(concepts, concept_id)
        }
      }
      
      # Build combined Capr ConceptSet
      caprCs <- Capr::cs(
        unique(concepts),
        Capr::descendants(unique(desc)),
        Capr::exclude(unique(excl)),
        Capr::exclude(Capr::descendants(unique(excl_desc))),
        name = combinedLabel
      )
      
      return(caprCs)
    },

    # Update concept set metadata (label, category, tags)
    update_concept_set_def = function(conceptSetId, label = NULL, category = NULL, tags = NULL) {
      checkmate::assert_int(conceptSetId)

      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      # Check that concept set exists and is active
      cs_row <- DBI::dbGetQuery(
        conn,
        "SELECT * FROM concept_set_manifest WHERE id = ? AND status = 'active'",
        list(conceptSetId)
      )

      if (nrow(cs_row) == 0) {
        cli::cli_abort("Concept set {conceptSetId} not found or is deleted")
      }

      # Prepare update values
      updates <- list()
      params <- list()

      if (!is.null(label)) {
        checkmate::assert_string(label, min.chars = 1)
        # Check label uniqueness (excluding self)
        existing <- DBI::dbGetQuery(
          conn,
          "SELECT id FROM concept_set_manifest WHERE label = ? AND id != ? AND status = 'active'",
          list(label, conceptSetId)
        )
        if (nrow(existing) > 0) {
          cli::cli_abort("Label '{label}' is already in use by concept set {existing$id[1]}")
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
      params[[length(params) + 1]] <- conceptSetId

      DBI::dbExecute(
        conn,
        paste0("UPDATE concept_set_manifest SET ", set_clause, " WHERE id = ?"),
        params
      )

      # Refresh in-memory manifest
      private$load_manifest_from_db()

      cli::cli_alert_success("Updated concept set {conceptSetId}")
      invisible(NULL)
    }
  ),

  public = list(
    #' @description Initialize a new ConceptSetManifest
    #'
    #' @param dbPath Character. Path to the SQLite database. Defaults to
    #'   "inputs/conceptSets/conceptSetManifest.sqlite". The directory is created
    #'   automatically if it does not exist.
    initialize = function(dbPath = "inputs/conceptSets/conceptSetManifest.sqlite") {
      private$.dbPath <- dbPath
      private$.manifest <- list()

      # Initialize SQLite schema (creates DB and table if needed)
      private$init_manifest(dbPath)

      # Load existing active entries from SQLite into memory
      private$load_manifest_from_db()
    },

    #' Get the manifest as a list of ConceptSetDef objects
    #'
    #' @return List. A list of ConceptSetDef objects in the manifest.
    getManifest = function() {
      return(private$.manifest)
    },

    #' @description Tabulate the manifest as a tibble
    #'
    #' @param filter Character. Controls which rows are returned. One of
    #'   \code{"active"} (default), \code{"deleted"}, or \code{"all"}.
    #'
    #' @return A tibble with columns: id, label, category, tags, file_path, hash,
    #'   source_type, cohort_type, status, created_at, deleted_at
    tabulateManifest = function(filter = c("active", "deleted", "all")) {

      filter <- match.arg(filter)

      where_clause <- switch(
        filter,
        active  = "WHERE status = 'active'",
        deleted = "WHERE status IN ('deleted', 'purged')",
        all     = ""
      )

      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      sql <- paste(
        "SELECT id, label, category, tags, file_path, hash, created_at, deleted_at",
        "FROM concept_set_manifest",
        where_clause,
        "ORDER BY id"
      )

      man <- DBI::dbGetQuery(conn, sql) |>
        tibble::as_tibble()

      return(man)
    },

    #' Get the manifest path
    #'
    #' @return Character. The path to the SQLite database.
    getDbPath = function() {
      private$.dbPath
    },

    #' Get the execution settings
    #'
    #' @return Object. The execution settings object for vocabulary access, or NULL if not set.
    getExecutionSettings = function() {
      private$.executionSettings
    },

    #' Set or update execution settings
    #'
    #' @param executionSettings ExecutionSettings object for database access.
    #'
    #' @return Invisibly returns self for method chaining.
    setExecutionSettings = function(executionSettings) {
      private$.executionSettings <- executionSettings
      invisible(self)
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
    #' `addAtlasConceptSet()` or `importAtlasConceptSets()` on every call.
    #'
    #' @param atlasConnection An ATLAS connection object (from `getAtlasConnection()`).
    #'
    #' @return Invisible self for method chaining.
    setAtlasConnection = function(atlasConnection) {
      private$.atlasConnection <- atlasConnection
      invisible(self)
    },

    # ========== ADD / IMPORT METHODS ==========

    #' @description Register a local CIRCE JSON file in the manifest
    #'
    #' @param filePath Character. Absolute or relative path to a valid CIRCE JSON file.
    #' @param label Character. Display name for the concept set.
    #' @param category Character. Category for the concept set. Defaults to `"init"`.
    #' @param tags Named list. Optional extra metadata tags. Defaults to `list()`.
    #'
    #' @return Invisible integer. The assigned concept set ID.
    addConceptSetFile = function(filePath, label, category = "init", tags = list()) {
      checkmate::assert_file_exists(filePath)
      checkmate::assert_string(label, min.chars = 1)
      # this is for domains...TODO add a checkmate on acceptable domains prior to add to tags
      # valid_domains <- c("drug_exposure", "condition_occurrence", "measurement", "procedure",
      #                    "observation", "device_exposure", "visit_occurrence", "init")
      checkmate::assert_string(category, min.chars = 1)
      checkmate::assert_list(tags, names = "named")

      ext <- tolower(tools::file_ext(filePath))

      if (ext != "json") {
        cli::cli_abort("filePath must be a .json file, got: .{ext}")
      }

      cs_id <- private$insert_concept_set(
        label = label,
        category = category,
        tags = tags,
        file_path = filePath
      )

      cli::cli_alert_success("Added concept set {cs_id}: {label}")
      invisible(cs_id)
    },

    #' @description Fetch a single concept set from ATLAS and register it in the manifest
    #'
    #' @param atlasId Integer. The ATLAS concept set definition ID.
    #' @param label Character. Display name for the concept set.
    #' @param category Character. Category for the concept set. Defaults to `"init"`.
    #' @param tags Named list. Optional extra metadata tags. Defaults to `list()`.
    #' @param atlasConnection An ATLAS connection object with a
    #'   `getConceptSetDefinition(conceptSetId)` method that returns a list with
    #'   `expression` (CIRCE JSON string) and `saveName` elements.
    #'   If `NULL`, falls back to the connection stored via `$setAtlasConnection()`.
    #'
    #' @return Invisible integer. The assigned concept set ID.
    addAtlasConceptSet = function(atlasId, label, category = "init", tags = list(), atlasConnection = NULL) {
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
      # this is for domains...TODO add a checkmate on acceptable domains prior to add to tags
      # valid_domains <- c("drug_exposure", "condition_occurrence", "measurement", "procedure",
      #                    "observation", "device_exposure", "visit_occurrence", "init")
      checkmate::assert_string(category, min.chars = 1)
      checkmate::assert_list(tags, names = "named")

      # Fetch concept set JSON from ATLAS
      cs_def <- tryCatch(
        atlasConnection$getConceptSetDefinition(conceptSetId = atlasId),
        error = function(e) cli::cli_abort("Failed to fetch concept set {atlasId} from ATLAS: {e$message}")
      )
      expression_json <- cs_def$expression[1]

      # Save JSON to json/ directory under the manifest folder
      concept_sets_dir <- dirname(private$.dbPath)
      json_dir <- fs::path(concept_sets_dir, "json")

      if (!dir.exists(json_dir)) {
        dir.create(json_dir, recursive = TRUE)
      }

      cs_name <- ifelse(!is.null(cs_def$saveName[1]) && cs_def$saveName[1] != "", cs_def$saveName[1], label)
      json_path <- fs::path(json_dir, paste0(cs_name, ".json"))
      readr::write_lines(expression_json, json_path) # make line ending always \\n

      cs_id <- private$insert_concept_set(
        label = label,
        category = category,
        tags = tags,
        file_path = json_path
      )

      cli::cli_alert_success("Added ATLAS concept set {cs_id}: {label}")
      invisible(cs_id)
    },

    #' @description Export a Capr ConceptSet to JSON and register it in the manifest
    #'
    #' @param caprConceptSet A Capr `ConceptSet` object.
    #' @param label Character. Display name for the concept set.
    #' @param category Character. Category for the concept set. Defaults to `"init"`.
    #' @param tags Named list. Optional extra metadata tags. Defaults to `list()`.
    #'
    #' @return Invisible integer. The assigned concept set ID.
    addCaprConceptSet = function(caprConceptSet, label, category = "init", tags = list()) {
      if (!requireNamespace("Capr", quietly = TRUE)) {
        cli::cli_abort(c(
          "Package {.pkg Capr} is required for addCaprConceptSet().",
          "i" = "Install with: {.code remotes::install_github('ohdsi/Capr')}"
        ))
      }

      if (!inherits(caprConceptSet, "ConceptSet")) {
        cli::cli_abort("caprConceptSet must be a Capr ConceptSet object")
      }

      checkmate::assert_string(label, min.chars = 1)
      # this is for domains...TODO add a checkmate on acceptable domains prior to add to tags
      # valid_domains <- c("drug_exposure", "condition_occurrence", "measurement", "procedure",
      #                    "observation", "device_exposure", "visit_occurrence", "init")
      checkmate::assert_string(category, min.chars = 1)
      checkmate::assert_list(tags, names = "named")

      concept_sets_dir <- dirname(private$.dbPath)
      json_dir <- fs::path(concept_sets_dir, "json")

      if (!dir.exists(json_dir)) {
        dir.create(json_dir, recursive = TRUE)
      }

      safe_label <- gsub("[^a-zA-Z0-9_-]", "_", label)
      json_path <- fs::path(json_dir, paste0(safe_label, ".json"))
      Capr::writeConceptSet(caprConceptSet, json_path)

      cs_id <- private$insert_concept_set(
        label = label,
        category = category,
        tags = tags,
        file_path = json_path
      )

      cli::cli_alert_success("Added Capr concept set {cs_id}: {label}")
      invisible(cs_id)
    },

    #' @description Batch-import concept sets from ATLAS via a conceptSetsLoad dataframe
    #' 
    #' Either create a dataframe or read in a csv file with columns `atlasId`, `label`, `category` (required) plus any
    #' additional columns treated as tag key-value pairs for tags. Calls `addAtlasConceptSet()` for each row inside 
    #' a `tryCatch` so a single failure does not abort the entire batch.
    #'
    #' @param conceptSetsLoad a data frame requiring the columns atlasId, label and category used to bulk add cohorts to the manifest
    #' @param atlasConnection An ATLAS connection object with a
    #'   `getConceptSetDefinition(conceptSetId)` method.
    #'   If `NULL`, falls back to the connection stored via `$setAtlasConnection()`.
    #'
    #' @return Invisible tibble imported concept sets.
    importAtlasConceptSets = function(conceptSetsLoad,
                                      atlasConnection = NULL) {
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
      # Validate data frame if provided directly
      checkmate::assert_data_frame(conceptSetsLoad, min.cols = 3)
      missing_cols <- setdiff(required_cols, names(conceptSetsLoad))
      if (length(missing_cols) > 0) {
        cli::cli_abort("conceptSetsLoad missing required columns: {paste(missing_cols, collapse = ', ')}")
      }

      # Determine which concept sets are new and which already exist
      cm_atlas_subset <- self$queryConceptSetsByTagName(tagName = "atlasId")
      concept_set_load_2 <- check_which_atlas_exist(cm_atlas_subset, conceptSetsLoad)

      # Header
      cli::cli_rule("ATLAS Concept Set Import")
      cli::cli_alert_info("Evaluating {nrow(conceptSetsLoad)} concept set(s) from load file")

      # Subset new and existing concept sets
      new_concept_sets <- concept_set_load_2 |>
        dplyr::filter(status == "new")

      existing_concept_sets <- concept_set_load_2 |>
        dplyr::filter(status == "active")

      # Process new concept sets
      if (nrow(new_concept_sets) > 0) {
        cli::cli_rule("Adding {nrow(new_concept_sets)} new concept set(s)")
        for (i in seq_len(nrow(new_concept_sets))) {
          row <- new_concept_sets[i, ]
          additional_tags <- list_tags_in_row(row)
          # Delegate to addAtlasConceptSet for actual manifest insertion
          concept_set_id <- self$addAtlasConceptSet(
            atlasId = row$atlasId,
            label = row$label,
            category = ifelse(is.na(row$category), "None", row$category),
            tags = additional_tags,
            atlasConnection = atlasConnection
          )
        }
      }

      # Process existing concept sets
      if (nrow(existing_concept_sets) > 0) {
        cli::cli_rule("Existing concept set(s) in manifest ({nrow(existing_concept_sets)})")
        for (i in seq_len(nrow(existing_concept_sets))) {
          row <- existing_concept_sets[i, ]
          cli::cli_alert_warning("  ID {row$id}: {row$label} (atlasId: {row$atlasId})")
        }
        
        cli::cli_alert_info("To check for ATLAS changes, run: {.code manifest$checkAtlasConceptSets(atlasConnection)}")
        cli::cli_alert_info("To update ATLAS definitions, run: {.code manifest$updateAtlasConceptSets(atlasConnection)}")
      }

      # Build and print final summary table
      summary_tbl <- concept_set_load_2 |>
        dplyr::mutate(
          message = dplyr::case_when(
            status == "new" ~ "Successfully added to manifest",
            status == "active" ~ "Already in manifest",
            TRUE ~ "Unknown"
          )
        ) |>
        dplyr::select(dplyr::any_of(c("id", "label", "atlasId", "status", "message")))

      cli::cli_rule("Import Summary ({nrow(summary_tbl)} concept set(s) total)")
      print(summary_tbl)

      invisible(concept_set_load_2)
    },

    #' Query concept sets by IDs
    #'
    #' @param ids Integer vector. One or more concept set IDs.
    #'
    #' @return Tibble with columns: id, label, category, tags, file_path, hash, created_at.
    queryConceptSetsByIds = function(ids) {
      checkmate::assert_integerish(x = ids, min.len = 1)
      ids <- as.integer(ids)

      matching_concept_sets <- list()

      for (concept_set in private$.manifest) {
        if (concept_set$getId() %in% ids) {
          matching_concept_sets[[length(matching_concept_sets) + 1]] <- concept_set
        }
      }

      if (length(matching_concept_sets) == 0) {
        cli::cli_alert_warning("No concept sets found with IDs: {paste(ids, collapse = ', ')}")
        return(NULL)
      }

      # Get data from database
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      ids_str <- paste(ids, collapse = ", ")
      manifest_df <- DBI::dbGetQuery(
        conn,
        paste0("SELECT id, label, category, tags, file_path, hash, created_at
                FROM concept_set_manifest WHERE id IN (", ids_str, ") AND status = 'active'")
      )

      if (nrow(manifest_df) == 0) {
        return(NULL)
      }

      return(tibble::as_tibble(manifest_df))
    },

    #' Query concept sets by tag
    #'
    #' @param tagStrings Character vector. One or more tags in the format "name: value"
    #'   (e.g., "category: primary"). When multiple tags are supplied, the \code{match}
    #'   argument controls whether a concept set must satisfy any or all of them.
    #' @param match Character. "any" (default) returns concept sets matching at least one tag;
    #'   "all" returns only concept sets matching every tag.
    #'
    #' @return Tibble with columns: id, label, category, tags, file_path, hash, created_at.
    queryConceptSetsByTag = function(tagStrings, match = c("any", "all")) {
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

      matching_concept_sets <- list()

      # Search through manifest for matching tags
      for (concept_set in private$.manifest) {
        cs_tags <- concept_set$tags
        tag_hits <- sapply(parsed_tags, function(pt) {
          !is.null(cs_tags) &&
            pt$name %in% names(cs_tags) &&
            cs_tags[[pt$name]] == pt$value
        })

        include <- if (match == "any") any(tag_hits) else all(tag_hits)

        if (include) {
          matching_concept_sets[[length(matching_concept_sets) + 1]] <- concept_set
        }
      }

      if (length(matching_concept_sets) == 0) {
        match_desc <- paste(tagStrings, collapse = " | ")
        cli::cli_alert_warning("No concept sets found matching ({match}): {match_desc}")
        return(NULL)
      }

      # Get IDs of matching concept sets
      matching_ids <- vapply(matching_concept_sets, function(cs) cs$getId(), integer(1))

      # Get data from database
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      ids_str <- paste(matching_ids, collapse = ", ")
      manifest_df <- DBI::dbGetQuery(
        conn,
        paste0("SELECT id, label, category, tags, file_path, hash, created_at
                FROM concept_set_manifest WHERE id IN (", ids_str, ") AND status = 'active'")
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
    queryConceptSetsByTagName = function(tagName) {
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

    #' Query concept sets by label
    #'
    #' @param labels Character vector. One or more labels to search for.
    #'   A concept set is included when it matches at least one of the supplied labels (OR logic).
    #' @param matchType Character. Either "exact" for exact match or "pattern" for pattern matching.
    #'   Defaults to "exact".
    #'
    #' @return Tibble with columns: id, label, category, tags, file_path, hash, created_at.
    queryConceptSetsByLabel = function(labels, matchType = c("exact", "pattern")) {
      checkmate::assert_character(x = labels, min.len = 1, min.chars = 1)
      matchType <- match.arg(matchType)

      matching_concept_sets <- list()

      # Search through manifest for matching labels (any-match across supplied labels)
      for (concept_set in private$.manifest) {
        cs_label <- concept_set$label

        label_hits <- sapply(labels, function(lbl) {
          if (matchType == "exact") {
            cs_label == lbl
          } else {
            grepl(lbl, cs_label, ignore.case = TRUE)
          }
        })

        if (any(label_hits)) {
          matching_concept_sets[[length(matching_concept_sets) + 1]] <- concept_set
        }
      }

      if (length(matching_concept_sets) == 0) {
        match_desc <- paste(labels, collapse = " | ")
        cli::cli_alert_warning("No concept sets found with {matchType} label match: {match_desc}")
        return(NULL)
      }

      # Get IDs of matching concept sets
      matching_ids <- vapply(matching_concept_sets, function(cs) cs$getId(), integer(1))

      # Get data from database
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      ids_str <- paste(matching_ids, collapse = ", ")
      manifest_df <- DBI::dbGetQuery(
        conn,
        paste0("SELECT id, label, category, tags, file_path, hash, created_at
                FROM concept_set_manifest WHERE id IN (", ids_str, ") AND status = 'active'")
      )

      if (nrow(manifest_df) == 0) {
        return(NULL)
      }

      return(tibble::as_tibble(manifest_df))
    },

    #' @description Get number of concept sets in manifest
    #'
    #' @return Integer. The number of concept sets.
    nConceptSets = function() {
      length(private$.manifest)
    },

    #' Get a specific concept set by ID
    #'
    #' @param id Integer. The concept set ID.
    #'
    #' @return ConceptSetDef. The ConceptSetDef object with matching ID, or NULL if not found.
    getConceptSetById = function(id) {
      checkmate::assert_int(x = id)

      for (concept_set in private$.manifest) {
        if (concept_set$getId() == id) {
          return(concept_set)
        }
      }

      cli::cli_alert_warning("Concept set with ID {id} not found")
      return(NULL)
    },

    #' Get concept sets by tag
    #'
    #' @param tagStrings Character vector. One or more tags in the format "name: value"
    #'   (e.g., "category: primary"). When multiple tags are supplied, the \code{match}
    #'   argument controls whether a concept set must satisfy any or all of them.
    #' @param match Character. "any" (default) returns concept sets matching at least one tag;
    #'   "all" returns only concept sets matching every tag.
    #'
    #' @return List. A list of ConceptSetDef objects with matching tags, or NULL if none found.
    getConceptSetsByTag = function(tagStrings, match = c("any", "all")) {
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

      matching_concept_sets <- list()

      # Search through manifest for matching tags
      for (concept_set in private$.manifest) {
        cs_tags <- concept_set$tags
        tag_hits <- sapply(parsed_tags, function(pt) {
          !is.null(cs_tags) &&
            pt$name %in% names(cs_tags) &&
            cs_tags[[pt$name]] == pt$value
        })

        include <- if (match == "any") any(tag_hits) else all(tag_hits)

        if (include) {
          matching_concept_sets[[length(matching_concept_sets) + 1]] <- concept_set
        }
      }

      if (length(matching_concept_sets) == 0) {
        match_desc <- paste(tagStrings, collapse = " | ")
        cli::cli_alert_warning("No concept sets found matching ({match}): {match_desc}")
        return(NULL)
      }

      return(matching_concept_sets)
    },

    #' Get concept sets by label
    #'
    #' @param labels Character vector. One or more labels to search for.
    #'   A concept set is included when it matches at least one of the supplied labels (OR logic).
    #' @param matchType Character. Either "exact" for exact match or "pattern" for pattern matching.
    #'   Defaults to "exact".
    #'
    #' @return List. A list of ConceptSetDef objects with matching labels, or NULL if none found.
    getConceptSetsByLabel = function(labels, matchType = c("exact", "pattern")) {
      checkmate::assert_character(x = labels, min.len = 1, min.chars = 1)
      matchType <- match.arg(matchType)

      matching_concept_sets <- list()

      # Search through manifest for matching labels (any-match across supplied labels)
      for (concept_set in private$.manifest) {
        cs_label <- concept_set$label

        label_hits <- sapply(labels, function(lbl) {
          if (matchType == "exact") {
            cs_label == lbl
          } else {
            grepl(lbl, cs_label, ignore.case = TRUE)
          }
        })

        if (any(label_hits)) {
          matching_concept_sets[[length(matching_concept_sets) + 1]] <- concept_set
        }
      }

      if (length(matching_concept_sets) == 0) {
        match_desc <- paste(labels, collapse = " | ")
        cli::cli_alert_warning("No concept sets found with {matchType} label match: {match_desc}")
        return(NULL)
      }

      return(matching_concept_sets)
    },



    #' @description Validate manifest and return status of all concept sets
    #'
    #' @return A tibble with columns: id, label, status (active/missing/deleted), deleted_at, file_exists
    validateManifest = function() {
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))
      
      # Get all concept sets from database (including deleted ones)
      db_records <- tryCatch({
        DBI::dbGetQuery(
          conn,
          "SELECT id, label, file_path, status, deleted_at FROM concept_set_manifest ORDER BY id"
        )
      }, error = function(e) {
        cli::cli_alert_danger("Failed to query manifest: {e$message}")
        return(data.frame())
      })
      
      if (nrow(db_records) == 0) {
        return(tibble::tibble(id = integer(), label = character(), status = character(), 
                              deleted_at = character(), file_exists = logical()))
      }
      
      # Add file_exists column (resolve stored paths before checking disk)
      db_records$file_exists <- sapply(db_records$file_path, function(p) file.exists(private$resolve_file_path(p)))
      
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

    #' @description Soft delete a concept set (mark as deleted, preserve record)
    #'
    #' @param id Integer. The concept set ID to delete.
    #' @param confirm Logical. If FALSE (default), prompts for interactive confirmation.
    #'   Pass TRUE to skip the prompt (suitable for scripts).
    #'
    #' @return Invisibly returns TRUE if successful, FALSE otherwise.
    deleteConceptSet = function(id, confirm = FALSE) {
      checkmate::assert_int(id)
      checkmate::assert_flag(confirm)
      
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      # Retrieve cohort record
      cs_row <- DBI::dbGetQuery(
        conn,
        "SELECT id, label, file_path FROM concept_set_manifest WHERE id = ?",
        list(id)
      )

      if (nrow(cs_row) == 0) {
        cli::cli_alert_danger("Concept Set {id} not found in manifest")
        invisible(NULL)
      }
      
      label     <- cs_row$label[1]
      file_path <- cs_row$file_path[1]


      # Request confirmation if not already confirmed
      if (!confirm) {
        cli::cli_alert_warning(
          "This will permanently delete concept set {id} ({label}) from the manifest and file system."
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
      }  else if (!file.exists(file_path)) {
        cli::cli_alert_warning("File not found on disk: {file_path} (manifest will be cleaned)")
      }

      # Mark as deleted in SQLite (soft delete with audit trail)
      tryCatch({
        DBI::dbExecute(
          conn,
          "UPDATE concept_set_manifest SET status = 'deleted', deleted_at = CURRENT_TIMESTAMP WHERE id = ?",
          list(id)
        )
      }, error = function(e) {
        cli::cli_alert_danger("Failed to mark concept set as deleted: {e$message}")
        return(invisible(NULL))
      })

      # Remove from in-memory manifest TODO
      cli::cli_alert_success("Marked concept set {id}: {label} as deleted (file removed from disk)")
      invisible(NULL)
      
    },

    # ========== COMBINE CONCEPT SETS METHOD ==========

    #' @description Combine multiple concept sets into a single unified concept set
    #'
    #' Loads multiple concept sets from the manifest as Capr objects, merges them
    #' into a unified concept set using set logic (include, include+descendants, exclude,
    #' exclude+descendants), exports the result as JSON, and registers it in the manifest.
    #'
    #' @param conceptSetIds Integer vector. IDs of concept sets to combine (minimum 2).
    #' @param combinedLabel Character. Display name for the combined concept set.
    #' @param combinedCategory Character. Category for the combined concept set.
    #'   Defaults to `"combined"`.
    #' @param combinedTags Named list. Optional metadata tags for the combined set.
    #'   Defaults to `list()`. A tag `sourceConceptSetIds` is automatically added
    #'   with comma-separated source IDs.
    #'
    #' @return Invisible integer. The ID of the newly created combined concept set.
    #'
    #' @details
    #' **Processing Steps:**
    #' 1. Validates that all concept set IDs exist and are active
    #' 2. Loads each concept set JSON as a Capr object using `Capr::readConceptSet()`
    #' 3. Combines them using set logic (private helper `combine_capr_concept_sets()`)
    #' 4. Exports combined Capr object to JSON in `json/` directory
    #' 5. Registers the new combined concept set in the manifest
    #' 6. Returns the new concept set ID
    #'
    #' **Concept Set Combination Logic:**
    #' - Includes: All included concepts across sets
    #' - Descendants: All concepts marked with descendants
    #' - Excludes: All excluded concepts (without descendants)
    #' - Exclude+Descendants: All concepts to exclude with descendants
    #'
    #' **Requirements:**
    #' - Capr package must be installed
    #' - All source concept sets must be active and have valid JSON files
    #'
    combineConceptSets = function(conceptSetIds, 
                                  combinedLabel,
                                  combinedCategory = "combined",
                                  combinedTags = list()) {
      if (!requireNamespace("Capr", quietly = TRUE)) {
        cli::cli_abort(c(
          "Package {.pkg Capr} is required for combineConceptSets().",
          i = "Install with: {.code remotes::install_github('ohdsi/Capr')}"
        ))
      }
      
      # Validation
      checkmate::assert_integerish(conceptSetIds, min.len = 2)
      conceptSetIds <- as.integer(conceptSetIds)
      checkmate::assert_string(combinedLabel, min.chars = 1)
      checkmate::assert_string(combinedCategory, min.chars = 1)
      checkmate::assert_list(combinedTags, names = "named")
      
      # Verify all concept set IDs exist
      cli::cli_rule("Combining {length(conceptSetIds)} Concept Sets")
      cli::cli_alert_info("Source IDs: {paste(conceptSetIds, collapse = ', ')}")
      
      for (cs_id in conceptSetIds) {
        cs_def <- self$getConceptSetById(cs_id)
        if (is.null(cs_def)) {
          cli::cli_abort("Concept set {cs_id} not found in manifest")
        }
      }
      
      cli::cli_alert_success("All source concept sets validated")
      
      # Load Capr objects
      cli::cli_alert_info("Loading Capr concept sets...")
      caprList <- list()
      
      for (cs_id in conceptSetIds) {
        cs_def <- self$getConceptSetById(cs_id)
        filePath <- cs_def$getFilePath()
        
        tryCatch({
          caprCs <- Capr::readConceptSet(filePath)
          caprList[[length(caprList) + 1]] <- caprCs
          cli::cli_alert_success("  [{cs_id}] {cs_def$label}")
        }, error = function(e) {
          cli::cli_abort("Failed to load concept set {cs_id} ({cs_def$label}): {e$message}")
        })
      }
      
      # Combine concept sets
      cli::cli_alert_info("Combining concept sets...")
      combinedCaprCs <- tryCatch({
        private$combine_capr_concept_sets(caprList, combinedLabel)
      }, error = function(e) {
        cli::cli_abort("Failed to combine concept sets: {e$message}")
      })
      
      cli::cli_alert_success("Concepts combined successfully")
      
      # Add source IDs to tags
      if (is.null(combinedTags$sourceConceptSetIds)) {
        combinedTags$sourceConceptSetIds <- paste(conceptSetIds, collapse = ",")
      }
      
      # Register combined concept set
      cli::cli_alert_info("Registering combined concept set...")
      new_id <- tryCatch({
        self$addCaprConceptSet(
          caprConceptSet = combinedCaprCs,
          label = combinedLabel,
          category = combinedCategory,
          tags = combinedTags
        )
      }, error = function(e) {
        cli::cli_abort("Failed to register combined concept set: {e$message}")
      })
      
      cli::cli_rule()
      cli::cli_alert_success(
        "Combined concept set created: ID {new_id} ({combinedLabel})"
      )
      cli::cli_alert_info("Source sets: {paste(conceptSetIds, collapse = ', ')}")
      cli::cli_alert_info("Tags include: sourceConceptSetIds = {paste(conceptSetIds, collapse = ',')}")
      
      invisible(new_id)
    },

    # ========== UPDATE METHODS ==========

    #' @description Update a concept set label
    #'
    #' @param conceptSetId Integer. The concept set ID to update.
    #' @param newLabel Character. The new label for the concept set.
    #'
    #' @return Invisible NULL.
    updateConceptSetLabel = function(conceptSetId, newLabel) {
      checkmate::assert_int(conceptSetId, lower = 1)
      checkmate::assert_string(newLabel, min.chars = 1)
      private$update_concept_set_def(conceptSetId = conceptSetId, label = newLabel)
      invisible(NULL)
    },

    #' @description Update a concept set category
    #'
    #' @param conceptSetId Integer. The concept set ID to update.
    #' @param newCategory Character. The new category for the concept set.
    #'
    #' @return Invisible NULL.
    updateConceptSetCategory = function(conceptSetId, newCategory) {
      checkmate::assert_int(conceptSetId, lower = 1)
      checkmate::assert_string(newCategory, min.chars = 1)
      private$update_concept_set_def(conceptSetId = conceptSetId, category = newCategory)
      invisible(NULL)
    },

    #' @description Update concept set tags
    #'
    #' @param conceptSetId Integer. The concept set ID to update.
    #' @param newTags Named list. The new tags for the concept set.
    #'
    #' @return Invisible NULL.
    updateConceptSetTags = function(conceptSetId, newTags) {
      checkmate::assert_int(conceptSetId, lower = 1)
      checkmate::assert_list(newTags, names = "named")
      private$update_concept_set_def(conceptSetId = conceptSetId, tags = newTags)
      invisible(NULL)
    },

    # ========== ATLAS MAINTENANCE METHODS ==========

    #' @description Auto-detect changes to ATLAS concept sets in remote repository
    #'
    #' Queries the manifest for all active ATLAS concept sets (identified by `atlasId` in tags),
    #' fetches their current definitions from ATLAS, computes hashes, and compares against
    #' the stored local hash. Provides a read-only summary of which concept sets have changed
    #' in ATLAS since import. No modifications are made.
    #'
    #' @details
    #' This is the detection phase of the ATLAS maintenance workflow. Use this to identify
    #' which ATLAS concept sets have changed, then optionally call `updateAtlasConceptSets()` to
    #' apply updates. Changes are detected by comparing expression JSON hashes.
    #'
    #' @param atlasConnection An ATLAS connection object with a method `getConceptSetDefinition(conceptSetId)`
    #'   that returns a list with an `expression` element (the CIRCE JSON as a string).
    #'   If `NULL` (default), uses the connection stored via `$setAtlasConnection()`.
    #'   If no connection is available, raises an error.
    #'
    #' @return Invisible tibble with columns:
    #'   - `id`: Concept set ID in the local manifest
    #'   - `label`: Concept set label
    #'   - `atlasId`: ATLAS concept set ID
    #'   - `filePath`: Local path to the JSON file
    #'   - `hasChanged`: Logical, TRUE if remote definition differs from local hash
    #'   - `localHash`: Hash of the stored JSON file
    #'   - `remoteHash`: Hash of the current ATLAS definition
    checkAtlasConceptSets = function(atlasConnection = NULL) {
      if (is.null(atlasConnection)) {
        atlasConnection <- private$.atlasConnection
      }

      if (is.null(atlasConnection)) {
        cli::cli_abort(c(
          "No ATLAS connection available.",
          i = "Supply {.arg atlasConnection} or call {.code $setAtlasConnection()} first."
        ))
      }

      # Query for concept sets with atlasId tag
      atlas_subset <- self$queryConceptSetsByTagName(tagName = "atlasId") |>
        dplyr::mutate(
          tags_list = purrr::map(tags, ~jsonlite::fromJSON(.x)),
          atlasId = purrr::map_int(tags_list, ~.x$atlasId)
        ) |>
        dplyr::select(
          id, atlasId, label, category, hash, filePath
        )

      if (is.null(atlas_subset) || nrow(atlas_subset) == 0) {
        cli::cli_alert_info("No ATLAS concept sets found in manifest")
        invisible(NULL)
      }


      res <- vector('list', length = nrow(atlas_subset))
      # go through each atlas cohort row and check if any change to the definition
      for (i in seq_len(nrow(cm_atlas_subset))) {
        row_atlas_id <- atlas_subset$atlasId[i]
        row_label <- atlas_subset$label[i]
        existing_id <- atlas_subset$id[i]
        current_hash <- atlas_subset$hash[i]
        row_file_path <- atlas_subset$filePath[i] #note bug in CSM that filePath is snakecase

        # Fetch JSON from ATLAS and compare hashes
        tryCatch({
          cs_def <- atlasConnection$getConceptSetDefinition(conceptSetId = atlas_id)
        }, error = function(e) {
          cli::cli_warn("Failed to fetch atlasId {row_atlas_id}: {e$message}")
          return(NULL)
        })

        expression_json <- c(cs_def$expression[1], "\n") |> paste(collapse = "") # make sure matches file read
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

      cli::cli_rule("ATLAS Change Detection Summary ({nrow(res_final)} concept sets(s) checked)")
      print(res_final)

      invisible(res_final)

    },

    #' @description Update ATLAS concept sets with remote definitions
    #'
    #' Fetches current definitions from ATLAS for concept sets that have changed and updates 
    #' the stored JSON files and manifest entries. This is the modification phase that applies 
    #' changes detected by checkAtlasConceptSets().
    #'
    #' @details
    #' This method updates ATLAS concept sets that have changed in the remote repository. It:
    #' - Calls checkAtlasConceptSets() to identify changes
    #' - For each changed concept set: fetches current definition, updates JSON file, updates hash in manifest
    #' - Refreshes the in-memory manifest
    #'
    #' Use `checkAtlasConceptSets()` first to identify which concept sets have changed, then call 
    #' this method to apply updates.
    #'
    #' @param atlasConnection An ATLAS connection object with a method `getConceptSetDefinition(conceptSetId)`.
    #'   If `NULL` (default), uses the connection stored via `$setAtlasConnection()`.
    #'
    #' @return Invisible tibble of concept sets that were updated, with columns:
    #'   id, label, atlasId, filePath, hasChanged, localHash, remoteHash
    updateAtlasConceptSets = function(atlasConnection = NULL) {
      if (is.null(atlasConnection)) {
        atlasConnection <- private$.atlasConnection
      }

      if (is.null(atlasConnection)) {
        cli::cli_abort(c(
          "No ATLAS connection available.",
          i = "Supply {.arg atlasConnection} or call {.code $setAtlasConnection()} first."
        ))
      }

      # Check for changes
      check_atlas_changes <- self$checkAtlasConceptSets(atlasConnection) |>
        dplyr::filter(hasChanged)

      if (nrow(check_atlas_changes) == 0) {
        cli::cli_alert_info("No changed ATLAS concept sets found. All concept sets are current.")
        invisible(NULL)
      }

      # Get SQLite connection
      dbPath <- private$.dbPath
      sqlite_conn <- DBI::dbConnect(RSQLite::SQLite(), dbPath)
      on.exit(DBI::dbDisconnect(sqlite_conn))

      # Header
      cli::cli_rule("ATLAS Concept Set Update")
      cli::cli_alert_info("Updating {nrow(check_atlas_changes)} concept set(s)")

      # Process each changed concept set
      for (i in seq_len(nrow(check_atlas_changes))) {
        row_atlas_id <- check_atlas_changes$atlasId[i]
        row_label <- check_atlas_changes$label[i]
        existing_path <- check_atlas_changes$filePath[i]
        existing_id <- check_atlas_changes$id[i]

        # Fetch JSON from ATLAS
        tryCatch({
          cs_def <- atlasConnection$getConceptSetDefinition(conceptSetId = row_atlas_id)
        }, error = function(e) {
          cli::cli_warn("Failed to fetch atlasId {row_atlas_id}: {e$message}")
          return(NULL)
        })

        expression_json <- cs_def$expression[1]
        expression_json_file <- c(expression_json, "\n") |> paste(collapse = "")
        new_hash <- rlang::hash(expression_json_file)

        # Save JSON to file
        concept_sets_dir <- dirname(dbPath)
        json_dir <- fs::path(concept_sets_dir, "json")
        json_file_path <- fs::path_file(existing_path)
        json_path <- fs::path(json_dir, json_file_path)
        readr::write_lines(expression_json, json_path)

        # Update SQLite manifest
        DBI::dbExecute(
          sqlite_conn,
          "UPDATE concept_set_manifest SET hash = ?, timestamp = CURRENT_TIMESTAMP WHERE id = ?",
          list(new_hash, existing_id)
        )

        cli::cli_alert_success("Updated {row_label} (ID {existing_id})")
      }

      # Refresh in-memory manifest
      private$load_manifest_from_db()

      cli::cli_alert_success("All {nrow(check_atlas_changes)} concept set(s) updated successfully")
      invisible(check_atlas_changes)
    },

    #' @description Clean up missing concept sets from manifest
    #'
    #' @param keep_trace Logical. If TRUE, marks missing as deleted with timestamp (soft delete).
    #'   If FALSE, permanently removes from database (hard delete). Defaults to TRUE.
    #'
    #' @return Invisibly returns NULL. Displays summary of cleanup actions.
    cleanupMissing = function(keep_trace = TRUE) {
      status_df <- self$validateManifest()
      
      # Find missing active concept sets (file doesn't exist but status is active)
      missing_mask <- status_df$status == "active" & !status_df$file_exists
      missing_conceptsets <- status_df[missing_mask, ]
      
      if (nrow(missing_conceptsets) == 0) {
        cli::cli_alert_success("No missing concept sets to clean up")
        invisible(NULL)
      }
      
      cli::cli_rule("Cleaning Up Missing Concept Sets")
      cli::cli_alert_info("Found {nrow(missing_conceptsets)} missing concept set file(s)")
      
      for (i in seq_len(nrow(missing_conceptsets))) {
        cs_id <- missing_conceptsets$id[i]
        label <- missing_conceptsets$label[i]
        
        if (keep_trace) {
          self$deleteConceptSet(cs_id, reason = "missing file")
        } else {
          self$permanentlyDeleteConceptSet(cs_id, confirm = TRUE)
        }
      }
      
      cleanup_method <- if (keep_trace) "soft deleted (with trace)" else "hard deleted (permanently)"
      cli::cli_alert_success("Cleanup complete: {nrow(missing_conceptsets)} concept set(s) {cleanup_method}")
      
      invisible(NULL)
    },

    #' Sync the manifest against concept set files on disk
    #'
    #' @description
    #' Scans the \code{json/} subdirectory of the concept sets folder, reconciles it against
    #' the SQLite manifest, and updates both the database and the in-memory list:
    #' \itemize{
    #'   \item New files found on disk are added (new ConceptSetDef + manifest entry).
    #'   \item Active manifest records whose file no longer exists are soft-deleted.
    #'   \item Existing files whose JSON hash has changed are updated in the manifest.
    #' }
    #' 
    #' @param strict_mode Logical. If TRUE (default), automatically removes orphaned files found
    #'   on disk. If FALSE, only warns about them without deletion. Default: TRUE.
    #' 
    #' @return Data frame with columns: id, label, action
    #'   (\code{"added"}, \code{"hash_updated"}, \code{"missing_flagged"}, or \code{"unchanged"}).
    syncManifest = function(strict_mode = TRUE) {
      checkmate::assert_flag(strict_mode)
      
      concept_sets_folder <- dirname(private$.dbPath)
      json_dir <- file.path(concept_sets_folder, "json")

      # Collect all JSON files currently on disk
      on_disk <- c()

      if (dir.exists(json_dir)) {
        on_disk <- c(on_disk, list.files(json_dir, pattern = "\\.json$",
                                         full.names = TRUE, recursive = TRUE))
      }

      on_disk_rel <- fs::path_rel(on_disk)

      # Pull current records from the SQLite manifest
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      db_records <- DBI::dbGetQuery(
        conn,
        "SELECT id, label, category, tags, file_path, hash, status
         FROM concept_set_manifest
         WHERE status IN ('active', 'deleted')"
      )

      results <- data.frame(
        id     = integer(),
        label  = character(),
        action = character(),
        stringsAsFactors = FALSE
      )

      cli::cli_rule("Syncing Concept Set Manifest")

      # ── Step 1: check files already in the manifest ──────────────────────────
      for (i in seq_len(nrow(db_records))) {
        rec        <- db_records[i, ]
        rec_id     <- rec$id
        rec_label  <- rec$label
        rec_status <- rec$status
        file_path  <- private$resolve_file_path(rec$file_path)

        if (rec_status == "active" && !file.exists(file_path)) {
          # File has gone missing — soft-delete
          DBI::dbExecute(
            conn,
            "UPDATE concept_set_manifest SET status = 'deleted', deleted_at = CURRENT_TIMESTAMP WHERE id = ?",
            list(rec_id)
          )
          # Remove from in-memory list
          private$.manifest <- Filter(function(cs) cs$getId() != rec_id, private$.manifest)
          cli::cli_alert_warning("Missing: {rec_label} (ID {rec_id}) — soft-deleted")
          results <- rbind(results, data.frame(id = rec_id, label = rec_label,
                                               action = "missing_flagged", stringsAsFactors = FALSE))
          next
        }

        if (!file.exists(file_path)) {
          next  # already deleted/purged record with missing file — skip
        }

        # Recompute hash and compare
        tryCatch({
          tmp_def <- ConceptSetDef$new(label = rec_label, category = rec$category, tags = list(), filePath = file_path)
          new_hash <- tmp_def$getHash()

          if (new_hash != rec$hash) {
            DBI::dbExecute(
              conn,
              "UPDATE concept_set_manifest SET hash = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
              list(new_hash, rec_id)
            )
            # Update in-memory entry if present
            idx <- which(sapply(private$.manifest, function(cs) cs$getId() == rec_id))

            if (length(idx) > 0) {
              tmp_def$setId(as.integer(rec_id))

              if (!is.na(rec$tags) && rec$tags != "") {
                tmp_def$tags <- jsonlite::fromJSON(rec$tags, simplifyVector = FALSE)
              }

              private$.manifest[[idx]] <- tmp_def
            }

            cli::cli_alert_warning("Hash updated: {rec_label} (ID {rec_id})")
            results <- rbind(results, data.frame(id = rec_id, label = rec_label,
                                                 action = "hash_updated", stringsAsFactors = FALSE))
          } else {
            results <- rbind(results, data.frame(id = rec_id, label = rec_label,
                                                 action = "unchanged", stringsAsFactors = FALSE))
          }
        }, error = function(e) {
          cli::cli_alert_danger("Error checking {rec_label}: {e$message}")
        })
      }

      # ── Step 2: discover new files not yet in the manifest ───────────────────
      existing_rel <- db_records$file_path  # stored as relative paths
      new_files    <- on_disk[!(on_disk_rel %in% existing_rel)]

      if (length(new_files) > 0) {
        cli::cli_alert_info("Found {length(new_files)} new concept set file(s)")
      }

      for (file_path in new_files) {
        label <- tools::file_path_sans_ext(basename(file_path))
        tryCatch({
          new_def <- ConceptSetDef$new(label = label, tags = list(), filePath = file_path)

          # Determine next ID
          max_id_result <- DBI::dbGetQuery(conn, "SELECT MAX(id) as max_id FROM concept_set_manifest")
          max_id  <- ifelse(!is.na(max_id_result$max_id[1]), max_id_result$max_id[1], 0)
          next_id <- as.integer(max_id + 1)
          new_def$setId(next_id)

          DBI::dbExecute(
            conn,
            "INSERT INTO concept_set_manifest (id, label, category, tags, file_path, hash, created_at, updated_at, status)
             VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'active')",
            list(next_id, label, "init", NA_character_, fs::path_rel(file_path), new_def$getHash())
          )

          private$.manifest[[length(private$.manifest) + 1]] <- new_def
          cli::cli_alert_success("Added: {label} (ID {next_id})")
          results <- rbind(results, data.frame(id = next_id, label = label,
                                               action = "added", stringsAsFactors = FALSE))
        }, error = function(e) {
          cli::cli_alert_danger("Error adding {label}: {e$message}")
        })
      }

      # ── Step 3: Auto-remove orphaned files not in manifest ──────────────────
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
      n_added   <- sum(results$action == "added")
      n_updated <- sum(results$action == "hash_updated")
      n_missing <- sum(results$action == "missing_flagged")
      n_orphan_removed <- sum(results$action == "auto_removed_orphan")
      n_same    <- sum(results$action == "unchanged")
      
      cli::cli_rule()
      cli::cli_alert_success(
        "Sync complete — Added: {n_added} | Updated: {n_updated} | Missing: {n_missing} | Orphaned removed: {n_orphan_removed} | Unchanged: {n_same}"
      )

      return(results)
    },

    #' @description Retrieve concept information for all concepts in a concept set
    #'
    #' Fetches the standard concepts included in a concept set from the OMOP vocabulary tables.
    #' The concept set definition (stored as CIRCE JSON) is used to build a query that retrieves
    #' all concept IDs and names matching the set definition. Results are returned as a tibble
    #' with concept identifiers and display names.
    #'
    #' @param conceptSetId Integer. The concept set ID in the manifest.
    #'
    #' @return Tibble with columns:
    #'   - \code{conceptId}: Integer, the OMOP concept identifier
    #'   - \code{conceptName}: Character, the concept name from the vocabulary
    #'
    #' @details
    #' **Requirements:**
    #' - ExecutionSettings must be initialized with a valid database connection
    #' - ExecutionSettings must have \code{cdmDatabaseSchema} and optionally \code{tempEmulationSchema} set
    #' - User must have READ access to OMOP concept and concept_ancestor tables
    #'
    #' **Processing:**
    #' 1. Retrieves the concept set definition (CIRCE JSON) by ID
    #' 2. Builds SQL query using \code{CirceR::buildConceptSetQuery()}
    #' 3. Executes query against the OMOP vocabulary schema
    #' 4. Returns results with concept_id and concept_name columns
    #'
    grabConceptInfoFromSet = function(conceptSetId) {
      checkmate::assert_int(conceptSetId, lower = 1)
      
      # Validate ExecutionSettings
      private$validateExecutionSettings()

      # Get concept set definition
      cs_def <- self$getConceptSetById(conceptSetId)
      if (is.null(cs_def)) {
        cli::cli_abort("Concept set {conceptSetId} not found in manifest")
      }

      csJson <- cs_def$getJson()
      cs_sql <- CirceR::buildConceptSetQuery(csJson)

      # Get connection and vocabulary schema from ExecutionSettings
      exec_settings <- private$.executionSettings
      connection <- exec_settings$getConnection()
      
      if (is.null(connection)) {
        exec_settings$connect()
        connection <- exec_settings$getConnection()
      }
      on.exit(exec_settings$disconnect())

      # Wrap in CTE and find included standard concepts
      full_sql <- glue::glue(
        "WITH concepts AS ({cs_sql})\n",
        "SELECT c.concept_id, c.concept_name, c.vocabulary_id, c.domain_id, c.concept_class_id, c.standard_concept, c.concept_code\n",
            "FROM concepts\n",
            "JOIN @vocabulary_database_schema.concept c\n",
            "  ON c.concept_id = concepts.concept_id\n",
            "ORDER BY 1, 2;"
      )

      # Execute query
      conceptInfo <- DatabaseConnector::renderTranslateQuerySql(
        connection,
        full_sql,
        vocabulary_database_schema = exec_settings$cdmDatabaseSchema,
        tempEmulationSchema = exec_settings$tempEmulationSchema,
        snakeCaseToCamelCase = TRUE
      ) 

      # Inform user of retrieval
      cs_label <- cs_def$label
      n_concepts <- nrow(conceptInfo)
      cli::cli_alert_success(
        "Retrieved {n_concepts} concept(s) for concept set {conceptSetId}: {cs_label}"
      )

      return(conceptInfo)
      
    },

    #' Extract Source Codes for Concept Sets
    #'
    #' @description
    #' Finds source codes from specified vocabularies that map to each concept set's 
    #' standard concepts. Results are exported to a single xlsx file with one sheet 
    #' per concept set, saved in the inputs/conceptSets folder. The function provides 
    #' interactive vocabulary suggestions based on detected concept set domains.
    #'
    #' @param sourceVocabs Character vector. Source vocabulary IDs to search for.
    #'   Valid options: "ICD9CM", "ICD10CM", "HCPCS", "CPT4", "LOINC", "NDC".
    #'   Defaults to c("ICD10CM"). The function will suggest appropriate vocabularies
    #'   based on the domains of your concept sets and prompt you to use them.
    #' @param outputFolder Character. Path where the xlsx file will be saved.
    #'   Defaults to "inputs/conceptSets".
    #'
    #' @details
    #' **Vocabulary Suggestion by Domain:**
    #' The function automatically suggests appropriate vocabularies based on concept set domains:
    #' - `condition_occurrence`: ICD10CM, ICD9CM
    #' - `procedure`: HCPCS, CPT4
    #' - `measurement`: LOINC
    #' - `drug_exposure`: NDC
    #' - `observation`: All vocabularies (ICD9CM, ICD10CM, HCPCS, CPT4, LOINC, NDC)
    #' - `device_exposure`: NDC
    #' - `visit_occurrence`: ICD10CM, ICD9CM, HCPCS, CPT4
    #'
    #' Note: These suggestions are based on OMOP CDM conventions. You can override 
    #' with any valid vocabulary combination.
    #'
    #' **Processing Workflow:**
    #' 1. Verifies ExecutionSettings is configured with database connection
    #' 2. Detects domains of all concept sets in the manifest
    #' 3. Displays suggested vocabularies based on detected domains
    #' 4. Prompts user to accept or override suggested vocabularies
    #' 5. Creates a new xlsx workbook
    #' 6. For each concept set in the manifest:
    #'    - Reads the CIRCE JSON definition
    #'    - Builds a concept query selecting standard concepts (using CirceR)
    #'    - Performs SQL join: concepts -> concept_relationship (Maps to) -> source concepts
    #'    - Finds matching source codes in the specified vocabularies
    #'    - Adds results as a new sheet in the xlsx workbook with formatted header
    #'    - Provides status messages for each concept set
    #' 7. Exports combined results to `{outputFolder}/SourceCodeWorkbook.xlsx`
    #' 8. Each sheet contains columns: vocabulary_id, concept_code, concept_name
    #' 9. Sheet headers are styled with blue background and white bold text
    #' 10. Column widths are auto-fitted for readability
    #'
    #' **SQL Query Pattern:**
    #' For each concept set, the following logic is executed:
    #' - CTE selects all standard concepts in the concept set
    #' - Joins to concept_relationship table with relationship_id = 'Maps to'
    #' - Maps relationship finds what source codes map TO standard concepts
    #' - Filters to valid, non-invalid source codes in specified vocabularies
    #' - Results ordered by vocabulary_id and concept_code
    #'
    #' **Requirements:**
    #' - ExecutionSettings must be initialized with a valid database connection
    #' - Vocabulary schema must be accessible from ExecutionSettings
    #' - openxlsx2 package must be installed
    #' - User must have READ permissions on vocabulary tables
    #'
    #' **Error Handling:**
    #' - Displays warnings if any concept set processing fails but continues with others
    #' - Provides clear error messages if database connection is unavailable
    #' - Validates source vocabularies against known vocabulary IDs
    #'
    #' @return Invisibly returns NULL. Saves xlsx file to outputFolder and prints 
    #'   status messages via cli package. Output file is ready to open in Excel or 
    #'   other spreadsheet software.
    #'
    extractSourceCodes = function(sourceVocabs = c("ICD10CM"),
                                  outputFolder = here::here("inputs/conceptSets")) {
      # Validate executionSettings is available
      private$validateExecutionSettings()

      # Define valid source vocabularies
      valid_vocabs <- c("ICD9CM", "ICD10CM", "HCPCS", "CPT4", "LOINC", "NDC")

      # Validate sourceVocabs
      checkmate::assert_character(sourceVocabs, min.len = 1)
      invalid_vocabs <- setdiff(sourceVocabs, valid_vocabs)
      if (length(invalid_vocabs) > 0) {
        stop("Invalid source vocabulary: ", paste(invalid_vocabs, collapse = ", "),
             ". Valid options: ", paste(valid_vocabs, collapse = ", "))
      }

      # Collect domains from all concept sets and suggest vocabularies
      domains <- unique(sapply(private$.manifest, function(cs) {
        tags <- cs$tags
        if (!is.null(tags) && "domain" %in% names(tags)) {
          return(tags[["domain"]])
        }
        return(NA_character_)
      }))
      
      domains <- domains[!is.na(domains)]
      
      # Suggest vocabularies based on domains
      if (length(domains) > 0) {
        suggested_vocabs <- unique(unlist(lapply(domains, private$suggest_source_vocabs_for_domain)))
        cli::cli_alert_info("Concept set domains detected: {paste(domains, collapse = ', ')}")
        cli::cli_alert_info("Suggested source vocabularies for these domains: {paste(suggested_vocabs, collapse = ', ')}")
        
        # Interactive prompt to use suggested vocabularies
        cli::cli_rule("Source Vocabulary Selection")
        choice <- utils::menu(
          c("Yes", "No"),
          title = "Would you like to use the suggested source vocabularies?"
        )
        
        if (choice == 1) {
          # User selected "Yes"
          sourceVocabs <- suggested_vocabs
          cli::cli_alert_success("Using suggested vocabularies: {paste(sourceVocabs, collapse = ', ')}")
        } else {
          # User selected "No"
          cli::cli_alert_info("Using specified vocabularies: {paste(sourceVocabs, collapse = ', ')}")
        }
      }

      # Get connection and vocabulary schema from ExecutionSettings
      exec_settings <- private$.executionSettings
      connection <- exec_settings$getConnection()
      vocab_schema <- exec_settings$cdmDatabaseSchema

      if (is.null(connection)) {
        exec_settings$connect()
        connection <- exec_settings$getConnection()
      }
      on.exit(exec_settings$disconnect())


      if (is.null(vocab_schema)) {
        stop("ExecutionSettings must have vocabularySchema defined")
      }

      # Check if openxlsx2 is available
      if (!requireNamespace("openxlsx2", quietly = TRUE)) {
        stop("The 'openxlsx2' package is required to extract source codes. Install it with: install.packages('openxlsx2')")
      }

      # Create output file path
      output_file <- fs::path(outputFolder, paste0("SourceCodeWorkbook", ".xlsx"))

      # Create workbook
      wb <- openxlsx2::wb_workbook()

      cli::cli_alert_info("Extracting source codes for {length(private$.manifest)} concept sets...")

      # Process each concept set
      for (i in seq_along(private$.manifest)) {
        concept_set <- private$.manifest[[i]]

        tryCatch({
          cs_label <- concept_set$label
          cs_json <- concept_set$getJson()
          cs_file_path <- concept_set$getFilePath()

          cli::cli_alert_info("[{i}/{length(private$.manifest)}] Processing: {crayon::magenta(cs_label)}")

          # Build CIRCE concept set query
          cs_sql <- CirceR::buildConceptSetQuery(cs_json)

          # Wrap in CTE and join with source codes
          full_sql <- glue::glue(
            "WITH concepts AS ({cs_sql})\n",
            "SELECT c.vocabulary_id, c.concept_code, c.concept_name\n",
            "FROM concepts\n",
            "JOIN @vocabulary_database_schema.concept_relationship cr\n",
            "  ON cr.concept_id_2 = concepts.concept_id\n",
            "  AND relationship_id = 'Maps to'\n",
            "JOIN @vocabulary_database_schema.concept c\n",
            "  ON c.concept_id = cr.concept_id_1\n",
            "  AND c.vocabulary_id IN (@vocabs)\n",
            "  AND c.invalid_reason IS NULL\n",
            "ORDER BY 1, 2;"
          )

          # Format vocabulary list for SQL
          vocabs_sql <- paste0("'", paste(sourceVocabs, collapse = "','"), "'")

          # Execute query
          source_codes <- DatabaseConnector::renderTranslateQuerySql(
            connection,
            full_sql,
            vocabulary_database_schema = vocab_schema,
            vocabs = vocabs_sql
          )

          # Create a valid sheet name (max 31 characters, no special chars)
          sheet_name <- substr(gsub("[^a-zA-Z0-9]", "_", cs_label), 1, 31)

          # Add worksheet to workbook and add data
          wb <- openxlsx2::wb_add_worksheet(wb, sheet = sheet_name)
          wb <- openxlsx2::wb_add_data(wb, sheet = sheet_name, x = source_codes)

          # Format the header row - blue background with white bold text
          header_range <- paste0("A1:", openxlsx2::int2col(ncol(source_codes)), "1")
          wb <- openxlsx2::wb_add_fill(wb, sheet = sheet_name, dims = header_range, color = openxlsx2::wb_color(hex = "FF4472C4"))
          wb <- openxlsx2::wb_add_font(wb, sheet = sheet_name, dims = header_range, bold = TRUE, color = openxlsx2::wb_color(hex = "FFFFFFFF"))

          # Auto-fit columns
          wb <- openxlsx2::wb_set_col_widths(wb, sheet = sheet_name, widths = "auto", cols = 1:ncol(source_codes))

          cli::cli_alert_success(
            "Added {nrow(source_codes)} source codes for {crayon::cyan(cs_label)}"
          )
        }, error = function(e) {
          cli::cli_alert_danger(
            "Error extracting source codes for {concept_set$label}: {e$message}"
          )
        })
      }

      # Save the workbook
      openxlsx2::wb_save(wb, file = output_file, overwrite = TRUE)
      cli::cli_alert_success("Source codes extracted and saved to: {fs::path_rel(output_file)}")

      invisible(NULL)
    },

    #' Extract Included Standard Concepts for Concept Sets
    #'
    #' Finds standard concepts that are included in (map TO) each concept set's included concepts.
    #' Results are exported to a single xlsx file with one sheet per concept set,
    #' saved in the inputs/conceptSets folder.
    #'
    #' @param outputFolder Character. Path where the xlsx file will be saved.
    #'   Defaults to "inputs/conceptSets".
    #'
    #' @details
    #' This function identifies which standard concepts are included in each concept set
    #' by finding the reverse mapping relationship. For each concept set:
    #'
    #' 1. Reads the CIRCE JSON definition
    #' 2. Builds a concept query using CirceR
    #' 3. Joins with concept_relationship via reverse "Maps to" relationship
    #'    (finds what maps TO the concept set concepts)
    #' 4. Filters for standard concepts (standard_concept = 'S')
    #' 5. Adds results to a new sheet in the xlsx workbook
    #' 6. Exports all results to `{outputFolder}/IncludedCodes.xlsx`
    #' 7. Each sheet contains: concept_id, concept_name, vocabulary_id
    #'
    #' **Requirements:**
    #' - ExecutionSettings must be initialized with a valid connection
    #' - Vocabulary schema must be accessible from ExecutionSettings
    #' - openxlsx2 package must be installed
    #'
    #' @return Invisibly returns NULL. Saves xlsx file to outputFolder and prints status messages.
    #'
    extractIncludedCodes = function(outputFolder = here::here("inputs/conceptSets")) {
      # Validate executionSettings is available
      private$validateExecutionSettings()

      # Check if openxlsx2 is available
      if (!requireNamespace("openxlsx2", quietly = TRUE)) {
        stop("openxlsx2 package is required for extractIncludedCodes. Install with: install.packages('openxlsx2')")
      }

      # Create output file path
      output_file <- fs::path(outputFolder, "IncludedCodes.xlsx")

      # Create workbook
      wb <- openxlsx2::wb_workbook()

      cli::cli_alert_info("Extracting included codes for {length(private$.manifest)} concept sets...")

      # Get connection and vocabulary schema from ExecutionSettings
      exec_settings <- private$.executionSettings
      connection <- exec_settings$getConnection()
      vocab_schema <- exec_settings$cdmDatabaseSchema

      if (is.null(connection)) {
        stop("No database connection available in ExecutionSettings")
      }
      on.exit(exec_settings$disconnect())

      if (is.null(vocab_schema)) {
        stop("No vocabulary database schema specified in ExecutionSettings")
      }

      # Process each concept set
      for (i in seq_along(private$.manifest)) {
        concept_set <- private$.manifest[[i]]

        tryCatch({
          cs_label <- concept_set$label
          cs_json <- concept_set$getJson()
          cs_file_path <- concept_set$getFilePath()

          cli::cli_alert_info("[{i}/{length(private$.manifest)}] Processing: {crayon::magenta(cs_label)}")

          # Build CIRCE concept set query
          cs_sql <- CirceR::buildConceptSetQuery(cs_json)

          # Wrap in CTE and find included standard concepts
          full_sql <- glue::glue(
            "WITH concepts AS ({cs_sql})\n",
            "SELECT c.concept_id, c.concept_name, c.vocabulary_id\n",
            "FROM concepts\n",
            "JOIN @vocabulary_database_schema.concept_relationship cr\n",
            "  ON cr.concept_id_2 = concepts.concept_id\n",
            "  AND relationship_id = 'Maps to'\n",
            "JOIN @vocabulary_database_schema.concept c\n",
            "  ON c.concept_id = cr.concept_id_1\n",
            "  AND c.standard_concept = 'S'\n",
            "ORDER BY 1, 2;"
          )

          # Execute query
          included_codes <- DatabaseConnector::renderTranslateQuerySql(
            connection,
            full_sql,
            vocabulary_database_schema = vocab_schema
          )

          # Create a valid sheet name (max 31 characters, no special chars)
          sheet_name <- substr(gsub("[^a-zA-Z0-9]", "_", cs_label), 1, 31)

          # Add worksheet to workbook and add data
          wb <- openxlsx2::wb_add_worksheet(wb, sheet = sheet_name)
          wb <- openxlsx2::wb_add_data(wb, sheet = sheet_name, x = included_codes)

          # Format the header row - green background with white bold text
          header_range <- paste0("A1:", openxlsx2::int2col(ncol(included_codes)), "1")
          wb <- openxlsx2::wb_add_fill(wb, sheet = sheet_name, dims = header_range, color = openxlsx2::wb_color(hex = "FF70AD47"))
          wb <- openxlsx2::wb_add_font(wb, sheet = sheet_name, dims = header_range, bold = TRUE, color = openxlsx2::wb_color(hex = "FFFFFFFF"))

          # Auto-fit columns
          wb <- openxlsx2::wb_set_col_widths(wb, sheet = sheet_name, widths = "auto", cols = 1:ncol(included_codes))

          cli::cli_alert_success(
            "Added {nrow(included_codes)} included codes for {crayon::cyan(cs_label)}"
          )
        }, error = function(e) {
          cli::cli_alert_danger(
            "Error extracting included codes for {concept_set$label}: {e$message}"
          )
        })
      }

      # Save the workbook
      openxlsx2::wb_save(wb, file = output_file, overwrite = TRUE)
      cli::cli_alert_success("Included codes extracted and saved to: {fs::path_rel(output_file)}")

      invisible(NULL)
    }
  )
)
