#' CohortDef R6 Class
#'
#' An R6 class that stores key information about cohorts managed by the CohortManifest.
#' Each CohortDef is a pointer to a file on disk (JSON or SQL) with associated metadata.
#'
#' @details
#' The CohortDef class manages cohort metadata and SQL generation.
#' Upon initialization, it loads and validates cohort definitions from either
#' JSON (CIRCE format) or SQL files, and creates a hash to uniquely identify
#' the generated SQL.
#'
#' @export
CohortDef <- R6::R6Class(
  classname = "CohortDef",
  private = list(
    .label = NULL,
    .category = NULL,
    .tags = NULL,
    .filePath = NULL,
    .sql = NULL,
    .hash = NULL,
    .id = NULL,
    .sourceType = NULL,
    .cohortType = "circe",

    # Load SQL from file
    load_sql_from_file = function(filePath) {
      if (!file.exists(filePath)) {
        stop("File does not exist: ", filePath)
      }

      file_ext <- tolower(tools::file_ext(filePath))

      if (file_ext == "sql") {
        # Load SQL file directly
        private$.sql <- readChar(filePath, file.info(filePath)$size)
      } else if (file_ext == "json") {
        # Load and validate JSON as CIRCE cohort
        json_content <- readr::read_file(filePath)
        # Validate JSON is valid CIRCE using CirceR
        tryCatch(
          CirceR::cohortExpressionFromJson(json_content),
          error = function(e) {
            stop("JSON file is not valid CIRCE format: ", filePath, "\nError: ", e$message)
          }
        )

        # Render JSON to SQL
        private$.sql <- CirceR::buildCohortQuery(json_content, options = CirceR::createGenerateOptions(generateStats = TRUE))
      } else {
        stop("File must be either .sql or .json, got: .", file_ext)
      }

      # Create hash of SQL string
      private$.hash <- rlang::hash(private$.sql)
    }
  ),

  public = list(
    #' @description Initialize a new CohortDef
    #'
    #' @param label Character. The common name of the cohort.
    #' @param category Character. Required classification (e.g., 'target', 'exposure', 'outcome').
    #' @param sourceType Character. Provenance: 'atlas', 'capr', 'sql', or 'derived'.
    #' @param tags List. A named list of tags that give metadata about the cohort.
    #' @param filePath Character. Path to the cohort file in inputs/cohorts folder (can be .json or .sql).
    initialize = function(label, category, sourceType, tags = list(), filePath) {
      checkmate::assert_string(x = label, min.chars = 1)
      checkmate::assert_string(x = category, min.chars = 1)
      checkmate::assert_choice(x = sourceType, choices = c("atlas", "capr", "sql", "derived"))
      checkmate::assert_list(x = tags, names = "named")
      checkmate::assert_file_exists(x = filePath)

      private$.label <- label
      private$.category <- category
      private$.sourceType <- sourceType
      private$.tags <- tags
      private$.filePath <- filePath

      # Load SQL and generate hash
      private$load_sql_from_file(filePath)

      # Cohort ID will be assigned later when listed within the CohortManifest
      private$.id <- NA_integer_
    },

    #' Get the file path
    #'
    #' @return Character. Relative path to the cohort file.
    getFilePath = function() {
      fs::path_rel(private$.filePath)
    },

    #' Get the generated SQL
    #'
    #' @return Character. The SQL definition of the cohort.
    getSql = function() {
      private$.sql
    },

    #' Get the SQL hash
    #'
    #' @return Character. MD5 hash of the current SQL definition.
    getHash = function() {
      private$.hash
    },

    #' Get the cohort ID
    #'
    #' @return Integer. The cohort ID, or NA_integer_ if not set.
    getId = function() {
      private$.id
    },

    #' Set the cohort ID (internal use)
    #'
    #' @param id Integer. The cohort ID to set.
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
    },

    #' Get the cohort type
    #'
    #' @return Character. One of 'circe', 'custom', 'subset', 'union', 'complement', 'composite'.
    getCohortType = function() {
      private$.cohortType
    },

    #' Set the cohort type (internal use)
    #'
    #' @param cohortType Character. One of 'circe', 'custom', 'subset', 'union', 'complement', 'composite'.
    setCohortType = function(cohortType) {
      checkmate::assert_choice(x = cohortType, choices = c("circe", "custom", "subset", "union", "complement", "composite"))
      private$.cohortType <- cohortType
    },

    #' Get the source type
    #'
    #' @return Character. One of 'atlas', 'capr', 'sql', 'derived'.
    getSourceType = function() {
      private$.sourceType
    },

    #' Get the category
    #'
    #' @return Character. The cohort category (e.g., 'target', 'exposure', 'outcome').
    getCategory = function() {
      private$.category
    },

    #' Set the category
    #'
    #' @param category Character. The cohort category.
    setCategory = function(category) {
      checkmate::assert_string(x = category, min.chars = 1)
      private$.category <- category
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
    },

    #' @field category character to set the category to. If missing, returns the current category.
    category = function(category) {
      if (missing(category)) {
        private[[".category"]]
      } else {
        checkmate::assert_string(x = category, min.chars = 1)
        private[[".category"]] <- category
      }
    }
  )
)

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

      if (db_exists) {
        cli::cli_alert_warning("Manifest already exists at {dbPath}.")
      }
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
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      # Get next available ID
      max_id_result <- DBI::dbGetQuery(conn, "SELECT MAX(id) as max_id FROM cohort_manifest")
      next_id <- if (is.na(max_id_result$max_id[1])) 1L else as.integer(max_id_result$max_id[1]) + 1L

      # Compute hash from file
      hash <- if (file.exists(file_path)) {
        file_content <- readChar(file_path, file.info(file_path)$size)
        rlang::hash(file_content)
      } else {
        rlang::hash(label)
      }

      # Serialize tags to JSON
      tags_json <- if (length(tags) > 0) {
        jsonlite::toJSON(tags, auto_unbox = TRUE)
      } else {
        NA_character_
      }

      # Serialize depends_on to JSON array
      depends_on_json <- if (!is.null(depends_on) && length(depends_on) > 0) {
        jsonlite::toJSON(as.integer(depends_on), auto_unbox = FALSE)
      } else {
        NA_character_
      }

      # Serialize dependency_rule to JSON
      dep_rule_json <- if (!is.null(dependency_rule) && length(dependency_rule) > 0) {
        jsonlite::toJSON(dependency_rule, auto_unbox = TRUE)
      } else {
        NA_character_
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

    # ========== PRIVATE HELPER METHODS FOR DEPENDENCY MANAGEMENT ==========

    # Build a dependency graph from all cohorts in the manifest
    #
    # Creates an adjacency list representation of dependencies.
    # Returns a list where each cohort ID maps to a vector of cohorts it depends on.
    build_dependency_graph = function() {
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      rows <- DBI::dbGetQuery(
        conn,
        "SELECT id, depends_on FROM cohort_manifest WHERE status = 'active'"
      )

      graph <- list()
      for (i in seq_len(nrow(rows))) {
        cohort_id <- rows$id[i]
        depends_on_raw <- rows$depends_on[i]

        parent_ids <- if (!is.na(depends_on_raw) && nchar(depends_on_raw) > 0) {
          as.integer(jsonlite::fromJSON(depends_on_raw))
        } else {
          integer(0)
        }

        graph[[as.character(cohort_id)]] <- parent_ids
      }

      return(graph)
    },

    # Validate that the dependency graph has no cycles (is a DAG)
    #
    # Uses depth-first search to detect cycles. Throws an error if a cycle is found.
    validate_no_cycles = function(graph) {
      # DFS-based cycle detection using color marking (white/gray/black)
      state <- new.env()
      state$colors <- rep("white", length(graph))
      names(state$colors) <- names(graph)
      state$cycle_found <- FALSE
      state$cycle_msg <- ""

      visit_node <- function(node_id) {
        state$colors[[node_id]] <- "gray"

        deps <- graph[[node_id]]
        if (length(deps) > 0) {
          for (dep_id in deps) {
            if (state$cycle_found) return()

            dep_str <- as.character(dep_id)
            if (!dep_str %in% names(graph)) {
              cli::cli_abort("Cohort {node_id} depends on non-existent cohort {dep_id}")
            }

            color <- state$colors[[dep_str]]
            if (color == "gray") {
              state$cycle_found <- TRUE
              state$cycle_msg <- paste0("Circular dependency detected: Cohort ", node_id, " -> ", dep_id)
              return()
            } else if (color == "white") {
              visit_node(dep_str)
            }
          }
        }

        state$colors[[node_id]] <- "black"
      }

      # Visit all nodes
      for (node in names(graph)) {
        if (state$cycle_found) break
        if (state$colors[[node]] == "white") {
          visit_node(node)
        }
      }

      if (state$cycle_found) {
        cli::cli_abort(state$cycle_msg)
      }

      cli::cli_alert_success("No circular dependencies detected")
    },

    # Topologically sort cohorts by dependencies
    #
    # Returns a vector of cohort IDs in execution order (dependencies before dependents).
    topological_sort = function(graph) {
      # Kahn's algorithm: in-degree based topological sort
      in_degree <- rep(0L, length(graph))
      names(in_degree) <- names(graph)

      # Build reverse graph: node -> nodes that depend on it
      reverse_graph <- setNames(
        lapply(names(graph), function(x) integer()),
        names(graph)
      )

      # Calculate in-degrees and build reverse edges
      for (node_id in names(graph)) {
        deps <- graph[[node_id]]
        if (length(deps) > 0) {
          # node_id depends on these nodes, so node_id has incoming edges
          in_degree[[node_id]] <- in_degree[[node_id]] + length(deps)

          # Build reverse edges: each dependency has an outgoing edge to node_id
          for (dep_id in deps) {
            dep_str <- as.character(dep_id)
            if (dep_str %in% names(reverse_graph)) {
              reverse_graph[[dep_str]] <- c(reverse_graph[[dep_str]], as.integer(node_id))
            }
          }
        }
      }

      # Initialize queue with nodes having in_degree = 0 (no dependencies)
      queue <- as.integer(names(in_degree[in_degree == 0]))
      sorted_order <- integer()

      # Process nodes in topological order
      while (length(queue) > 0) {
        node_id <- queue[1]
        queue <- queue[-1]
        sorted_order <- c(sorted_order, node_id)

        # For each node that depends on this node, decrement its in-degree
        dependents <- reverse_graph[[as.character(node_id)]]
        if (length(dependents) > 0) {
          for (dependent_id in dependents) {
            dependent_str <- as.character(dependent_id)
            in_degree[[dependent_str]] <- in_degree[[dependent_str]] - 1L

            if (in_degree[[dependent_str]] == 0) {
              queue <- c(queue, as.integer(dependent_id))
            }
          }
        }
      }

      # Verify all nodes were processed
      if (length(sorted_order) != length(graph)) {
        cli::cli_abort("Topological sort failed - possible circular dependency")
      }

      return(sorted_order)
    },

    expand_metadata_parameters = function(metadata, sql_params, field_mapping) {
      for (meta_field in names(field_mapping)) {
        if (!is.null(metadata[[meta_field]])) {
          sql_param_name <- field_mapping[[meta_field]]
          sql_params[[sql_param_name]] <- metadata[[meta_field]]

          # For vector-type params, also add count
          if (grepl("_ids$", meta_field)) {
            count_param <- paste0(sql_param_name, "_count")
            sql_params[[count_param]] <- length(metadata[[meta_field]])
          }
        }
      }
      return(sql_params)
    },

    # Compute dependency hash for a dependent cohort
    # Combines parent cohort hashes with the dependency rule parameters.
    compute_dependency_hash = function(cohort, parent_hashes) {
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      cohort_id <- cohort$getId()
      row <- DBI::dbGetQuery(
        conn,
        "SELECT depends_on, dependency_rule FROM cohort_manifest WHERE id = ? AND status = 'active'",
        list(cohort_id)
      )

      parent_ids <- if (nrow(row) > 0 && !is.na(row$depends_on[1]) && nchar(row$depends_on[1]) > 0) {
        as.integer(jsonlite::fromJSON(row$depends_on[1]))
      } else {
        integer(0)
      }

      rule <- if (nrow(row) > 0 && !is.na(row$dependency_rule[1]) && nchar(row$dependency_rule[1]) > 0) {
        jsonlite::fromJSON(row$dependency_rule[1], simplifyVector = FALSE)
      } else {
        list()
      }

      # Combine parent hashes in dependency order
      parent_hash_strs <- character()
      for (pid in parent_ids) {
        pid_str <- as.character(pid)
        if (pid_str %in% names(parent_hashes)) {
          parent_hash_strs <- c(parent_hash_strs, parent_hashes[[pid_str]])
        }
      }

      # Serialize the rule (dependency parameters)
      rule_json <- jsonlite::toJSON(rule, auto_unbox = TRUE)

      # Combine: parent hashes + rule parameters
      combined <- paste0(
        paste(parent_hash_strs, collapse = "|"),
        "|",
        rule_json
      )
      md5Hash <- rlang::hash(combined)
      return(md5Hash)
    },

    # Cascade 'stale' status to all transitive downstream dependents of the
    # given cohort IDs. Only affects cohorts with status 'active' or 'stale'.
    # Returns invisibly the integer vector of IDs that were updated.
    cascade_stale_downstream = function(cohort_ids) {
      cohort_ids <- as.integer(cohort_ids)

      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      # Fetch all potentially relevant rows once
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

      # Bulk update to stale
      ids_str <- paste(visited, collapse = ", ")
      DBI::dbExecute(
        conn,
        paste0(
          "UPDATE cohort_manifest SET status = 'stale', updated_at = CURRENT_TIMESTAMP",
          " WHERE id IN (", ids_str, ")"
        )
      )

      # Report
      labels <- DBI::dbGetQuery(
        conn,
        paste0("SELECT id, label FROM cohort_manifest WHERE id IN (", ids_str, ")")
      )
      for (i in seq_len(nrow(labels))) {
        cli::cli_alert_warning(
          "Marked stale: [{labels$id[i]}] {labels$label[i]}"
        )
      }

      private$load_manifest_from_db()
      invisible(visited)
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
    #' composite) with parsed dependency information sourced directly from SQLite. Useful
    #' for quickly auditing what each derived cohort depends on and how it was built.
    #'
    #' @return A tibble with columns:
    #'   \itemize{
    #'     \item \code{id} - Cohort ID
    #'     \item \code{label} - Cohort label
    #'     \item \code{cohort_type} - One of 'union', 'subset', 'complement', 'composite'
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

      man <- DBI::dbGetQuery(conn, sql)
      return(tibble::as_tibble(man))
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
      writeLines(expression_json, json_path)

      # Register in manifest
      cohort_id <- private$insert_cohort(
        label = label,
        category = category,
        tags = tags,
        file_path = fs::path_rel(json_path),
        source_type = "atlas",
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
    #' @param atlasConnection An ATLAS connection object with a `getCohortDefinition(cohortId)` method.
    #'   If `NULL`, falls back to the connection stored via `$setAtlasConnection()`.
    #' @param cohortsLoadPath Character. Path to the CSV file. Defaults to
    #'   `here::here("inputs/cohorts/cohortsLoad.csv")`.
    #'
    #' @return Invisible tibble of imported cohorts.
    importAtlasCohorts = function(atlasConnection = NULL, cohortsLoadPath = here::here("inputs/cohorts/cohortsLoad.csv")) {
      if (is.null(atlasConnection)) {
        atlasConnection <- private$.atlasConnection
      }

      if (is.null(atlasConnection)) {
        cli::cli_abort(c(
          "No ATLAS connection available.",
          i = "Supply {.arg atlasConnection} or call {.code $setAtlasConnection()} first."
        ))
      }

      if (is.null(cohortsLoadPath)) {
        cohortsLoadPath <- here::here("inputs/cohorts/cohortsLoad.csv")
      }

      checkmate::assert_file_exists(cohortsLoadPath)
      cohorts_load <- readr::read_csv(cohortsLoadPath, show_col_types = FALSE, comment = "#")

      # Validate required columns
      required_cols <- c("atlasId", "label", "category", "file_name")
      missing_cols <- setdiff(required_cols, names(cohorts_load))
      if (length(missing_cols) > 0) {
        cli::cli_abort("cohortsLoad.csv missing required columns: {paste(missing_cols, collapse = ', ')}")
      }

      # Determine which columns are tags (everything beyond reserved)
      reserved_cols <- c("atlasId", "label", "category", "file_name")
      tag_cols <- setdiff(names(cohorts_load), reserved_cols)

      cli::cli_alert_info("Importing {nrow(cohorts_load)} cohort(s) from {fs::path_rel(cohortsLoadPath)}")

      results <- list()
      for (i in seq_len(nrow(cohorts_load))) {
        row <- cohorts_load[i, ]

        # Build tags from extra columns
        tags <- list()
        for (col in tag_cols) {
          val <- row[[col]]
          if (!is.na(val) && nchar(as.character(val)) > 0) {
            tags[[col]] <- as.character(val)
          }
        }

        tryCatch({
          cohort_id <- self$addAtlasCohort(
            atlasId = as.integer(row$atlasId),
            label = as.character(row$label),
            category = as.character(row$category),
            tags = tags,
            atlasConnection = atlasConnection
          )
          results[[length(results) + 1]] <- list(
            id = cohort_id, label = row$label, status = "success"
          )
        }, error = function(e) {
          cli::cli_alert_danger("Failed to import {row$label}: {e$message}")
          results[[length(results) + 1]] <<- list(
            id = NA_integer_, label = row$label, status = paste("error:", e$message)
          )
        })
      }

      result_df <- tibble::tibble(
        id = vapply(results, function(x) x$id %||% NA_integer_, integer(1)),
        label = vapply(results, function(x) x$label, character(1)),
        status = vapply(results, function(x) x$status, character(1)
      )
      )

      successful <- sum(result_df$status == "success")
      cli::cli_alert_success("Imported {successful}/{nrow(cohorts_load)} cohort(s)")

      invisible(result_df)
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

      # Register in manifest
      cohort_id <- private$insert_cohort(
        label = label,
        category = category,
        tags = tags,
        file_path = fs::path_rel(json_path),
        source_type = "capr",
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
    #'
    #' @return Invisible integer. The assigned cohort ID.
    addSqlCohort = function(filePath, label, category, tags = list()) {
      checkmate::assert_file_exists(filePath)
      checkmate::assert_string(label, min.chars = 1)
      checkmate::assert_string(category, min.chars = 1)
      checkmate::assert_list(tags, names = "named")

      # Validate file is SQL
      ext <- tolower(tools::file_ext(filePath))
      if (ext != "sql") {
        cli::cli_abort("filePath must be a .sql file, got: .{ext}")
      }

      # Validate label uniqueness
      private$validate_label_unique(label)

      # Validate file_path uniqueness
      rel_path <- fs::path_rel(filePath)
      private$validate_filepath_unique(rel_path)

      # Run portability validation
      sql_content <- readChar(filePath, file.info(filePath)$size)
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

    #' @description Build a union cohort from existing cohorts
    #'
    #' Creates a derived cohort that is the union of specified parent cohorts.
    #' Delegates SQL generation to the internal builder function.
    #'
    #' @param label Character. Display name for the derived cohort.
    #' @param cohortIds Integer vector. IDs of parent cohorts to union.
    #' @param category Character. Required classification.
    #' @param tags Named list. Optional metadata tags.
    #' @param gapDays Integer. Maximum gap between eras to merge. Default 0.
    #'
    #' @return Invisible integer. The assigned cohort ID.
    buildUnionCohort = function(label, cohortIds, category, tags = list(), gapDays = 0L) {
      checkmate::assert_string(label, min.chars = 1)
      checkmate::assert_integerish(cohortIds, min.len = 2, unique = TRUE)
      checkmate::assert_string(category, min.chars = 1)
      checkmate::assert_list(tags, names = "named")
      checkmate::assert_int(gapDays, lower = 0)

      private$validate_label_unique(label)
      private$validate_parent_cohorts_exist(cohortIds)

      # Build dependency rule
      dependency_rule <- list(cohortIds = as.integer(cohortIds), gapDays = gapDays)

      # Generate SQL via internal builder
      cohorts_dir <- dirname(private$.dbPath)
      derived_dir <- fs::path(cohorts_dir, "derived")
      if (!dir.exists(derived_dir)) dir.create(derived_dir, recursive = TRUE)

      safe_label <- gsub("[^a-zA-Z0-9_-]", "_", label)
      sql_path <- fs::path(derived_dir, paste0(safe_label, ".sql"))

      # Render union SQL template
      sql_template <- readLines(system.file("sql", "createUnionCohort.sql", package = "picard"), warn = FALSE)
      sql_content <- paste(sql_template, collapse = "\n")
      writeLines(sql_content, sql_path)

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
    #' @param baseCohortId Integer. ID of the base cohort to subset.
    #' @param filterCohortId Integer. ID of the filter cohort.
    #' @param category Character. Required classification.
    #' @param startWindow A SubsetWindowOperator object (from [createSubsetStartWindow()]) defining
    #'   the temporal window for the filter cohort start date relative to the base cohort event.
    #' @param endWindow A SubsetWindowOperator object (from [createSubsetEndWindow()]) or NULL.
    #'   Defines the temporal window for the filter cohort end date. Default: NULL.
    #' @param endDateType Character. Whether to use the base cohort end date ('base') or filter
    #'   cohort end date ('filter') in the output. Default: 'base'.
    #' @param subsetLimit Character. One of 'First', 'Last', or 'All'. Default: 'First'.
    #' @param tags Named list. Optional metadata tags.
    #'
    #' @return Invisible integer. The assigned cohort ID.
    buildSubsetCohortTemporal = function(label, baseCohortId, filterCohortId, category,
                                         startWindow,
                                         endWindow = NULL,
                                         endDateType = "base",
                                         subsetLimit = "First",
                                         tags = list()) {
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
      cohorts_dir <- dirname(private$.dbPath)
      derived_dir <- fs::path(cohorts_dir, "derived")
      if (!dir.exists(derived_dir)) dir.create(derived_dir, recursive = TRUE)

      safe_label <- gsub("[^a-zA-Z0-9_-]", "_", label)
      sql_path <- fs::path(derived_dir, paste0(safe_label, ".sql"))

      template_path <- system.file("sql", "createSubsetCohort_Cohort.sql", package = "picard")
      rendered_sql <- readr::read_file(template_path) |>
        SqlRender::render(
          base_cohort_id = baseCohortId,
          filter_cohort_id = filterCohortId,
          start_window = start_window_sql,
          end_window = end_window_sql,
          subset_limit = subsetLimit,
          end_date_type = endDateType
        )
      writeLines(rendered_sql, sql_path)

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
    buildComplementCohort = function(label, populationCohortId, excludeCohortIds,
                                     category, complementType = "exclude_any",
                                     tags = list()) {
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

      cohorts_dir <- dirname(private$.dbPath)
      derived_dir <- fs::path(cohorts_dir, "derived")
      if (!dir.exists(derived_dir)) dir.create(derived_dir, recursive = TRUE)

      safe_label <- gsub("[^a-zA-Z0-9_-]", "_", label)
      sql_path <- fs::path(derived_dir, paste0(safe_label, ".sql"))

      template_path <- system.file("sql", "createComplementCohort.sql", package = "picard")
      rendered_sql <- readr::read_file(template_path) |>
        SqlRender::render(
          population_cohort_id = populationCohortId,
          exclude_cohort_ids = paste(as.integer(excludeCohortIds), collapse = ", "),
          exclude_cohort_ids_count = length(excludeCohortIds),
          complement_type = complementType
        )
      writeLines(rendered_sql, sql_path)

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

    #' @description Build a composite cohort
    #'
    #' Creates a derived cohort that requires membership in multiple cohorts
    #' (intersection logic).
    #'
    #' @param label Character. Display name.
    #' @param cohortIds Integer vector. IDs of cohorts to intersect.
    #' @param category Character. Required classification.
    #' @param minCohorts Integer. Minimum cohorts a subject must appear in. Default: all.
    #' @param tags Named list. Optional metadata tags.
    #'
    #' @return Invisible integer. The assigned cohort ID.
    buildCompositeCohort = function(label, cohortIds, category, minCohorts = NULL, tags = list()) {
      checkmate::assert_string(label, min.chars = 1)
      checkmate::assert_integerish(cohortIds, min.len = 2, unique = TRUE)
      checkmate::assert_string(category, min.chars = 1)
      checkmate::assert_list(tags, names = "named")

      if (is.null(minCohorts)) minCohorts <- length(cohortIds)
      checkmate::assert_int(minCohorts, lower = 1, upper = length(cohortIds))

      private$validate_label_unique(label)
      private$validate_parent_cohorts_exist(cohortIds)

      dependency_rule <- list(
        cohortIds = as.integer(cohortIds),
        minCohorts = as.integer(minCohorts)
      )

      cohorts_dir <- dirname(private$.dbPath)
      derived_dir <- fs::path(cohorts_dir, "derived")
      if (!dir.exists(derived_dir)) dir.create(derived_dir, recursive = TRUE)

      safe_label <- gsub("[^a-zA-Z0-9_-]", "_", label)
      sql_path <- fs::path(derived_dir, paste0(safe_label, ".sql"))

      sql_template <- readLines(system.file("sql", "createCompositeCohort.sql", package = "picard"), warn = FALSE)
      sql_content <- paste(sql_template, collapse = "\n")
      writeLines(sql_content, sql_path)

      cohort_id <- private$insert_cohort(
        label = label,
        category = category,
        tags = tags,
        file_path = fs::path_rel(sql_path),
        source_type = "derived",
        cohort_type = "composite",
        depends_on = as.integer(cohortIds),
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

      return(tibble::as_tibble(manifest_df))
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

    #' @description Update metadata for an existing cohort
    #'
    #' Modifies label, category, or tags for a cohort entry in the manifest.
    #' The file path remains immutable.
    #'
    #' @param cohortId Integer. The cohort ID to update.
    #' @param label Character. New label. If NULL, keeps existing.
    #' @param category Character. New category. If NULL, keeps existing.
    #' @param tags Named list. New tags. If NULL, keeps existing.
    #'
    #' @return Invisible NULL. Updates the manifest.
    updateCohortDef = function(cohortId, label = NULL, category = NULL, tags = NULL) {
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

    #' @description Hard-delete a cohort and its files
    #'
    #' Permanently removes a cohort from the manifest database AND deletes
    #' its associated file(s) on disk. Use with caution.
    #'
    #' @param cohortId Integer. The cohort ID to permanently remove.
    #' @param force Logical. If FALSE (default), requires confirmation. If TRUE, skips confirmation.
    #'
    #' @return Invisible NULL. Removes the cohort from database and disk.
    hardDeleteCohort = function(cohortId, force = FALSE) {
      checkmate::assert_int(cohortId)
      checkmate::assert_flag(force)

      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      cohort_row <- DBI::dbGetQuery(
        conn,
        "SELECT id, label, file_path, status FROM cohort_manifest WHERE id = ?",
        list(cohortId)
      )

      if (nrow(cohort_row) == 0) {
        cli::cli_abort("Cohort {cohortId} not found")
      }

      label <- cohort_row$label[1]
      file_path <- cohort_row$file_path[1]
      status <- cohort_row$status[1]

      if (!force) {
        if (status == "active") {
          cli::cli_alert_warning("Cohort {cohortId} ({label}) is still ACTIVE. Proceed to permanently delete?")
          response <- readline("Type 'yes' to confirm: ")
          if (!grepl("^yes$", trimws(tolower(response)))) {
            cli::cli_alert_info("Cancellation confirmed")
            invisible(NULL)
          }
        }
      }

      # Delete from database
      DBI::dbExecute(conn, "DELETE FROM cohort_manifest WHERE id = ?", list(cohortId))

      # Delete file from disk
      if (!is.na(file_path) && file.exists(file_path)) {
        tryCatch({
          unlink(file_path)
          cli::cli_alert_success("Deleted file: {file_path}")
        }, error = function(e) {
          cli::cli_alert_warning("Could not delete file {file_path}: {e$message}")
        })
      }

      # Refresh in-memory manifest
      private$load_manifest_from_db()

      cli::cli_alert_success("Permanently removed cohort {cohortId}: {label}")
      invisible(NULL)
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
    #'   \item New files found on disk are added (new CohortDef + manifest entry).
    #'   \item Active manifest records whose file no longer exists are soft-deleted.
    #'   \item Existing files whose SQL hash has changed are updated in the manifest.
    #' }
    #' Only the \code{json/} and \code{sql/} source directories are scanned — derived cohorts
    #' managed via \code{build*()} methods are not touched.
    #'
    #' @return Data frame with columns: id, label, action
    #'   (\code{"added"}, \code{"hash_updated"}, \code{"missing_flagged"}, or \code{"unchanged"}).
    syncManifest = function() {
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

      # ── Step 1: check files already in the manifest ──────────────────────────
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
          tmp_def <- CohortDef$new(
            label = rec_label,
            category = if (!is.na(rec$category) && nchar(rec$category) > 0) rec$category else "derived",
            sourceType = if (!is.na(rec$source_type) && nchar(rec$source_type) > 0) rec$source_type else "derived",
            tags = list(),
            filePath = file_path
          )
          new_hash <- tmp_def$getHash()

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
                  tmp_def$tags <- picard::parseTagsString(rec$tags)
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

      # ── Step 2: warn about new files not yet in the manifest ────────────────
      existing_rel <- db_records$file_path
      new_files    <- on_disk[!(on_disk_rel %in% existing_rel)]

      if (length(new_files) > 0) {
        cli::cli_alert_warning("{length(new_files)} file(s) on disk not registered in the manifest:")
        for (f in utils::head(on_disk_rel[!(on_disk_rel %in% existing_rel)], 5)) {
          cli::cli_bullets(c("!" = "{f}"))
        }
        if (length(new_files) > 5) {
          cli::cli_bullets(c("!" = "... and {length(new_files) - 5} more"))
        }
        cli::cli_alert_info("Use $addAtlasCohort(), $addSqlCohort(), or $addCaprCohort() to register them (category is required).")
        for (f_rel in on_disk_rel[!(on_disk_rel %in% existing_rel)]) {
          results <- rbind(results, data.frame(id = NA_integer_, label = tools::file_path_sans_ext(basename(f_rel)),
                                                action = "untracked", stringsAsFactors = FALSE))
        }
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
      cdm_schema <- settings$cdmDatabaseSchema
      if (is.null(cdm_schema) || is.na(cdm_schema)) {
        stop("cdmDatabaseSchema must be set in execution settings")
      }

      cohort_schema <- settings$workDatabaseSchema
      if (is.null(cohort_schema) || is.na(cohort_schema)) {
        stop("workDatabaseSchema must be set in execution settings")
      }

      cohort_table <- settings$cohortTable
      if (is.null(cohort_table) || is.na(cohort_table)) {
        stop("cohortTable must be set in execution settings")
      }

      temp_schema <- settings$tempEmulationSchema
      dbms <- settings$getDbms()

      # Get checksum table name
      table_names <- getCohortTableNames(cohortTable = cohort_table)
      checksum_table <- table_names$cohortChecksumTable

      cli::cli_rule("Generating Cohorts")
      cli::cli_alert_info("Database: {settings$databaseName}")
      cli::cli_alert_info("CDM Schema: {cdm_schema}")
      cli::cli_alert_info("Cohort Schema: {cohort_schema}")
      cli::cli_alert_info("Cohort Table: {cohort_table}")
      cli::cli_alert_info("Generating {length(private$.manifest)} cohorts...\n")

      # === PHASE 1: DEPENDENCY GRAPH BUILDING & VALIDATION ===

      # Build dependency graph
      dependency_graph <- private$build_dependency_graph()

      # Validate no circular dependencies
      private$validate_no_cycles(dependency_graph)

      # Get topological sort (execution order: parents before children)
      sorted_cohort_ids <- private$topological_sort(dependency_graph)

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

      # Check if checksum table is empty
      checksum_query <- paste0("SELECT COUNT(*) as count FROM ", cohort_schema, ".", checksum_table)
      checksum_count_result <- try(DatabaseConnector::querySql(conn, checksum_query), silent = TRUE)
      
      # Determine if checksum table is empty or doesn't exist
      if (inherits(checksum_count_result, "try-error")) {
        # Table doesn't exist or query failed
        is_checksum_empty <- TRUE
      } else if (nrow(checksum_count_result) == 0) {
        # Query succeeded but no rows
        is_checksum_empty <- TRUE
      } else {
        # Query succeeded and we have rows - check the count value
        count_value <- checksum_count_result$COUNT[1]
        is_checksum_empty <- is.na(count_value) || count_value == 0
      }

      # === PHASE 2-4: EXECUTE COHORTS IN DEPENDENCY ORDER ===

      # Generate each cohort in topological order
      for (idx in seq_along(sorted_cohort_ids)) {
        cohort_id <- sorted_cohort_ids[idx]
        cohort <- self$getCohortById(cohort_id)

        if (is.null(cohort)) {
          cli::cli_alert_danger("Cohort {cohort_id} not found in manifest")
          next
        }

        cohort_label <- cohort$label
        cohort_type <- cohort$getCohortType()

        # Query parent IDs from SQLite depends_on column (include stale cohorts)
        dep_row <- DBI::dbGetQuery(
          sqlite_conn,
          "SELECT depends_on, status FROM cohort_manifest WHERE id = ? AND status IN ('active', 'stale')",
          list(cohort_id)
        )

        # Stale cohorts must always be re-executed regardless of checksum
        is_stale <- nrow(dep_row) > 0 && dep_row$status[1] == "stale"
        parent_ids <- if (nrow(dep_row) > 0 && !is.na(dep_row$depends_on[1]) && nchar(dep_row$depends_on[1]) > 0) {
          as.integer(jsonlite::fromJSON(dep_row$depends_on[1]))
        } else {
          integer(0)
        }
        depends_on_str <- ifelse(length(parent_ids) > 0, paste(parent_ids, collapse = ", "), "")

        # Check if we should skip this cohort based on hash
        should_skip <- FALSE
        stored_hash <- NULL
        dependency_hash_changed <- FALSE
        stored_dependency_hash <- NULL

        if (!is_checksum_empty) {
          # Query the stored hash for this cohort
          hash_query <- paste0(
            "SELECT checksum FROM ", cohort_schema, ".", checksum_table,
            " WHERE cohort_definition_id = ", cohort_id
          )
          hash_result <- try(DatabaseConnector::querySql(conn, hash_query), silent = TRUE)

          if (!inherits(hash_result, "try-error") && nrow(hash_result) > 0) {
            stored_hash <- hash_result$CHECKSUM[1]
          }
        }
        

        # For dependent cohorts, also check dependency hash
        dependency_status <- "Not applicable"
        if (cohort_type %in% c("subset", "union", "complement", "composite")) {
          # Compute dependency hash using cached parent hashes
          current_dependency_hash <- private$compute_dependency_hash(cohort, cohort_hashes)

          if (is_stale) {
            # Stale: parent data changed — must re-run, skip hash check
            dependency_status <- "Stale - parent changed"
            should_skip <- FALSE
          } else if (!is_checksum_empty && !is.null(stored_hash)) {
            # Check if dependency hash is available
            stored_dependency_hash <- stored_hash  # For now, store both as one; could extend DB schema
            if (!is.na(stored_dependency_hash) && stored_dependency_hash == current_dependency_hash) {
              dependency_status <- "Unchanged"
              should_skip <- TRUE
            } else {
              dependency_status <- "Parent changed"
            }
          } else {
            dependency_status <- "New"
          }
        } else {
          # For circe cohorts, use standard SQL hash (stale not applicable for base cohorts)
          current_hash <- cohort$getHash()
          if (!is.null(stored_hash) && !is.na(stored_hash) && stored_hash == current_hash) {
            should_skip <- TRUE
          }
        }

        # Log decision
        if (should_skip) {
          cli::cli_alert_info("Skipping cohort {cohort_id}: {cohort_label} ({cohort_type})")
          results_df <- rbind(results_df, data.frame(
            cohort_id = cohort_id,
            label = cohort_label,
            cohort_type = cohort_type,
            depends_on = depends_on_str,
            execution_time_min = 0,
            status = "Skipped - already generated",
            dependency_status = dependency_status,
            stringsAsFactors = FALSE
          ))
          
          # Cache this cohort's hash for dependency calculations
          if (cohort_type %in% c("circe", "custom")) {
            cohort_hashes[[as.character(cohort_id)]] <- cohort$getHash()
          } else {
            cohort_hashes[[as.character(cohort_id)]] <- private$compute_dependency_hash(cohort, cohort_hashes)
          }

          next
        }

        # Generate the cohort
        cli::cli_alert_info("Generating cohort {cohort_id}: {cohort_label} ({cohort_type})...")

        # Get the SQL from the cohortDef class
        cohort_sql <- cohort$getSql()
        cohort_file_path <- cohort$getFilePath()

        # Validate cohort SQL is not NULL or empty
        if (is.null(cohort_sql) || !is.character(cohort_sql) || nchar(cohort_sql) == 0) {
          error_msg <- paste0("Invalid cohort SQL for ", cohort_id, ": SQL is null or empty")
          cli::cli_alert_danger("Failed to execute cohort {cohort_id}: {cohort_label} - {error_msg}")

          results_df <- rbind(results_df, data.frame(
            cohort_id = cohort_id,
            label = cohort_label,
            cohort_type = cohort_type,
            depends_on = depends_on_str,
            execution_time_min = NA_real_,
            status = paste("Error:", error_msg),
            dependency_status = dependency_status,
            stringsAsFactors = FALSE
          ))
          next
        }

        # Run portability validation for custom cohorts
        if (cohort_type == "custom") {
          .validateCustomSql(cohort_sql, cohort_label)
        }

        # Prepare SQL rendering parameters
        sql_params <- list(
          cdm_database_schema = cdm_schema,
          vocabulary_database_schema = cdm_schema,
          target_database_schema = cohort_schema,
          target_cohort_table = cohort_table,
          target_cohort_id = cohort_id,
          results_database_schema.cohort_inclusion = paste(cohort_schema, table_names$cohortInclusionTable, sep = "."),
          results_database_schema.cohort_inclusion_result = paste(cohort_schema, table_names$cohortInclusionResultTable, sep = "."),
          results_database_schema.cohort_inclusion_stats = paste(cohort_schema, table_names$cohortInclusionStatsTable, sep = "."),
          results_database_schema.cohort_summary_stats = paste(cohort_schema, table_names$cohortSummaryStatsTable, sep = "."),
          results_database_schema.cohort_censor_stats = paste(cohort_schema, table_names$cohortCensorStatsTable, sep = "."),
          warnOnMissingParameters = FALSE
        )

        # For dependent cohorts, load dependency_rule from SQLite and add to parameters
        if (cohort_type %in% c("subset", "union", "complement", "composite")) {
          # Add execution context parameters for dependent cohorts
          output_table_name <- paste(cohort_schema, cohort_table, sep = ".")
          sql_params$output_cohort_id <- cohort_id
          sql_params$output_table <- output_table_name
          sql_params$base_cohort_table <- output_table_name

          rule_row <- DBI::dbGetQuery(
            sqlite_conn,
            "SELECT dependency_rule FROM cohort_manifest WHERE id = ? AND status = 'active'",
            list(cohort_id)
          )
          metadata <- if (nrow(rule_row) > 0 && !is.na(rule_row$dependency_rule[1]) && nchar(rule_row$dependency_rule[1]) > 0) {
            tryCatch(jsonlite::fromJSON(rule_row$dependency_rule[1]), error = function(e) list())
          } else {
            list()
          }

          if (length(metadata) > 0) {
            field_mapping <- list(
              baseCohortId = "base_cohort_id",
              filterCohortId = "filter_cohort_id",
              temporalOperator = "temporal_operator",
              temporalStartOffset = "temporal_start_offset",
              temporalEndOffset = "temporal_end_offset",
              minAge = "min_age",
              maxAge = "max_age",
              genderConceptIds = "gender_concept_ids",
              raceConceptIds = "race_concept_ids",
              ethnicityConceptIds = "ethnicity_concept_ids",
              cohortIds = "cohort_ids",
              gapDays = "gap_days",
              eraPadDays = "era_pad_days",
              minEraDays = "min_era_days",
              minCohorts = "min_cohorts",
              washoutDays = "washout_days",
              firstEraOnly = "first_era_only",
              populationCohortId = "population_cohort_id",
              excludeCohortIds = "exclude_cohort_ids",
              complementType = "complement_type"
            )
            sql_params <- private$expand_metadata_parameters(metadata, sql_params, field_mapping)
          }
        }

        # Render the SQL with all parameters
        render_result <- try({
          do.call(SqlRender::render, c(list(sql = cohort_sql), sql_params))
        }, silent = TRUE)

        if (inherits(render_result, "try-error")) {
          error_msg <- as.character(render_result)
          cli::cli_alert_danger("Failed to render SQL for cohort {cohort_id}: {cohort_label} - {error_msg}")

          results_df <- rbind(results_df, data.frame(
            cohort_id = cohort_id,
            label = cohort_label,
            cohort_type = cohort_type,
            depends_on = depends_on_str,
            execution_time_min = NA_real_,
            status = paste("Error:", error_msg),
            dependency_status = dependency_status,
            stringsAsFactors = FALSE
          ))
          next
        }

        # Translate to target dialect
        translate_result <- try({
          SqlRender::translate(
            sql = render_result,
            targetDialect = dbms,
            tempEmulationSchema = temp_schema
          )
        }, silent = TRUE)
        translate_result <- translate_result |>  # Convert CRLF to LF
          stringr::str_replace_all("\r", "\n")
          
        if (inherits(translate_result, "try-error")) {
          error_msg <- as.character(translate_result)
          cli::cli_alert_danger("Failed to translate SQL for cohort {cohort_id}: {cohort_label} - {error_msg}")

          results_df <- rbind(results_df, data.frame(
            cohort_id = cohort_id,
            label = cohort_label,
            cohort_type = cohort_type,
            depends_on = depends_on_str,
            execution_time_min = NA_real_,
            status = paste("Error:", error_msg),
            dependency_status = dependency_status,
            stringsAsFactors = FALSE
          ))
          next
        }

        # Execute and time it
        start_time <- Sys.time()
        result <- try({
          DatabaseConnector::executeSql(
            conn,
            translate_result,
            progressBar = FALSE,
            reportOverallTime = FALSE
          )
        }, silent = TRUE)

        # Check if execution failed
        if (inherits(result, "try-error")) {
          end_time <- Sys.time()
          execution_time_min <- as.numeric(difftime(end_time, start_time, units = "mins"))
          error_msg <- as.character(result)

          cli::cli_alert_danger("Failed to execute cohort {cohort_id}: {cohort_label} ({execution_time_min |> round(2)} min) - {error_msg}")

          # Add the failed cohort to results
          results_df <- rbind(results_df, data.frame(
            cohort_id = cohort_id,
            label = cohort_label,
            cohort_type = cohort_type,
            depends_on = depends_on_str,
            execution_time_min = execution_time_min,
            status = paste("Error:", error_msg),
            dependency_status = dependency_status,
            stringsAsFactors = FALSE
          ))

          # Add "Not generated" for remaining cohorts (due to cascade failure)
          if (idx < length(sorted_cohort_ids)) {
            for (j in (idx + 1):length(sorted_cohort_ids)) {
              remaining_cohort_id <- sorted_cohort_ids[j]
              remaining_cohort <- self$getCohortById(remaining_cohort_id)
              if (!is.null(remaining_cohort)) {
                rem_dep_row <- DBI::dbGetQuery(
                  sqlite_conn,
                  "SELECT depends_on FROM cohort_manifest WHERE id = ? AND status = 'active'",
                  list(remaining_cohort_id)
                )
                rem_parent_ids <- if (nrow(rem_dep_row) > 0 && !is.na(rem_dep_row$depends_on[1]) && nchar(rem_dep_row$depends_on[1]) > 0) {
                  as.integer(jsonlite::fromJSON(rem_dep_row$depends_on[1]))
                } else {
                  integer(0)
                }
                remaining_deps_str <- ifelse(length(rem_parent_ids) > 0, paste(rem_parent_ids, collapse = ", "), "")
                results_df <- rbind(results_df, data.frame(
                  cohort_id = remaining_cohort_id,
                  label = remaining_cohort$label,
                  cohort_type = remaining_cohort$getCohortType(),
                  depends_on = remaining_deps_str,
                  execution_time_min = NA_real_,
                  status = "Not generated",
                  dependency_status = "Not applicable",
                  stringsAsFactors = FALSE
                ))
              }
            }
          }

          cli::cli_alert_info("Stopping cohort generation due to error at cohort {cohort_id}")
          break
        }

        # Success path
        end_time <- Sys.time()
        execution_time_min <- as.numeric(difftime(end_time, start_time, units = "mins"))

        # Determine hash to store (depends on cohort type)
        if (cohort_type %in% c("circe", "custom")) {
          hash_to_store <- cohort$getHash()
        } else {
          hash_to_store <- private$compute_dependency_hash(cohort, cohort_hashes)
        }

        # Update or insert checksum
        if (is.null(stored_hash)) {
          # Insert new checksum record
          checksum_data <- data.frame(
            cohort_definition_id = cohort_id,
            checksum = hash_to_store,
            start_time = NA_real_,
            end_time = as.numeric(difftime(Sys.time(), start_time, units = "secs")),
            stringsAsFactors = FALSE
          )
          
          try({
            DatabaseConnector::insertTable(
              connection = conn,
              tableName = paste(cohort_schema, checksum_table, sep = "."),
              data = checksum_data,
              dropTableIfExists = FALSE,
              createTable = FALSE,
              tempTable = FALSE
            )
            cli::cli_alert_info("Recorded checksum for cohort {cohort_id}")
          }, silent = FALSE)
        } else {
          # Update existing checksum record
          update_sql <- paste0(
            "UPDATE ", cohort_schema, ".", checksum_table,
            " SET checksum = '", hash_to_store, "', ",
            "end_time = ", as.numeric(difftime(Sys.time(), start_time, units = "secs")), " ",
            "WHERE cohort_definition_id = ", cohort_id
          )
          
          try({
            DatabaseConnector::executeSql(
              conn,
              update_sql,
              progressBar = FALSE,
              reportOverallTime = FALSE
            )
            cli::cli_alert_info("Updated checksum for cohort {cohort_id}")
          }, silent = FALSE)
        }

        cli::cli_alert_success("Generated cohort {cohort_id}: {cohort_label} ({cohort_type}) ({execution_time_min |> round(2)} min)")

        # If cohort was stale, reset to active now that it has been re-executed
        if (isTRUE(is_stale)) {
          DBI::dbExecute(
            sqlite_conn,
            "UPDATE cohort_manifest SET status = 'active', updated_at = CURRENT_TIMESTAMP WHERE id = ?",
            list(cohort_id)
          )
        }

        # Cache this cohort's hash for dependency calculations
        cohort_hashes[[as.character(cohort_id)]] <- hash_to_store

        results_df <- rbind(results_df, data.frame(
          cohort_id = cohort_id,
          label = cohort_label,
          cohort_type = cohort_type,
          depends_on = depends_on_str,
          execution_time_min = execution_time_min,
          status = "Success",
          dependency_status = dependency_status,
          stringsAsFactors = FALSE
        ))
      }

      # === PHASE 5: RESULTS REPORTING ===

      cli::cli_rule()
      total_time_min <- sum(results_df$execution_time_min[results_df$status == "Success"], na.rm = TRUE)
      successful <- sum(results_df$status == "Success")
      skipped <- sum(results_df$status == "Skipped - already generated")
      failed <- sum(grepl("Error:", results_df$status))
      
      # Report by cohort type
      if ("cohort_type" %in% names(results_df)) {
        circe_count <- sum(results_df$cohort_type == "circe", na.rm = TRUE)
        custom_count <- sum(results_df$cohort_type == "custom", na.rm = TRUE)
        dependent_count <- sum(results_df$cohort_type %in% c("subset", "union", "complement", "composite"), na.rm = TRUE)
        cli::cli_alert_info("Cohort types: {circe_count} circe + {custom_count} custom + {dependent_count} dependent")
      }

      cli::cli_alert_success("Cohort generation complete")
      cli::cli_alert_info("Total cohorts: {nrow(results_df)} | Successful: {successful} | Skipped: {skipped} | Failed: {failed}")
      cli::cli_alert_info("Total execution time: {total_time_min |> round(2)} min")

      return(results_df)
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

    #' @description Soft delete a cohort (mark as deleted, preserve record)
    #'
    #' @param id Integer. The cohort ID to delete.
    #' @param reason Character. Optional reason for deletion.
    #'
    #' @return Invisibly returns TRUE if successful, FALSE otherwise.
    deleteCohort = function(id, reason = NULL) {
      checkmate::assert_int(id)
      
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))
      
      # Check if cohort exists
      exists <- DBI::dbGetQuery(
        conn,
        "SELECT COUNT(*) as count FROM cohort_manifest WHERE id = ?",
        list(id)
      )$count > 0
      
      if (!exists) {
        cli::cli_alert_danger("Cohort with ID {id} not found in manifest")
        invisible(FALSE)
      }
      
      # Update status and set deleted_at timestamp
      tryCatch({
        DBI::dbExecute(
          conn,
          "UPDATE cohort_manifest SET status = 'deleted', deleted_at = CURRENT_TIMESTAMP WHERE id = ?",
          list(id)
        )
        
        # Get label for display
        label_result <- DBI::dbGetQuery(
          conn,
          "SELECT label FROM cohort_manifest WHERE id = ?",
          list(id)
        )
        label <- ifelse(nrow(label_result) > 0, label_result$label[1], "Unknown")
        
        reason_msg <- ifelse(!is.null(reason), glue::glue(" ({reason})"), "")
        cli::cli_alert_success("Deleted cohort {id}: {label}{reason_msg}")
        invisible(TRUE)
      }, error = function(e) {
        cli::cli_alert_danger("Failed to delete cohort {id}: {e$message}")
        invisible(FALSE)
      })
    },

    #' @description Permanently delete a cohort (removes the record from database, irreversible)
    #'
    #' @param id Integer. The cohort ID to permanently remove.
    #' @param confirm Logical. Must be TRUE to proceed. Defaults to FALSE as a safety guard.
    #'
    #' @return Invisibly returns TRUE if successful, FALSE otherwise.
    permanentlyDeleteCohort = function(id, confirm = FALSE) {
      checkmate::assert_int(id)

      if (!confirm) {
        cli::cli_abort(
          "This operation permanently removes the cohort record from the database and cannot be undone. \
          Pass confirm = TRUE to proceed."
        )
      }
      
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))
      
      # Check if cohort exists
      cohort_info <- DBI::dbGetQuery(
        conn,
        "SELECT label, status FROM cohort_manifest WHERE id = ?",
        list(id)
      )
      
      if (nrow(cohort_info) == 0) {
        cli::cli_alert_danger("Cohort with ID {id} not found")
        invisible(FALSE)
      }
      
      label <- cohort_info$label[1]
      status <- cohort_info$status[1]
      
      # Hard delete
      tryCatch({
        DBI::dbExecute(
          conn,
          "DELETE FROM cohort_manifest WHERE id = ?",
          list(id)
        )
        
        cli::cli_alert_warning("Permanently removed cohort {id}: {label} (status was: {status})")
        invisible(TRUE)
      }, error = function(e) {
        cli::cli_alert_danger("Failed to remove cohort {id}: {e$message}")
        invisible(FALSE)
      })
    },

    #' @description Clean up missing cohorts from manifest
    #'
    #' @param keep_trace Logical. If TRUE, marks missing as deleted with timestamp (soft delete).
    #'   If FALSE, permanently removes from database (hard delete). Defaults to TRUE.
    #'
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
          self$permanentlyDeleteCohort(cohort_id, confirm = TRUE)
        }
      }
      
      cleanup_method <- ifelse(keep_trace, "soft deleted (with trace)", "hard deleted (permanently)")
      cli::cli_alert_success("Cleanup complete: {nrow(missing_cohorts)} cohort(s) {cleanup_method}")
      
      invisible(NULL)
    }
  )
)


# helpers -------------


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
