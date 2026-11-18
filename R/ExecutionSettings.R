# ExecutionSettings ----

#' @title ExecutionSettings
#' @description
#' An R6 class to define an ExecutionSettings object
#'
#' @export
ExecutionSettings <- R6::R6Class(
  classname = "ExecutionSettings",
  public = list(
    #' @param connectionDetails a connectionDetails object
    #' @param connection a connection to a dbms
    #' @param cdmDatabaseSchema The schema of the OMOP CDM database
    #' @param workDatabaseSchema The schema to which results will be written
    #' @param tempEmulationSchema Some database platforms like Oracle and Snowflake do not truly support temp tables. To emulate temp tables, provide a schema with write privileges where temp tables can be created.
    #' @param cohortTable The name of the table where the cohort(s) are stored
    #' @param databaseName A human-readable name for the OMOP CDM database
    initialize = function(connectionDetails = NULL,
                          connection = NULL,
                          cdmDatabaseSchema = NULL,
                          workDatabaseSchema = NULL,
                          tempEmulationSchema = NULL,
                          cohortTable = NULL,
                          databaseName = NULL) {
      # Validate: must provide exactly one of connectionDetails or connection
      has_details <- !is.null(connectionDetails)
      has_connection <- !is.null(connection)
      
      if (!has_details && !has_connection) {
        stop("Must provide either 'connectionDetails' or 'connection'", call. = FALSE)
      }
      
      if (has_details && has_connection) {
        stop("Cannot provide both 'connectionDetails' and 'connection'. Choose one.", call. = FALSE)
      }
      
      checkmate::assert_class(x = connectionDetails, classes = "ConnectionDetails", null.ok = TRUE)
      private[["connectionDetails"]] <- connectionDetails
      checkmate::assert_class(x = connection, classes = "DatabaseConnectorConnection", null.ok = TRUE)
      private[[".connection"]] <- connection

      checkmate::assert_string(x = cdmDatabaseSchema, min.chars = 1)
      checkmate::assert_string(x = workDatabaseSchema, min.chars = 1)
      checkmate::assert_string(x = cohortTable, min.chars = 1)
      checkmate::assert_string(x = databaseName, min.chars = 1)
      private[[".cdmDatabaseSchema"]] <- cdmDatabaseSchema
      private[[".workDatabaseSchema"]] <- workDatabaseSchema
      private[[".cohortTable"]] <- cohortTable
      private[[".databaseName"]] <- databaseName
      # tempEmulationSchema is optional
      if (!is.null(tempEmulationSchema)) {
        private[[".tempEmulationSchema"]] <- tempEmulationSchema
      }
    },
    
    #' @description Extract the DBMS dialect
    #' @return Character. The DBMS type (e.g., "postgresql", "snowflake")
    #' @details Prioritizes active connection DBMS over connectionDetails DBMS
    getDbms = function() {
      conObj <- private$.connection
      if (!is.null(conObj)) {
        tryCatch({
          dbms <- conObj@dbms
          if (is.null(dbms) || is.na(dbms)) {
            stop("Unable to extract DBMS from connection object", call. = FALSE)
          }
          return(dbms)
        }, error = function(e) {
          stop("Failed to get DBMS from active connection: ", e$message, call. = FALSE)
        })
      } else if (!is.null(private$connectionDetails)) {
        tryCatch({
          dbms <- private$connectionDetails$dbms
          if (is.null(dbms) || is.na(dbms)) {
            stop("DBMS not set in connectionDetails", call. = FALSE)
          }
          return(dbms)
        }, error = function(e) {
          stop("Failed to get DBMS from connectionDetails: ", e$message, call. = FALSE)
        })
      } else {
        stop("No connection or connectionDetails available to determine DBMS", call. = FALSE)
      }
    },
    
    #' @description Connect to DBMS using connectionDetails
    #' @details Creates a new connection if one doesn't exist. If a connection already exists, 
    #'   validates it and returns a message. If validation fails, attempts to reconnect.
    #' @return Invisible NULL
    connect = function() {
      conObj <- private$.connection
      
      if (is.null(private$connectionDetails)) {
        stop("connectionDetails not set. Cannot establish connection.", call. = FALSE)
      }
      
      if (!is.null(conObj)) {
        # Connection exists, try to validate it
        if (private$validateConnection(conObj)) {
          cli::cli_alert_info("Connection already established and active")
          return(invisible(NULL))
        } else {
          cli::cli_alert_warning("Existing connection is no longer valid. Attempting to reconnect...")
          tryCatch({
            DatabaseConnector::disconnect(conObj)
          }, error = function(e) {
            # Silently ignore disconnect errors for invalid connections
          })
          private$.connection <- NULL
        }
      }
      
      # Establish new connection
      tryCatch({
        cli::cli_alert_info("Connecting to {private$connectionDetails$dbms}...")
        new_connection <- DatabaseConnector::connect(private$connectionDetails)
        
        if (is.null(new_connection)) {
          stop("DatabaseConnector::connect() returned NULL", call. = FALSE)
        }
        
        private$.connection <- new_connection
        cli::cli_alert_success("Successfully connected to {private$connectionDetails$dbms}")
        invisible(NULL)
      }, error = function(e) {
        stop("Failed to connect to database: ", e$message, call. = FALSE)
      })
    },

    #' @description Disconnect from DBMS
    #' @details Closes the active connection and clears the connection object.
    #'   Safe to call even if no connection exists.
    #' @return Invisible NULL
    disconnect = function() {
      conObj <- private$.connection
      
      if (is.null(conObj)) {
        cli::cli_alert_info("No active connection to disconnect")
        return(invisible(NULL))
      }
      
      if (!inherits(conObj, "DatabaseConnectorConnection")) {
        cli::cli_alert_warning("Connection object is not valid type. Clearing reference.")
        private$.connection <- NULL
        return(invisible(NULL))
      }
      
      tryCatch({
        DatabaseConnector::disconnect(conObj)
        private$.connection <- NULL
        cli::cli_alert_success("Connection successfully closed")
      }, error = function(e) {
        cli::cli_alert_warning("Error during disconnect: {e$message}. Clearing connection reference.")
        private$.connection <- NULL
      })
      
      invisible(NULL)
    },

    #' @description Retrieve the active connection object
    #' @details Returns the connection if it exists and is valid. Otherwise returns NULL
    #'   with an informative message. Use this to check connection status before database operations.
    #' @return DatabaseConnectorConnection or NULL
    getConnection = function() {
      conObj <- private$.connection
      
      if (is.null(conObj)) {
        cli::cli_alert_warning("No active database connection. Call $connect() to establish one.")
        return(NULL)
      }
      
      if (!inherits(conObj, "DatabaseConnectorConnection")) {
        cli::cli_alert_warning("Connection object is invalid. Call $connect() to re-establish connection.")
        return(NULL)
      }
      
      # Validate connection is still active
      if (!private$validateConnection(conObj)) {
        cli::cli_alert_warning("Connection appears to be closed. Call $connect() to re-establish connection.")
        return(NULL)
      }
      
      return(conObj)
    },

    #' @description Return the configured connectionDetails object
    #' @return A DatabaseConnector connectionDetails object or NULL.
    reviewConnectionDetails = function() {
      return(private$connectionDetails)
    }

  ),

  private = list(
    connectionDetails = NULL,
    .connection = NULL,
    .cdmDatabaseSchema = NULL,
    .workDatabaseSchema = NULL,
    .tempEmulationSchema = NULL,
    .cohortTable = NULL,
    .databaseName = NULL,
    
    validateConnection = function(conObj) {
      if (is.null(conObj)) return(FALSE)
      if (!inherits(conObj, "DatabaseConnectorConnection")) return(FALSE)
      
      tryCatch({
        # Attempt a simple query to validate connection
        result <- DatabaseConnector::querySql(conObj, "SELECT 1 as test")
        return(!is.null(result) && nrow(result) > 0)
      }, error = function(e) {
        return(FALSE)
      })
    }
  ),

  active = list(
    #' @field cdmDatabaseSchema the schema containing the OMOP CDM
    cdmDatabaseSchema = function(value) {
      if(missing(value)) {
        return(private$.cdmDatabaseSchema)
      }
      checkmate::assert_string(x = value, min.chars = 1)
      private[[".cdmDatabaseSchema"]] <- value
      cli::cli_alert_info("Updated {crayon::cyan('cdmDatabaseSchema')} to {crayon::green(value)}")
    },

    #' @field workDatabaseSchema the schema containing the cohort table
    workDatabaseSchema = function(value) {
      if(missing(value)) {
        return(private$.workDatabaseSchema)
      }
      checkmate::assert_string(x = value, min.chars = 1)
      private[[".workDatabaseSchema"]] <- value
      cli::cli_alert_info("Updated {crayon::cyan('workDatabaseSchema')} to {crayon::green(value)}")
    },

    #' @field tempEmulationSchema the schema needed for temp tables
    tempEmulationSchema = function(value) {
      if(missing(value)) {
        return(private$.tempEmulationSchema)
      }
      checkmate::assert_string(x = value, min.chars = 1)
      private[[".tempEmulationSchema"]] <- value
      cli::cli_alert_info("Updated {crayon::cyan('tempEmulationSchema')} to {crayon::green(value)}")
    },
    
    #' @field cohortTable the table containing the cohorts
    cohortTable = function(value) {
      if(missing(value)) {
        return(private$.cohortTable)
      }
      checkmate::assert_string(x = value, min.chars = 1)
      private[[".cohortTable"]] <- value
      cli::cli_alert_info("Updated {crayon::cyan('cohortTable')} to {crayon::green(value)}")
    },
    
    #' @field databaseName the name of the source data of the cdm
    databaseName = function(value) {
      if(missing(value)) {
        return(private$.databaseName)
      }
      checkmate::assert_string(x = value, min.chars = 1)
      private[[".databaseName"]] <- value
      cli::cli_alert_info("Updated {crayon::cyan('databaseName')} to {crayon::green(value)}")
    }

  )
)

# Practical cross-database ceiling for a derived (test) cohort table name.
# Some platforms cap identifiers well below this; 60 is the package-level guard
# and is overridable per `ExecutionContext`.
MAX_TEST_COHORT_TABLE_NAME_LENGTH <- 60L

#' @title Normalize a test pipeline version (namespace)
#' @description Canonical normalization for a test-mode `pipelineVersion`: the
#'   value is lowercased and every run of non-alphanumeric characters collapses
#'   to a single underscore, with leading and trailing underscores removed. The
#'   result is used verbatim as the cohort-table suffix, the results-folder
#'   segment, and the task-history namespace, so all three always agree.
#'
#'   This does **not** truncate. An over-long namespace fails loudly (via the
#'   [ExecutionContext] cohort-table length check) rather than being silently
#'   shortened into a name that no longer matches the folder it was derived
#'   alongside.
#' @param pipelineVersion Character. The user-supplied test namespace.
#' @return Character. The normalized namespace.
#' @keywords internal
normalizePipelineVersion <- function(pipelineVersion) {
  checkmate::assert_string(pipelineVersion, min.chars = 1)

  normalized <- tolower(trimws(pipelineVersion))
  normalized <- gsub("[^a-z0-9]+", "_", normalized)
  normalized <- gsub("^_+|_+$", "", normalized)
  normalized <- gsub("_+", "_", normalized)

  if (!nzchar(normalized)) {
    cli::cli_abort("Test pipeline version must contain at least one letter or number.")
  }

  normalized
}

#' @title Classify a pipeline version string as production or test
#' @description A `pipelineVersion` string carries its own mode: the sentinel
#'   `"prod"` and any `MAJOR.MINOR.PATCH` string mean a production run against
#'   the configured cohort table; every other value (`"dev"`, `"develop_ml"`, …)
#'   is a test namespace. This is the single classifier used by
#'   [newExecutionContext()], [createExecutionSettingsFromConfig()], and the
#'   results-path helpers.
#' @param pipelineVersion Character.
#' @return Logical. `TRUE` for a production version.
#' @keywords internal
isProductionPipelineVersion <- function(pipelineVersion) {
  identical(pipelineVersion, "prod") ||
    grepl("^\\d+\\.\\d+\\.\\d+$", pipelineVersion)
}

#' @title Build an ExecutionContext from a pipeline version string
#' @description The single place that turns a raw `pipelineVersion` into an
#'   [ExecutionContext]: it classifies the mode (unless `testMode` forces it) and
#'   derives `studyVersion`, so callers never hand-roll `mode = ` /
#'   `studyVersion = `.
#' @param pipelineVersion Character. A semantic version, `"prod"`, or a test
#'   namespace.
#' @param testMode Logical or `NULL`. `NULL` (default) infers the mode from
#'   `pipelineVersion` via [isProductionPipelineVersion()]; `TRUE`/`FALSE` forces
#'   it (used by the pipeline, which already knows).
#' @param databaseName Character or `NULL`. Passed through to `ExecutionContext`.
#' @param execPath Character. Base results path. Passed through.
#' @return An `ExecutionContext`.
#' @keywords internal
newExecutionContext <- function(pipelineVersion,
                                testMode = NULL,
                                databaseName = NULL,
                                execPath = here::here("exec/results")) {
  checkmate::assert_string(pipelineVersion, min.chars = 1)
  checkmate::assert_logical(testMode, len = 1, null.ok = TRUE)

  is_test <- if (is.null(testMode)) {
    !isProductionPipelineVersion(pipelineVersion)
  } else {
    isTRUE(testMode)
  }

  study_version <- if (is_test || identical(pipelineVersion, "prod")) {
    NULL
  } else {
    pipelineVersion
  }

  ExecutionContext$new(
    mode = if (is_test) "test" else "production",
    pipelineVersion = pipelineVersion,
    studyVersion = study_version,
    databaseName = databaseName,
    execPath = execPath
  )
}

#' @title ExecutionContext
#' @description
#'
#' Describes one Picard pipeline execution and derives the names used to
#' isolate its database and filesystem outputs. This R6 class owns execution
#' mode and pipeline version (the namespace).
#'
#' Internal: constructed by the pipeline (`execute_pipeline()`) and by the
#' settings/path helpers ([createExecutionSettingsFromConfig()],
#' [setOutputFolder()], [resolveResultsPath()]). Study code and task files
#' never construct it directly.
#'
#' @keywords internal
ExecutionContext <- R6::R6Class(
  classname = "ExecutionContext",
  public = list(
    #' @param mode Character. Either `"test"` or `"production"`.
    #' @param pipelineVersion Character. The complete execution pipeline version.
    #'   Defaults to `"dev"` for test executions. Test pipeline versions are
    #'   normalized to lowercase snake case. Production pipeline versions are
    #'   semantic versions, or the literal `"prod"` for a production run against
    #'   the configured table whose version is not tracked.
    #' @param studyVersion Character or `NULL`. The study version associated with
    #'   the execution. Required for a semantic-version production run; `NULL` for
    #'   test runs and for `pipelineVersion = "prod"`.
    #' @param baseCohortTable Character or `NULL`. The configured, unsuffixed
    #'   cohort table. Optional for a run-scoped context shared by multiple
    #'   database config blocks.
    #' @param databaseName Character or `NULL`. Human-readable database name
    #'   used in result paths. Optional for a run-scoped context shared by
    #'   multiple database config blocks.
    #' @param execPath Character. Base path for execution results. Defaults to
    #'   `exec/results` in the current study project.
    #' @param maxTableNameLength Integer. Maximum permitted length of the derived
    #'   cohort table name. Defaults to 60, a practical cross-database limit for
    #'   test-derived names. Set to `NULL` to disable this package-level check.
    initialize = function(mode = c("test", "production"),
                          pipelineVersion = "dev",
                          studyVersion = NULL,
                          baseCohortTable = NULL,
                          databaseName = NULL,
                          execPath = here::here("exec/results"),
                          maxTableNameLength = MAX_TEST_COHORT_TABLE_NAME_LENGTH) {
      mode <- match.arg(mode)
      checkmate::assert_string(pipelineVersion, min.chars = 1)
      checkmate::assert_string(baseCohortTable, min.chars = 1, null.ok = TRUE)
      checkmate::assert_string(databaseName, min.chars = 1, null.ok = TRUE)
      checkmate::assert_string(execPath, min.chars = 1)
      checkmate::assert_int(maxTableNameLength, lower = 1, null.ok = TRUE)

      if (mode == "production" && identical(pipelineVersion, "prod")) {
        # Production run against the configured table, version untracked.
        checkmate::assert_string(studyVersion, min.chars = 1, null.ok = TRUE)
        normalized_pipeline_version <- "prod"
      } else if (mode == "production") {
        checkmate::assert_string(studyVersion, min.chars = 1)
        if (!grepl("^\\d+\\.\\d+\\.\\d+$", studyVersion)) {
          cli::cli_abort("Production studyVersion must use MAJOR.MINOR.PATCH format.")
        }
        if (!identical(pipelineVersion, studyVersion)) {
          cli::cli_abort("Production pipelineVersion must match studyVersion.")
        }
        normalized_pipeline_version <- pipelineVersion
      } else {
        normalized_pipeline_version <- normalizePipelineVersion(pipelineVersion)
      }

      private$.mode <- mode
      private$.pipelineVersion <- normalized_pipeline_version
      private$.studyVersion <- studyVersion
      private$.baseCohortTable <- baseCohortTable
      private$.databaseName <- databaseName
      private$.execPath <- fs::path_abs(execPath)
      private$.maxTableNameLength <- maxTableNameLength

      # Derived here so a single-database context still exposes getCohortTable();
      # deriveCohortTable() is the one place the mode + namespace rule lives.
      if (is.null(baseCohortTable)) {
        private$.cohortTable <- NULL
      } else {
        private$.cohortTable <- self$deriveCohortTable(baseCohortTable)
      }
    },

    #' @return Character. Execution mode, either `"test"` or `"production"`.
    getMode = function() {
      private$.mode
    },

    #' @return Character. Normalized execution pipelineVersion.
    getPipelineVersion = function() {
      private$.pipelineVersion
    },

    #' @return Character or `NULL`. Associated production study version.
    getStudyVersion = function() {
      private$.studyVersion
    },

    #' @return Character or `NULL`. Effective cohort table name for this
    #'   execution, or `NULL` for a run-scoped context without a base table.
    getCohortTable = function() {
      private$.cohortTable
    },

    #' @description Apply this run's mode and namespace to a configured base
    #'   cohort table. Production returns the base table unchanged; test appends
    #'   the normalized pipeline version and enforces the table-name length
    #'   ceiling before any database work.
    #' @param baseCohortTable Character. The configured, unsuffixed cohort table.
    #' @return Character. The effective cohort table name for this execution.
    deriveCohortTable = function(baseCohortTable) {
      checkmate::assert_string(baseCohortTable, min.chars = 1)

      if (identical(private$.mode, "production")) {
        return(baseCohortTable)
      }

      cohort_table <- paste0(baseCohortTable, "_", private$.pipelineVersion)
      private$assert_table_name_length(baseCohortTable, cohort_table)
      cohort_table
    },

    #' @param taskName Character. Task folder or file name.
    #' @param databaseName Character or `NULL`. Database name to use when the
    #'   context is shared across multiple config blocks.
    #' @return Character. Absolute result path for the supplied task.
    getResultsPath = function(taskName = NULL, databaseName = private$.databaseName) {
      checkmate::assert_string(taskName, null.ok = TRUE)
      checkmate::assert_string(databaseName, min.chars = 1)
      path <- fs::path(
        private$.execPath,
        snakecase::to_snake_case(databaseName),
        private$.pipelineVersion
      )
      if (!is.null(taskName)) {
        path <- fs::path(path, taskName)
      }
      return(path)
    }
  ),

  private = list(
    .mode = NULL,
    .pipelineVersion = NULL,
    .studyVersion = NULL,
    .baseCohortTable = NULL,
    .cohortTable = NULL,
    .databaseName = NULL,
    .execPath = NULL,
    .maxTableNameLength = NULL,

    assert_table_name_length = function(base_cohort_table, cohort_table) {
      if (is.null(private$.maxTableNameLength) ||
          nchar(cohort_table) <= private$.maxTableNameLength) {
        return(invisible(NULL))
      }
      cli::cli_abort(c(
        "Derived cohort table name is too long.",
        i = "Base table {.val {base_cohort_table}} has {nchar(base_cohort_table)} characters.",
        i = "Pipeline version {.val {private$.pipelineVersion}} produces {.val {cohort_table}} ({nchar(cohort_table)} characters).",
        i = "The maximum permitted length is {private$.maxTableNameLength} characters."
      ))
    }
  )
)

#' @title Resolve a task results path
#' @description Returns the absolute `exec/results/<database>/<pipelineVersion>/<taskName>`
#'   path for a run. When an `ExecutionContext` is supplied it is used directly;
#'   otherwise an equivalent one is derived from the `ExecutionSettings` object
#'   and the pipeline version. This keeps every results-folder path in the
#'   package flowing through [ExecutionContext]'s `getResultsPath()` rather than
#'   being hand-assembled at each call site.
#' @param executionSettings An `ExecutionSettings` object; supplies the database name.
#' @param pipelineVersion Character. Test namespace (e.g. `"develop_ml"`) or
#'   semantic version (e.g. `"1.0.2"`). Ignored when `executionContext` is supplied.
#' @param taskName Character or `NULL`. Task folder name appended to the path.
#' @param executionContext Optional `ExecutionContext` for the current run.
#' @param execPath Character. Base results path. Defaults to `exec/results` in
#'   the current study project. Ignored when `executionContext` is supplied.
#' @return Character. The absolute results path (not created).
#' @keywords internal
resolveResultsPath <- function(executionSettings,
                               pipelineVersion,
                               taskName = NULL,
                               executionContext = NULL,
                               execPath = here::here("exec/results")) {
  checkmate::assert_class(executionSettings, "ExecutionSettings")
  checkmate::assert_class(executionContext, "ExecutionContext", null.ok = TRUE)

  if (is.null(executionContext)) {
    executionContext <- newExecutionContext(
      pipelineVersion,
      databaseName = executionSettings$databaseName,
      execPath = execPath
    )
  }

  executionContext$getResultsPath(
    taskName = taskName,
    databaseName = executionSettings$databaseName
  )
}
