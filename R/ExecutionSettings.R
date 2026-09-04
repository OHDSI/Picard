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
      checkmate::assert_class(x = connection, classes = "DatabaseConnectorJdbcConnection", null.ok = TRUE)
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
      
      if (!inherits(conObj, "DatabaseConnectorJdbcConnection")) {
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
    #' @return DatabaseConnectorJdbcConnection or NULL
    getConnection = function() {
      conObj <- private$.connection
      
      if (is.null(conObj)) {
        cli::cli_alert_warning("No active database connection. Call $connect() to establish one.")
        return(NULL)
      }
      
      if (!inherits(conObj, "DatabaseConnectorJdbcConnection")) {
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
      if (!inherits(conObj, "DatabaseConnectorJdbcConnection")) return(FALSE)
      
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

#' ExecutionContext R6 Class
#'
#' Describes one Picard pipeline execution and derives the names used to
#' isolate its database and filesystem outputs. Database connection details
#' remain in [ExecutionSettings]; this class owns execution mode and
#' namespacing.
#'
#' @param mode Character. Either `"test"` or `"production"`.
#' @param namespace Character. The complete execution namespace. Test
#'   namespaces are normalized to lowercase snake case; production namespaces
#'   must be semantic versions.
#' @param studyVersion Character or `NULL`. The study version associated with
#'   the execution. Required for production and optional for test runs.
#' @param baseCohortTable Character. The configured, unsuffixed cohort table.
#' @param databaseName Character. Human-readable database name used in result
#'   paths.
#' @param execPath Character. Base path for execution results. Defaults to
#'   `exec/results` in the current study project.
#' @param maxTableNameLength Integer. Maximum permitted length of the derived
#'   cohort table name. Defaults to 30, the strict portable limit.
#'
#' @return An `ExecutionContext` R6 object.
#' @export
ExecutionContext <- R6::R6Class(
  classname = "ExecutionContext",
  public = list(
    initialize = function(mode = c("test", "production"),
                          namespace,
                          studyVersion = NULL,
                          baseCohortTable,
                          databaseName,
                          execPath = here::here("exec/results"),
                          maxTableNameLength = 30L) {
      mode <- match.arg(mode)
      checkmate::assert_string(namespace, min.chars = 1)
      checkmate::assert_string(baseCohortTable, min.chars = 1)
      checkmate::assert_string(databaseName, min.chars = 1)
      checkmate::assert_string(execPath, min.chars = 1)
      checkmate::assert_int(maxTableNameLength, lower = 1)

      if (mode == "production") {
        checkmate::assert_string(studyVersion, min.chars = 1)
        if (!grepl("^\\d+\\.\\d+\\.\\d+$", studyVersion)) {
          cli::cli_abort("Production studyVersion must use MAJOR.MINOR.PATCH format.")
        }
        if (!identical(namespace, studyVersion)) {
          cli::cli_abort("Production namespace must match studyVersion.")
        }
        normalized_namespace <- namespace
        cohort_table <- baseCohortTable
      } else {
        normalized_namespace <- private$normalize_namespace(namespace)
        cohort_table <- paste0(baseCohortTable, "_", normalized_namespace)
      }

      if (nchar(cohort_table) > maxTableNameLength) {
        cli::cli_abort(c(
          "Derived cohort table name is too long.",
          i = "Base table {.val {baseCohortTable}} has {nchar(baseCohortTable)} characters.",
          i = "Namespace {.val {normalized_namespace}} produces {.val {cohort_table}} ({nchar(cohort_table)} characters).",
          i = "The maximum permitted length is {maxTableNameLength} characters."
        ))
      }

      private$.mode <- mode
      private$.namespace <- normalized_namespace
      private$.studyVersion <- studyVersion
      private$.baseCohortTable <- baseCohortTable
      private$.cohortTable <- cohort_table
      private$.databaseName <- databaseName
      private$.execPath <- fs::path_abs(execPath)
      private$.maxTableNameLength <- maxTableNameLength
    },

    #' @return Character. Execution mode, either `"test"` or `"production"`.
    getMode = function() {
      private$.mode
    },

    #' @return Character. Normalized execution namespace.
    getNamespace = function() {
      private$.namespace
    },

    #' @return Character or `NULL`. Associated production study version.
    getStudyVersion = function() {
      private$.studyVersion
    },

    #' @return Character. Effective cohort table name for this execution.
    getCohortTable = function() {
      private$.cohortTable
    },

    #' @param taskName Character. Task folder or file name.
    #' @return Character. Absolute result path for the supplied task.
    getResultsPath = function(taskName = NULL) {
      checkmate::assert_string(taskName, null.ok = TRUE)
      path <- fs::path(
        private$.execPath,
        snakecase::to_snake_case(private$.databaseName),
        private$.namespace
      )
      if (!is.null(taskName)) {
        path <- fs::path(path, taskName)
      }
      path
    }
  ),

  private = list(
    .mode = NULL,
    .namespace = NULL,
    .studyVersion = NULL,
    .baseCohortTable = NULL,
    .cohortTable = NULL,
    .databaseName = NULL,
    .execPath = NULL,
    .maxTableNameLength = NULL,

    normalize_namespace = function(namespace) {
      normalized <- tolower(trimws(namespace))
      normalized <- gsub("[^a-z0-9]+", "_", normalized)
      normalized <- gsub("^_+|_+$", "", normalized)
      normalized <- gsub("_+", "_", normalized)

      if (!nzchar(normalized)) {
        cli::cli_abort("Test namespace must contain at least one letter or number.")
      }

      normalized
    }
  )
)
