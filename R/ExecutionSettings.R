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
