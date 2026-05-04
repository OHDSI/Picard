#' ConceptSetDef R6 Class
#'
#' An R6 class that stores key information about OHDSI CIRCE concept sets that need to be
#' managed in a study.
#'
#' @details
#' The ConceptSetDef class manages concept set metadata, JSON definitions, and domain information.
#' Upon initialization, it loads and validates concept set definitions from CIRCE JSON files,
#' creates a hash to uniquely identify the generated JSON, and stores domain and source concept information.
#'
#' @export
ConceptSetDef <- R6::R6Class(
  classname = "ConceptSetDef",
  private = list(
    .label = NULL,
    .tags = NULL,
    .filePath = NULL,
    .json = NULL,
    .hash = NULL,
    .id = NULL,

    # Load JSON from file
    load_json_from_file = function(filePath) {
      if (!file.exists(filePath)) {
        stop("File does not exist: ", filePath)
      }

      file_ext <- tolower(tools::file_ext(filePath))

      if (file_ext != "json") {
        stop("Concept set file must be .json, got: .", file_ext)
      }

      # Load and validate JSON as CIRCE concept set
      json_content <- readr::read_file(filePath)

      # Validate JSON is valid CIRCE using CirceR
      tryCatch(
        CirceR::conceptSetExpressionFromJson(json_content),
        error = function(e) {
          stop("JSON file is not valid CIRCE concept set format: ", filePath, "\nError: ", e$message)
        }
      )

      # Store JSON string
      private$.json <- json_content

      # Create hash of JSON string
      private$.hash <- rlang::hash(private$.json)
    }
  ),

  public = list(
    #' @description Initialize a new ConceptSetDef
    #'
    #' @param label Character. The common name of the concept set.
    #' @param tags List. A named list of tags that give metadata about the concept set.
    #' @param filePath Character. Path to the concept set JSON file in inputs/conceptSet folder.
    #' @param sourceCode Logical. Whether the concept set uses source concepts (TRUE) or standard concepts (FALSE).
    #' @param domain Character. The OMOP CDM clinical domain for this concept set. 
    #'   Valid values: "drug_exposure", "condition_occurrence", "measurement", "procedure", "observation", "device_exposure", "visit_occurrence", "init".
    initialize = function(label, tags = list(), filePath, domain = "init") {
      checkmate::assert_string(x = label, min.chars = 1)
      checkmate::assert_list(x = tags, names = "named")
      checkmate::assert_file_exists(x = filePath)

      # Validate domain
      valid_domains <- c("drug_exposure", "condition_occurrence", "measurement", "procedure", 
        "observation", "device_exposure", "visit_occurrence", "init")
      if (!(domain %in% valid_domains)) {
        stop("Invalid domain '", domain, "'. Valid domains: ", paste(valid_domains, collapse = ", "))
      }
      tags <- c(tags, list(domain = domain))
      private$.label <- label
      private$.tags <- tags
      private$.filePath <- filePath

      # Load JSON and generate hash
      private$load_json_from_file(filePath)

      # Concept set ID will be assigned later when listed within the ConceptSetManifest
      private$.id <- NA_integer_
    },

    #' Get the file path
    #'
    #' @return Character. Relative path to the concept set file.
    getFilePath = function() {
      fs::path_rel(private$.filePath)
    },

    #' Get the concept set JSON
    #'
    #' @return Character. The JSON definition of the concept set.
    getJson = function() {
      private$.json
    },

    #' Get the JSON hash
    #'
    #' @return Character. MD5 hash of the current JSON definition.
    getHash = function() {
      private$.hash
    },

    #' Get the concept set ID
    #'
    #' @return Integer. The concept set ID, or NA_integer_ if not set.
    getId = function() {
      private$.id
    },

    #' Set the concept set ID (internal use)
    #'
    #' @param id Integer. The concept set ID to set.
    setId = function(id) {
      checkmate::assert_int(x = id)
      private$.id <- id
    },

    #' Format tags as string
    #'
    #' @return Character. Tags formatted as "name: value | name: value".
    formatTagsAsString = function() {
      if (length(private$.tags) == 0) {
        return("")
      }
      tags_str <- mapply(
        function(name, value) {
          paste0(name, ": ", value)
        },
        names(private$.tags),
        private$.tags,
        SIMPLIFY = TRUE
      )
      paste(tags_str, collapse = " | ")
    }
  ),

  active = list(
    #' @field label character to set the label to. If missing, returns the current label.
    label = function(label) {
      if (missing(label)) {
        private[[".label"]]
      } else {
        checkmate::assert_string(x = label, min.chars = 1)
        private[[".label"]] <- label
      }
    },

    #' @field tags list of the values to set the tags to. If missing, returns the current tags.
    tags = function(tags) {
      if (missing(tags)) {
        private[[".tags"]]
      } else {
        checkmate::assert_list(x = tags, names = "named")
        private[[".tags"]] <- tags
      }
    }
  )
)

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
          tags TEXT,
          filePath TEXT NOT NULL,
          hash TEXT NOT NULL,
          timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
          status TEXT DEFAULT 'active',
          deleted_at DATETIME DEFAULT NULL
        )"
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
        "SELECT id, label, tags, filePath FROM concept_set_manifest WHERE status = 'active' ORDER BY id"
      )

      private$.manifest <- list()

      if (nrow(db_records) == 0) {
        invisible(NULL)
      }

      for (i in seq_len(nrow(db_records))) {
        rec <- db_records[i, ]
        file_path <- private$resolve_file_path(rec$filePath)

        if (!file.exists(file_path)) {
          cli::cli_alert_warning("Concept set file missing, skipping: {rec$label} ({rec$filePath})")
          next
        }

        tryCatch({
          cs_def <- ConceptSetDef$new(label = rec$label, filePath = file_path)
          cs_def$setId(as.integer(rec$id))

          if (!is.na(rec$tags) && nchar(rec$tags) > 0) {
            cs_def$tags <- parseTagsString(rec$tags)
          }

          private$.manifest[[length(private$.manifest) + 1]] <- cs_def
        }, error = function(e) {
          cli::cli_alert_danger("Error loading concept set {rec$label}: {e$message}")
        })
      }

      invisible(NULL)
    },

    # Insert a new concept set record into SQLite and refresh the in-memory manifest
    insert_concept_set = function(label, tags, file_path) {
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

      # Serialize tags to "name: value | ..." string
      tags_str <- if (length(tags) > 0) {
        parts <- mapply(function(n, v) paste0(n, ": ", v), names(tags), tags, SIMPLIFY = TRUE)
        paste(parts, collapse = " | ")
      } else {
        ""
      }

      rel_path <- fs::path_rel(file_path)

      DBI::dbExecute(
        conn,
        "INSERT INTO concept_set_manifest (id, label, tags, filePath, hash, timestamp, status)
         VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP, 'active')",
        list(next_id, label, tags_str, rel_path, hash)
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
          "SELECT id, label, filePath, status FROM concept_set_manifest WHERE status = 'active'"
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
    }
  ),

  public = list(
    #' @description Initialize a new ConceptSetManifest
    #'
    #' @param dbPath Character. Path to the SQLite database. Defaults to
    #'   "inputs/conceptSets/conceptSetManifest.sqlite". The directory is created
    #'   automatically if it does not exist.
    #' @param executionSettings ExecutionSettings object. (Optional) Execution settings
    #'   for accessing the vocabulary database. Defaults to NULL. Only required for
    #'   operations like extractSourceCodes().
    initialize = function(dbPath = "inputs/conceptSets/conceptSetManifest.sqlite", executionSettings = NULL) {
      private$.dbPath <- dbPath
      private$.manifest <- list()

      checkmate::assert_class(x = executionSettings, classes = "ExecutionSettings", null.ok = TRUE)
      private$.executionSettings <- executionSettings

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

    #' Tabulate the manifest as a data frame
    #'
    #' @return Data frame. Manifest data with columns: id, label, tags, filePath, hash, timestamp
    tabulateManifest = function() {
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))
      man <- DBI::dbGetQuery(
          conn, "SELECT id, label, tags, filePath, hash, timestamp FROM concept_set_manifest ORDER BY id"
      )
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
    #' @param domain Character. OMOP CDM domain. One of `"drug_exposure"`,
    #'   `"condition_occurrence"`, `"measurement"`, `"procedure"`, `"observation"`,
    #'   `"device_exposure"`, `"visit_occurrence"`, `"init"`. Defaults to `"init"`.
    #' @param tags Named list. Optional extra metadata tags. Defaults to `list()`.
    #'
    #' @return Invisible integer. The assigned concept set ID.
    addConceptSetFile = function(filePath, label, domain = "init", tags = list()) {
      checkmate::assert_file_exists(filePath)
      checkmate::assert_string(label, min.chars = 1)
      valid_domains <- c("drug_exposure", "condition_occurrence", "measurement", "procedure",
                         "observation", "device_exposure", "visit_occurrence", "init")
      checkmate::assert_choice(domain, valid_domains)
      checkmate::assert_list(tags, names = "named")

      ext <- tolower(tools::file_ext(filePath))

      if (ext != "json") {
        cli::cli_abort("filePath must be a .json file, got: .{ext}")
      }

      # Merge domain into tags
      all_tags <- c(tags, list(domain = domain))

      cs_id <- private$insert_concept_set(
        label = label,
        tags = all_tags,
        file_path = filePath
      )

      cli::cli_alert_success("Added concept set {cs_id}: {label}")
      invisible(cs_id)
    },

    #' @description Fetch a single concept set from ATLAS and register it in the manifest
    #'
    #' @param atlasId Integer. The ATLAS concept set definition ID.
    #' @param label Character. Display name for the concept set.
    #' @param domain Character. OMOP CDM domain. Defaults to `"init"`.
    #' @param tags Named list. Optional extra metadata tags. Defaults to `list()`.
    #' @param atlasConnection An ATLAS connection object with a
    #'   `getConceptSetDefinition(conceptSetId)` method that returns a list with
    #'   `expression` (CIRCE JSON string) and `saveName` elements.
    #'   If `NULL`, falls back to the connection stored via `$setAtlasConnection()`.
    #'
    #' @return Invisible integer. The assigned concept set ID.
    addAtlasConceptSet = function(atlasId, label, domain = "init", tags = list(), atlasConnection = NULL) {
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
      valid_domains <- c("drug_exposure", "condition_occurrence", "measurement", "procedure",
                         "observation", "device_exposure", "visit_occurrence", "init")
      checkmate::assert_choice(domain, valid_domains)
      checkmate::assert_list(tags, names = "named")

      # Merge domain into tags
      all_tags <- c(tags, list(domain = domain))

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
      writeLines(expression_json, json_path)

      cs_id <- private$insert_concept_set(
        label = label,
        tags = all_tags,
        file_path = json_path
      )

      cli::cli_alert_success("Added ATLAS concept set {cs_id}: {label}")
      invisible(cs_id)
    },

    #' @description Export a Capr ConceptSet to JSON and register it in the manifest
    #'
    #' @param caprConceptSet A Capr `ConceptSet` object.
    #' @param label Character. Display name for the concept set.
    #' @param domain Character. OMOP CDM domain. Defaults to `"init"`.
    #' @param tags Named list. Optional extra metadata tags. Defaults to `list()`.
    #'
    #' @return Invisible integer. The assigned concept set ID.
    addCaprConceptSet = function(caprConceptSet, label, domain = "init", tags = list()) {
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
      valid_domains <- c("drug_exposure", "condition_occurrence", "measurement", "procedure",
                         "observation", "device_exposure", "visit_occurrence", "init")
      checkmate::assert_choice(domain, valid_domains)
      checkmate::assert_list(tags, names = "named")

      # Merge domain into tags
      all_tags <- c(tags, list(domain = domain))

      concept_sets_dir <- dirname(private$.dbPath)
      json_dir <- fs::path(concept_sets_dir, "json")

      if (!dir.exists(json_dir)) {
        dir.create(json_dir, recursive = TRUE)
      }

      safe_label <- gsub("[^a-zA-Z0-9_-]", "_", label)
      json_path <- fs::path(json_dir, paste0(safe_label, ".json"))
      Capr::writeCohort(caprConceptSet, json_path)

      cs_id <- private$insert_concept_set(
        label = label,
        tags = all_tags,
        file_path = json_path
      )

      cli::cli_alert_success("Added Capr concept set {cs_id}: {label}")
      invisible(cs_id)
    },

    #' @description Batch-import concept sets from ATLAS via a conceptSetsLoad CSV
    #'
    #' Reads a CSV with columns `atlasId`, `label`, `domain` (required) plus any
    #' additional columns treated as tag key-value pairs. Calls
    #' `addAtlasConceptSet()` for each row inside a `tryCatch` so a single failure
    #' does not abort the entire batch.
    #'
    #' @param atlasConnection An ATLAS connection object with a
    #'   `getConceptSetDefinition(conceptSetId)` method.
    #'   If `NULL`, falls back to the connection stored via `$setAtlasConnection()`.
    #' @param conceptSetsLoadPath Character. Path to the CSV file. Defaults to
    #'   `here::here("inputs/conceptSets/conceptSetsLoad.csv")`.
    #'
    #' @return Invisible tibble with columns `id`, `label`, `status`.
    importAtlasConceptSets = function(atlasConnection = NULL,
                                      conceptSetsLoadPath = here::here("inputs/conceptSets/conceptSetsLoad.csv")) {
      if (is.null(atlasConnection)) {
        atlasConnection <- private$.atlasConnection
      }

      if (is.null(atlasConnection)) {
        cli::cli_abort(c(
          "No ATLAS connection available.",
          i = "Supply {.arg atlasConnection} or call {.code $setAtlasConnection()} first."
        ))
      }

      checkmate::assert_file_exists(conceptSetsLoadPath)
      concept_sets_load <- readr::read_csv(conceptSetsLoadPath, show_col_types = FALSE, comment = "#")

      required_cols <- c("atlasId", "label", "domain")
      missing_cols <- setdiff(required_cols, names(concept_sets_load))

      if (length(missing_cols) > 0) {
        cli::cli_abort("conceptSetsLoad.csv missing required columns: {paste(missing_cols, collapse = ', ')}")
      }

      reserved_cols <- c("atlasId", "label", "domain")
      tag_cols <- setdiff(names(concept_sets_load), reserved_cols)

      cli::cli_alert_info(
        "Importing {nrow(concept_sets_load)} concept set(s) from {fs::path_rel(conceptSetsLoadPath)}"
      )

      results <- vector("list", nrow(concept_sets_load))

      for (i in seq_len(nrow(concept_sets_load))) {
        row <- concept_sets_load[i, ]

        tags <- list()

        for (col in tag_cols) {
          val <- row[[col]]
          if (!is.na(val) && nchar(as.character(val)) > 0) {
            tags[[col]] <- as.character(val)
          }
        }

        tryCatch({
          cs_id <- self$addAtlasConceptSet(
            atlasId = as.integer(row$atlasId),
            label = as.character(row$label),
            domain = as.character(row$domain),
            tags = tags,
            atlasConnection = atlasConnection
          )
          results[[i]] <- list(id = cs_id, label = as.character(row$label), status = "success")
        }, error = function(e) {
          cli::cli_alert_danger("Failed to import {row$label}: {e$message}")
          results[[i]] <<- list(id = NA_integer_, label = as.character(row$label),
                                status = paste("error:", e$message))
        })
      }

      result_df <- tibble::tibble(
        id     = vapply(results, function(x) if (is.null(x$id)) NA_integer_ else as.integer(x$id), integer(1)),
        label  = vapply(results, function(x) x$label, character(1)),
        status = vapply(results, function(x) x$status, character(1))
      )

      successful <- sum(result_df$status == "success")
      cli::cli_alert_success("Imported {successful}/{nrow(concept_sets_load)} concept set(s)")
      invisible(result_df)
    },

    #' Query concept sets by IDs
    #'
    #' @param ids Integer vector. One or more concept set IDs.
    #'
    #' @return Data frame. A subset of the manifest with columns id, label, tags, filePath, hash, timestamp for matching concept sets, or NULL if none found.
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

      # Convert matching concept sets to data frame
      manifest_df <- data.frame(
        id = integer(),
        label = character(),
        tags = character(),
        filePath = character(),
        hash = character(),
        timestamp = character(),
        stringsAsFactors = FALSE
      )

      for (concept_set in matching_concept_sets) {
        manifest_df <- rbind(manifest_df, data.frame(
          id = concept_set$getId(),
          label = concept_set$label,
          tags = concept_set$formatTagsAsString(),
          filePath = concept_set$getFilePath(),
          hash = concept_set$getHash(),
          timestamp = NA_character_,
          stringsAsFactors = FALSE
        ))
      }

      # Get timestamps from database
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      for (i in seq_len(nrow(manifest_df))) {
        cs_id <- manifest_df$id[i]
        timestamp_record <- DBI::dbGetQuery(
          conn,
          "SELECT timestamp FROM concept_set_manifest WHERE id = ?",
          list(cs_id)
        )
        if (nrow(timestamp_record) > 0) {
          manifest_df$timestamp[i] <- timestamp_record$timestamp[1]
        }
      }

      return(manifest_df)
    },

    #' Query concept sets by tag
    #'
    #' @param tagStrings Character vector. One or more tags in the format "name: value"
    #'   (e.g., "category: primary"). When multiple tags are supplied, the \code{match}
    #'   argument controls whether a concept set must satisfy any or all of them.
    #' @param match Character. "any" (default) returns concept sets matching at least one tag;
    #'   "all" returns only concept sets matching every tag.
    #'
    #' @return Data frame. A subset of the manifest with columns id, label, tags, filePath, hash, timestamp for matching concept sets, or NULL if none found.
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

      # Convert matching concept sets to data frame
      manifest_df <- data.frame(
        id = integer(),
        label = character(),
        tags = character(),
        filePath = character(),
        hash = character(),
        timestamp = character(),
        stringsAsFactors = FALSE
      )

      for (concept_set in matching_concept_sets) {
        manifest_df <- rbind(manifest_df, data.frame(
          id = concept_set$getId(),
          label = concept_set$label,
          tags = concept_set$formatTagsAsString(),
          filePath = concept_set$getFilePath(),
          hash = concept_set$getHash(),
          timestamp = NA_character_,
          stringsAsFactors = FALSE
        ))
      }

      # Get timestamps from database
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      for (i in seq_len(nrow(manifest_df))) {
        cs_id <- manifest_df$id[i]
        timestamp_record <- DBI::dbGetQuery(
          conn,
          "SELECT timestamp FROM concept_set_manifest WHERE id = ?",
          list(cs_id)
        )
        if (nrow(timestamp_record) > 0) {
          manifest_df$timestamp[i] <- timestamp_record$timestamp[1]
        }
      }

      return(manifest_df)
    },

    #' Query concept sets by label
    #'
    #' @param labels Character vector. One or more labels to search for.
    #'   A concept set is included when it matches at least one of the supplied labels (OR logic).
    #' @param matchType Character. Either "exact" for exact match or "pattern" for pattern matching.
    #'   Defaults to "exact".
    #'
    #' @return Data frame. A subset of the manifest with columns id, label, tags, filePath, hash, timestamp for matching concept sets, or NULL if none found.
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

      # Convert matching concept sets to data frame
      manifest_df <- data.frame(
        id = integer(),
        label = character(),
        tags = character(),
        filePath = character(),
        hash = character(),
        timestamp = character(),
        stringsAsFactors = FALSE
      )

      for (concept_set in matching_concept_sets) {
        manifest_df <- rbind(manifest_df, data.frame(
          id = concept_set$getId(),
          label = concept_set$label,
          tags = concept_set$formatTagsAsString(),
          filePath = concept_set$getFilePath(),
          hash = concept_set$getHash(),
          timestamp = NA_character_,
          stringsAsFactors = FALSE
        ))
      }

      # Get timestamps from database
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      for (i in seq_len(nrow(manifest_df))) {
        cs_id <- manifest_df$id[i]
        timestamp_record <- DBI::dbGetQuery(
          conn,
          "SELECT timestamp FROM concept_set_manifest WHERE id = ?",
          list(cs_id)
        )
        if (nrow(timestamp_record) > 0) {
          manifest_df$timestamp[i] <- timestamp_record$timestamp[1]
        }
      }

      return(manifest_df)
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
          "SELECT id, label, filePath, status, deleted_at FROM concept_set_manifest ORDER BY id"
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
      db_records$file_exists <- sapply(db_records$filePath, function(p) file.exists(private$resolve_file_path(p)))
      
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
    #' @param reason Character. Optional reason for deletion.
    #'
    #' @return Invisibly returns TRUE if successful, FALSE otherwise.
    deleteConceptSet = function(id, reason = NULL) {
      checkmate::assert_int(id)
      
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))
      
      # Check if concept set exists
      exists <- DBI::dbGetQuery(
        conn,
        "SELECT COUNT(*) as count FROM concept_set_manifest WHERE id = ?",
        list(id)
      )$count > 0
      
      if (!exists) {
        cli::cli_alert_danger("Concept set with ID {id} not found in manifest")
        invisible(FALSE)
      }
      
      # Update status and set deleted_at timestamp
      tryCatch({
        DBI::dbExecute(
          conn,
          "UPDATE concept_set_manifest SET status = 'deleted', deleted_at = CURRENT_TIMESTAMP WHERE id = ?",
          list(id)
        )
        
        # Get label for display
        label_result <- DBI::dbGetQuery(
          conn,
          "SELECT label FROM concept_set_manifest WHERE id = ?",
          list(id)
        )
        label <- if (nrow(label_result) > 0) label_result$label[1] else "Unknown"
        
        reason_msg <- if (!is.null(reason)) glue::glue(" ({reason})") else ""
        cli::cli_alert_success("Deleted concept set {id}: {label}{reason_msg}")
        invisible(TRUE)
      }, error = function(e) {
        cli::cli_alert_danger("Failed to delete concept set {id}: {e$message}")
        invisible(FALSE)
      })
    },

    #' @description Permanently delete a concept set (removes the record from database, irreversible)
    #'
    #' @param id Integer. The concept set ID to permanently remove.
    #' @param confirm Logical. Must be TRUE to proceed; prevents accidental deletion. Defaults to FALSE.
    #'
    #' @return Invisibly returns TRUE if successful, FALSE otherwise.
    permanentlyDeleteConceptSet = function(id, confirm = FALSE) {
      checkmate::assert_int(id)

      if (!isTRUE(confirm)) {
        cli::cli_abort(
          "permanentlyDeleteConceptSet() is irreversible. Set confirm = TRUE to proceed."
        )
      }

      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))
      
      # Check if concept set exists
      cs_info <- DBI::dbGetQuery(
        conn,
        "SELECT label, status FROM concept_set_manifest WHERE id = ?",
        list(id)
      )
      
      if (nrow(cs_info) == 0) {
        cli::cli_alert_danger("Concept set with ID {id} not found")
        invisible(FALSE)
      }
      
      label <- cs_info$label[1]
      status <- cs_info$status[1]
      
      # Hard delete
      tryCatch({
        DBI::dbExecute(
          conn,
          "DELETE FROM concept_set_manifest WHERE id = ?",
          list(id)
        )
        
        cli::cli_alert_warning("Permanently removed concept set {id}: {label} (status was: {status})")
        invisible(TRUE)
      }, error = function(e) {
        cli::cli_alert_danger("Failed to remove concept set {id}: {e$message}")
        invisible(FALSE)
      })
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
    #' @return Data frame with columns: id, label, action
    #'   (\code{"added"}, \code{"hash_updated"}, \code{"missing_flagged"}, or \code{"unchanged"}).
    syncManifest = function() {
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
        "SELECT id, label, tags, filePath, hash, status
         FROM concept_set_manifest"
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
        file_path  <- private$resolve_file_path(rec$filePath)

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
          tmp_def <- ConceptSetDef$new(label = rec_label, tags = list(), filePath = file_path)
          new_hash <- tmp_def$getHash()

          if (new_hash != rec$hash) {
            DBI::dbExecute(
              conn,
              "UPDATE concept_set_manifest SET hash = ?, timestamp = CURRENT_TIMESTAMP WHERE id = ?",
              list(new_hash, rec_id)
            )
            # Update in-memory entry if present
            idx <- which(sapply(private$.manifest, function(cs) cs$getId() == rec_id))

            if (length(idx) > 0) {
              tmp_def$setId(as.integer(rec_id))

              if (!is.na(rec$tags) && rec$tags != "") {
                tmp_def$tags <- picard::parseTagsString(rec$tags)
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
      existing_rel <- db_records$filePath  # stored as relative paths
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
            "INSERT INTO concept_set_manifest (id, label, tags, filePath, hash, timestamp, status)
             VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP, 'active')",
            list(next_id, label, "", new_def$getFilePath(), new_def$getHash())
          )

          private$.manifest[[length(private$.manifest) + 1]] <- new_def
          cli::cli_alert_success("Added: {label} (ID {next_id})")
          results <- rbind(results, data.frame(id = next_id, label = label,
                                               action = "added", stringsAsFactors = FALSE))
        }, error = function(e) {
          cli::cli_alert_danger("Error adding {label}: {e$message}")
        })
      }

      # ── Summary ──────────────────────────────────────────────────────────────
      n_added   <- sum(results$action == "added")
      n_updated <- sum(results$action == "hash_updated")
      n_missing <- sum(results$action == "missing_flagged")
      n_same    <- sum(results$action == "unchanged")
      cli::cli_rule()
      cli::cli_alert_success(
        "Sync complete — Added: {n_added} | Updated: {n_updated} | Missing: {n_missing} | Unchanged: {n_same}"
      )

      return(results)
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
      on.exit(settings$disconnect())


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
