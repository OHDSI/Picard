#' @title Validate Study Task Script
#' @description Validates that a study task R script has all required components to work
#'   in the pipeline. Checks for required sections, template variables, executionSettings
#'   creation, output folder setup, and non-empty script section.
#' @param taskFilePath Character. The full path to the task R script to validate.
#' @return Logical. Returns TRUE if valid. Stops with an error message if validation fails.
#' @details
#' A valid study task must contain:
#' - Section headers: A. Meta, B. Dependencies, C. Connection Settings, D. Task Settings, E. Script
#' - Template variables: !||configBlock||! and !||pipelineVersion||!
#' - ExecutionSettings creation (assignment to executionSettings object)
#' - Output folder creation (assignment to outputFolder object)
#' - Non-empty E. Script section (more than just the template comment)
#' @export
validateStudyTask <- function(taskFilePath) {
  
  # Verify file exists
  if (!file.exists(taskFilePath)) {
    cli::cli_alert_danger("Task file not found: {fs::path_rel(taskFilePath)}")
    stop("Task file does not exist")
  }
  
  # Read the file
  tryCatch({
    fileContent <- readr::read_file(taskFilePath)
  }, error = function(e) {
    cli::cli_alert_danger("Failed to read task file: {e$message}")
    stop("Error reading task file")
  })
  
  # Split into lines for section checking
  fileLines <- readr::read_lines(taskFilePath)
  
  # List of required sections
  requiredSections <- c(
    "A. Meta",
    "B. Dependencies",
    "C. Connection Settings",
    "D. Task Settings",
    "E. Script"
  )
  
  # Check for required sections
  missingSections <- character()
  for (section in requiredSections) {
    if (!any(grepl(section, fileLines, fixed = TRUE))) {
      missingSections <- c(missingSections, section)
    }
  }
  
  if (length(missingSections) > 0) {
    cli::cli_alert_danger("Missing required sections in task file:")
    cli::cli_bullets(setNames(missingSections, "x"))
    stop("Task is missing required sections")
  }
  
  # Check for required template variables
  requiredVars <- c("!||configBlock||!", "!||pipelineVersion||!")
  missingVars <- character()
  
  for (var in requiredVars) {
    if (!grepl(var, fileContent, fixed = TRUE)) {
      missingVars <- c(missingVars, var)
    }
  }
  
  if (length(missingVars) > 0) {
    cli::cli_alert_danger("Missing required template variables:")
    cli::cli_bullets(setNames(missingVars, "x"))
    stop("Task is missing required configuration variables")
  }
  
  # Check for executionSettings creation
  if (!grepl("executionSettings\\s*(<-|=)", fileContent)) {
    cli::cli_alert_danger("Task must create an executionSettings object")
    cli::cli_bullets(c(
      i = "Add: {.code executionSettings <- createExecutionSettingsFromConfig(configBlock = configBlock)}"
    ))
    stop("executionSettings object not created")
  }
  
  # Check for outputFolder creation
  if (!grepl("outputFolder\\s*(<-|=)", fileContent)) {
    cli::cli_alert_danger("Task must create an outputFolder object")
    cli::cli_bullets(c(
      i = "Add: {.code outputFolder <- setOutputFolder(executionSettings = executionSettings, ...)} in section D"
    ))
    stop("outputFolder object not created")
  }
  
  # Check that E. Script section has actual code (not just template comment)
  eScriptIndex <- which(grepl("E. Script", fileLines, fixed = TRUE))
  
  if (length(eScriptIndex) > 0) {
    # Get lines after E. Script section
    scriptLinesStart <- eScriptIndex[1] + 1
    scriptLines <- fileLines[scriptLinesStart:length(fileLines)]
    
    # Remove empty lines and comment lines that are just the template notes
    codeLines <- scriptLines[
      scriptLines != "" & 
      !grepl("^\\s*#.*Note: Add code", scriptLines)
    ]
    
    # Check if there's any actual code (not just comments)
    actualCode <- codeLines[!grepl("^\\s*#", codeLines)]
    
    if (length(actualCode) == 0 || all(trimws(actualCode) == "")) {
      cli::cli_alert_danger("E. Script section is empty!")
      cli::cli_bullets(c(
        i = "Add analysis or processing code under the 'E. Script' section"
      ))
      stop("Task has no implementation code in E. Script section")
    }
  }
  
  cli::cli_alert_success("Task validation successful: {fs::path_rel(taskFilePath)}")
  invisible(TRUE)
}

#' @importFrom yaml read_yaml
#' @title Validate config.yml File Structure
#' @description Validates that a config.yml file has the correct structure, required fields,
#'   and that sensitive credentials (user, password, connectionString) use !expr instead of
#'   plain text values. Checks each config block for consistency and DBMS-specific requirements.
#' @param configFilePath Character. Path to the config.yml file. If NULL, looks for config.yml
#'   in the current working directory.
#' @return Logical. Returns TRUE if valid. Stops with informative error messages if validation fails.
#' @details
#' A valid config.yml must have:
#' - Top-level version field (e.g., "version: 1.0.0")
#' - Top-level projectName field (character)
#' - One or more config blocks with required fields:
#'   - dbms: Database management system type (snowflake, postgresql, sql server, etc.)
#'   - user: !expr expression for credentials
#'   - password: !expr expression for credentials
#'   - cdmDatabaseSchema: OMOP CDM schema name
#'   - workDatabaseSchema: Schema for writing results
#'   - cohortTable: Name of cohort table
#'   - databaseName: Human-readable database name
#'
#' DBMS-specific requirements:
#' - Snowflake: Must have connectionString (!expr)
#' - PostgreSQL/SQL Server: Must have server and port
#'
#' Security check:
#' - user, password, connectionString fields MUST use !expr (not plain values)
#'
#' @export
validateConfigYaml <- function(configFilePath = NULL) {
  
  if (is.null(configFilePath)) {
    configFilePath <- "config.yml"
  }
  
  # Check file exists
  if (!file.exists(configFilePath)) {
    cli::cli_alert_danger("Config file not found: {fs::path_rel(configFilePath)}")
    stop("config.yml does not exist")
  }
  
  cli::cli_alert_info("Validating config file: {fs::path_rel(configFilePath)}")
  
  # Read raw file content for text-based validation (to check for !expr)
  tryCatch({
    rawContent <- readr::read_file(configFilePath)
  }, error = function(e) {
    cli::cli_alert_danger("Failed to read config file: {e$message}")
    stop("Error reading config.yml")
  })
  
  # Parse YAML
  configList <- tryCatch({
    yaml::read_yaml(configFilePath, eval.expr =FALSE)
  }, error = function(e) {
    cli::cli_alert_danger("Failed to parse YAML: {e$message}")
    stop("config.yml is not valid YAML")
  })
  
  # Check for top-level required fields (or in default block if not at top level)
  topLevelRequired <- c("version", "projectName")
  
  # Try to get version and projectName - check top level first, then default block
  version <- configList$version
  projectName <- configList$projectName
  
  if (is.null(version) && !is.null(configList$default)) {
    version <- configList$default$version
  }
  
  if (is.null(projectName) && !is.null(configList$default)) {
    projectName <- configList$default$projectName
  }
  
  missingTopLevel <- character()
  if (is.null(version)) {
    missingTopLevel <- c(missingTopLevel, "version")
  }
  if (is.null(projectName)) {
    missingTopLevel <- c(missingTopLevel, "projectName")
  }
  
  if (length(missingTopLevel) > 0) {
    cli::cli_alert_danger("Missing required fields in config.yml:")
    cli::cli_bullets(setNames(missingTopLevel, "x"))
    cli::cli_bullets(c(i = "These can be at the top level or in the 'default' block"))
    stop("config.yml is missing required fields")
  }
  
  # Validate version format (MAJOR.MINOR.PATCH)
  if (!grepl("^\\d+\\.\\d+\\.\\d+$", as.character(version))) {
    cli::cli_alert_danger("Invalid version format: {version}")
    cli::cli_bullets(c(i = "Use semantic versioning format: MAJOR.MINOR.PATCH (e.g., 1.0.0)"))
    stop("Invalid version format in config.yml")
  }
  
  # Check that projectName is a string
  if (!is.character(projectName)) {
    cli::cli_alert_danger("projectName must be a character string")
    stop("Invalid projectName type")
  }
  
  # Identify config blocks (any top-level key that's a list and not a reserved field)
  reservedFields <- c("version", "projectName", "default")
  configBlockNames <- setdiff(names(configList), reservedFields)
  
  if (length(configBlockNames) == 0) {
    cli::cli_alert_danger("No database config blocks found in config.yml")
    cli::cli_bullets(c(i = "Define at least one config block (e.g., database1:, optum_dod:, etc.)"))
    stop("config.yml has no database configuration blocks")
  }
  
  # Check for !expr usage in raw file (text-based check)
  credentialFields <- c("user", "password", "connectionString")
  
  # Pattern to find credential assignments
  credentialPattern <- paste0("(", paste(credentialFields, collapse = "|"), ")\\s*:\\s*([^\\n]+)")
  credMatches <- gregexpr(credentialPattern, rawContent, perl = TRUE)
  
  if (length(unlist(credMatches)) > 0) {
    # Extract matched lines and flatten to character vector
    credentialLines <- regmatches(rawContent, credMatches)
    credentialLines <- unlist(credentialLines)  # Flatten list to vector
    
    for (line in credentialLines) {
      if (!grepl("!expr", line, fixed = TRUE)) {
        cli::cli_alert_warning("Found credential field without !expr:")
        cli::cli_bullets(c(
          x = line,
          i = "Credentials must use !expr (e.g., {.code user: !expr Sys.getenv('dbUser')})"
        ))
        stop("Credential fields must use !expr expressions")
      }
    }
  }
  
  # Validate each config block
  blockErrors <- list()
  
  for (blockName in configBlockNames) {
    blockConfig <- configList[[blockName]]
    
    # Ensure it's a list
    if (!is.list(blockConfig)) {
      blockErrors[[blockName]] <- "Config block must be a YAML object/dictionary"
      next
    }
    
    # Check required block fields
    blockRequired <- c("dbms", "user", "password", "cdmDatabaseSchema", 
                       "workDatabaseSchema", "cohortTable", "databaseName")
    missingFields <- setdiff(blockRequired, names(blockConfig))
    
    if (length(missingFields) > 0) {
      blockErrors[[blockName]] <- paste(
        "Missing required fields:",
        paste(missingFields, collapse = ", ")
      )
      next
    }
    
    # Validate DBMS type
    dbms <- tolower(as.character(blockConfig$dbms))
    validDbms <- c("snowflake", "postgresql", "sql server", "mysql", "redshift", "oracle")
    
    if (!dbms %in% validDbms) {
      blockErrors[[blockName]] <- paste(
        "Unknown DBMS type: '", blockConfig$dbms, "'.",
        "Valid options:", paste(validDbms, collapse = ", ")
      )
      next
    }
    
    # DBMS-specific validation
    if (dbms == "snowflake") {
      if (is.null(blockConfig$connectionString)) {
        blockErrors[[blockName]] <- "Snowflake config must include 'connectionString' field"
        next
      }
    } else {
      # PostgreSQL, SQL Server, etc. require server and port
      if (is.null(blockConfig$server)) {
        blockErrors[[blockName]] <- paste(
          dbms, "config must include 'server' field"
        )
        next
      }
      if (is.null(blockConfig$port)) {
        blockErrors[[blockName]] <- paste(
          dbms, "config must include 'port' field"
        )
        next
      }
    }
    
    # Validate that schema names are non-empty strings
    schemaFields <- c("cdmDatabaseSchema", "workDatabaseSchema", "tempEmulationSchema")
    for (schemaField in schemaFields[schemaFields %in% names(blockConfig)]) {
      schemaValue <- blockConfig[[schemaField]]
      if (!is.character(schemaValue) || schemaValue == "") {
        blockErrors[[blockName]] <- paste(schemaField, "must be a non-empty string")
        next
      }
    }
    
    # Validate cohortTable and databaseName are non-empty strings
    if (!is.character(blockConfig$cohortTable) || blockConfig$cohortTable == "") {
      blockErrors[[blockName]] <- "cohortTable must be a non-empty string"
      next
    }
    
    if (!is.character(blockConfig$databaseName) || blockConfig$databaseName == "") {
      blockErrors[[blockName]] <- "databaseName must be a non-empty string"
      next
    }
  }
  
  # Report any block errors
  if (length(blockErrors) > 0) {
    cli::cli_alert_danger("Validation failed for {length(blockErrors)} config block(s):")
    for (blockName in names(blockErrors)) {
      cli::cli_alert_danger("Block '{blockName}': {blockErrors[[blockName]]}")
    }
    stop("config.yml has validation errors")
  }
  
  cli::cli_alert_success("Config validation successful!")
  cli::cli_bullets(c(
    "v" = "{length(configBlockNames)} config block(s) validated",
    "v" = "All required fields present",
    "v" = "Credentials properly use !expr",
    "v" = "DBMS types valid and properly configured"
  ))

  invisible(TRUE)
}


# ============================================================================
# Pre-flight Validators
# ============================================================================

#' @title Validate Results Folder is Fresh
#' @description Checks that the versioned results folder does not already contain
#'   output files. An existing but empty folder is allowed; a folder with files
#'   indicates a version collision and will block execution.
#' @param pipelineVersion Character. The pipeline version string (e.g., "1.2.3").
#' @param resultsPath Character. Path to the results root folder.
#'   Defaults to "exec/results" relative to the project root.
#' @return Logical TRUE invisibly if check passes. Stops with error if collision detected.
#' @keywords internal
validateResultsFolderFresh <- function(pipelineVersion,
                                       resultsPath = here::here("exec/results")) {
  versionPath <- fs::path(resultsPath, pipelineVersion)

  if (!dir.exists(versionPath)) {
    return(invisible(TRUE))
  }

  existingFiles <- fs::dir_ls(versionPath, recurse = TRUE, type = "file")

  if (length(existingFiles) > 0) {
    cli::cli_abort(c(
      "Results folder already contains data for version {.val {pipelineVersion}}",
      "i" = "Path: {.path {fs::path_rel(versionPath)}}",
      "i" = "{length(existingFiles)} existing file{?s}",
      "i" = "Increment your pipeline version or remove the existing results"
    ))
  }

  invisible(TRUE)
}


#' @title Validate Config Blocks Exist in config.yml
#' @description Checks that every config block name in the supplied vector
#'   corresponds to a top-level key in config.yml. Catches typos before
#'   a mid-run failure.
#' @param configBlock Character vector. Config block names to validate.
#' @param configFilePath Character. Path to config.yml. Defaults to
#'   "config.yml" in the working directory.
#' @return Logical TRUE invisibly if all blocks exist. Stops with error if any are missing.
#' @keywords internal
validateConfigBlockCompleteness <- function(configBlock,
                                            configFilePath = "config.yml") {
  if (!file.exists(configFilePath)) {
    cli::cli_abort("config.yml not found at {.path {configFilePath}}")
  }

  configList <- tryCatch(
    yaml::read_yaml(configFilePath, eval.expr = FALSE),
    error = function(e) cli::cli_abort("Failed to parse config.yml: {e$message}")
  )

  reservedFields <- c("version", "projectName", "default")
  availableBlocks <- setdiff(names(configList), reservedFields)
  missingBlocks <- setdiff(configBlock, availableBlocks)

  if (length(missingBlocks) > 0) {
    cli::cli_abort(c(
      "{length(missingBlocks)} config block{?s} not found in config.yml:",
      setNames(paste0("'", missingBlocks, "'"), rep("x", length(missingBlocks))),
      "i" = "Available: {.val {availableBlocks}}"
    ))
  }

  invisible(TRUE)
}


#' @title Validate Concept Set Manifest
#' @description Checks whether a concept set manifest SQLite database exists and
#'   contains records. Absence of the manifest is not a blocking error — not all
#'   studies use concept sets. Returns a status indicator for the pre-flight
#'   orchestrator to interpret.
#' @param conceptSetsFolderPath Character. Path to the concept sets folder.
#'   Defaults to "inputs/conceptSets" relative to the project root.
#' @return Invisibly returns "no_manifest", "empty", an integer record count,
#'   or "error" depending on findings.
#' @keywords internal
validateConceptSetManifest <- function(conceptSetsFolderPath = here::here("inputs/conceptSets")) {
  dbPath <- fs::path(conceptSetsFolderPath, "conceptSetManifest.sqlite")

  if (!file.exists(dbPath)) {
    return(invisible("no_manifest"))
  }

  tryCatch({
    conn <- DBI::dbConnect(RSQLite::SQLite(), as.character(dbPath))
    on.exit(DBI::dbDisconnect(conn), add = TRUE)
    tables <- DBI::dbListTables(conn)

    if (length(tables) == 0) {
      return(invisible("empty"))
    }

    n <- DBI::dbGetQuery(
      conn,
      sprintf('SELECT COUNT(*) AS n FROM "%s"', tables[1])
    )$n

    invisible(as.integer(n))
  }, error = function(e) {
    invisible("error")
  })
}


#' @title Validate Database Connectivity
#' @description Attempts a test connection to each config block's database using
#'   the project's config.yml credentials. Only called when
#'   \code{skipConnectivityCheck = FALSE} in \code{execStudyPipeline()}.
#'   Returns a named list of pass/warn results per block.
#' @param configBlock Character vector. Config block names to test.
#' @return Named list of result lists with \code{status} and \code{message} per block.
#' @keywords internal
validateDatabaseConnectivity <- function(configBlock) {
  results <- list()

  for (block in configBlock) {
    result <- tryCatch({
      execSettings <- createExecutionSettingsFromConfig(
        configBlock = block,
        pipelineVersion = "dev"
      )
      conn <- suppressMessages(
        DatabaseConnector::connect(execSettings$connectionDetails)
      )
      suppressMessages(DatabaseConnector::disconnect(conn))
      list(status = "pass", message = "Connected successfully")
    }, error = function(e) {
      msg <- strsplit(conditionMessage(e), "\n")[[1]][1]
      list(status = "warn", message = paste0("Failed: ", msg))
    })

    results[[block]] <- result
  }

  results
}


#' @title Validate Task File Dependencies
#' @description Scans all task files in the tasks folder for static
#'   \code{source("...")} calls and checks that each referenced path exists on
#'   disk. Only plain string arguments are detected; dynamic \code{source()}
#'   calls are not evaluated.
#' @param tasksFolderPath Character. Path to the analysis/tasks folder.
#'   Defaults to "analysis/tasks" relative to the project root.
#' @return Invisibly returns a list with \code{missing} (character vector of
#'   missing paths) and \code{total} (integer count of all source paths found).
#' @keywords internal
validateTaskDependencies <- function(tasksFolderPath = here::here("analysis/tasks")) {
  if (!dir.exists(tasksFolderPath)) {
    return(invisible(list(missing = character(0), total = 0L)))
  }

  taskFiles <- fs::dir_ls(tasksFolderPath, type = "file")

  if (length(taskFiles) == 0) {
    return(invisible(list(missing = character(0), total = 0L)))
  }

  sourcePaths <- character(0)

  for (taskFile in taskFiles) {
    lines <- tryCatch(readr::read_lines(taskFile), error = function(e) character(0))
    matches <- regmatches(
      lines,
      regexpr('source\\s*\\(\\s*["\']([^"\']+)["\']', lines, perl = TRUE)
    )
    matches <- matches[nchar(matches) > 0]

    if (length(matches) > 0) {
      paths <- sub('.*source\\s*\\(\\s*["\']([^"\']+)["\'].*', "\\1", matches, perl = TRUE)
      sourcePaths <- c(sourcePaths, paths)
    }
  }

  if (length(sourcePaths) == 0) {
    return(invisible(list(missing = character(0), total = 0L)))
  }

  missingPaths <- sourcePaths[!file.exists(sourcePaths)]
  invisible(list(missing = missingPaths, total = length(sourcePaths)))
}


#' @title Run Pre-flight Checks
#' @description Runs all pre-execution validation checks and displays a consolidated
#'   pass/warn/fail/skip checklist before the pipeline starts. All checks are run
#'   regardless of individual outcomes; the pipeline stops only after the full
#'   checklist has been displayed — replacing the previous pattern of scattered
#'   inline validators that stopped on first failure.
#' @param configBlock Character vector. Config block names.
#' @param pipelineVersion Character. The prospective pipeline version string.
#' @param testMode Logical. If TRUE, code-state, renv, results-folder, connectivity,
#'   and branch-sync checks are skipped.
#' @param skipRenv Logical. If TRUE, renv environment check is skipped.
#' @param skipConnectivityCheck Logical. If TRUE (default), database connectivity
#'   check is skipped.
#' @param resultsPath Character. Path to the results root folder for collision check.
#' @param tasksFolderPath Character. Path to the tasks folder.
#' @return Invisibly returns a list with \code{lockfileHash} and
#'   \code{taskFilesToRun} for downstream use in \code{execute_pipeline()}.
#' @keywords internal
runPreflightChecks <- function(configBlock,
                               pipelineVersion,
                               testMode = FALSE,
                               skipRenv = FALSE,
                               skipConnectivityCheck = TRUE,
                               resultsPath = here::here("exec/results"),
                               tasksFolderPath = here::here("analysis/tasks")) {

  results <- list()

  # Helper: run a single check silently, capture pass/fail result.
  # Only used for checks that do not need to return a side value — avoids <<-.
  .runCheck <- function(name, fn, skip_cond = FALSE, skip_msg = "Skipped") {
    if (skip_cond) {
      return(list(name = name, status = "skip", message = skip_msg))
    }

    result <- NULL

    invisible(utils::capture.output(
      result <- tryCatch(
        {
          val <- fn()
          list(
            name = name,
            status = "pass",
            message = if (is.character(val) && length(val) == 1L) val else "OK"
          )
        },
        error = function(e) {
          msg <- cli::ansi_strip(conditionMessage(e))
          msg <- strsplit(msg, "\n")[[1]][1]
          list(name = name, status = "fail", message = msg)
        }
      ),
      type = "message"
    ))

    result
  }

  # 1. Branch guard (always run)
  results[["Branch"]] <- .runCheck("Branch", function() {
    branch <- gert::git_branch()
    if (branch == "main") stop("On main \u2014 production runs require a release branch")
    paste0("On '", branch, "' (not main)")
  })

  # 2. Code state (skip in test mode)
  results[["Code state"]] <- .runCheck(
    "Code state",
    function() {
      sha <- validateCodeState()
      paste0("Clean (commit ", substr(sha, 1, 7), ")")
    },
    skip_cond = testMode,
    skip_msg = "Test mode"
  )

  # 3. Environment / renv — inlined to capture lockfileHash without <<-
  if (testMode || skipRenv) {
    lockfileHash <- NULL
    results[["Environment"]] <- list(
      name = "Environment",
      status = "skip",
      message = if (testMode) "Test mode" else "skipRenv = TRUE"
    )
  } else {
    env_check <- tryCatch({
      suppressMessages({
        validateEnvironment()
        lh <- snapshotEnvironment()
      })
      list(status = "pass", message = "renv.lock in sync", lockfileHash = lh)
    }, error = function(e) {
      msg <- strsplit(cli::ansi_strip(conditionMessage(e)), "\n")[[1]][1]
      list(status = "fail", message = msg, lockfileHash = NULL)
    })

    lockfileHash <- env_check$lockfileHash
    results[["Environment"]] <- list(
      name = "Environment",
      status = env_check$status,
      message = env_check$message
    )
  }

  # 4. Config YAML structure (always run)
  results[["Config"]] <- .runCheck("Config", function() {
    validateConfigYaml()
    "config.yml valid"
  })

  # 5. Config blocks exist in config.yml (always run)
  results[["Config blocks"]] <- .runCheck("Config blocks", function() {
    validateConfigBlockCompleteness(configBlock)
    paste0(paste(configBlock, collapse = ", "), " found in config.yml")
  })

  # 6. Results folder fresh (skip in test mode — version is always "dev")
  results[["Results folder"]] <- .runCheck(
    "Results folder",
    function() {
      validateResultsFolderFresh(pipelineVersion, resultsPath)
      paste0("exec/results/", pipelineVersion, "/ is available")
    },
    skip_cond = testMode,
    skip_msg = "Test mode"
  )

  # 7. Cohort manifest — inlined to capture missingCohorts without <<-
  cohort_check <- tryCatch({
    suppressMessages({
      temp_manifest <- loadCohortManifest(executionSettings = NULL, verbose = FALSE)
      manifest_status <- temp_manifest$validateManifest()
    })
    active  <- manifest_status[manifest_status$status == "active", ]
    missing <- manifest_status[
      manifest_status$status == "active" & !manifest_status$file_exists,
    ]
    msg <- if (nrow(missing) > 0) {
      paste0(nrow(active), " active cohorts (", nrow(missing), " file(s) missing \u2014 see prompt below)")
    } else {
      paste0(nrow(active), " active cohort(s)")
    }
    list(status = "pass", message = msg, missing = missing)
  }, error = function(e) {
    msg <- strsplit(cli::ansi_strip(conditionMessage(e)), "\n")[[1]][1]
    list(status = "fail", message = msg, missing = data.frame())
  })

  missingCohorts <- cohort_check$missing
  results[["Cohort manifest"]] <- list(
    name = "Cohort manifest",
    status = cohort_check$status,
    message = cohort_check$message
  )

  # 8. Concept set manifest (warn-only — absence is acceptable)
  cs_result <- validateConceptSetManifest()
  results[["Concept sets"]] <- if (identical(cs_result, "no_manifest")) {
    list(name = "Concept sets", status = "warn", message = "No manifest \u2014 OK if concept sets not used")
  } else if (identical(cs_result, "empty")) {
    list(name = "Concept sets", status = "warn", message = "Manifest database is empty")
  } else if (identical(cs_result, "error")) {
    list(name = "Concept sets", status = "warn", message = "Could not read manifest")
  } else {
    list(name = "Concept sets", status = "pass",
         message = paste0(cs_result, " concept set record(s) found"))
  }

  # 9. Database connectivity (warn-only; skipped by default)
  results[["DB connectivity"]] <- if (testMode || skipConnectivityCheck) {
    skip_reason <- if (testMode) "Test mode" else "Use skipConnectivityCheck = FALSE to enable"
    list(name = "DB connectivity", status = "skip", message = skip_reason)
  } else {
    conn_results <- tryCatch(
      validateDatabaseConnectivity(configBlock),
      error = function(e) NULL
    )

    if (is.null(conn_results)) {
      list(name = "DB connectivity", status = "warn", message = "Connectivity check failed unexpectedly")
    } else {
      failed <- Filter(function(r) r$status != "pass", conn_results)

      if (length(failed) > 0) {
        list(name = "DB connectivity", status = "warn",
             message = paste0("Failed: ", paste(names(failed), collapse = ", ")))
      } else {
        list(name = "DB connectivity", status = "pass",
             message = paste0(length(conn_results), " connection(s) verified"))
      }
    }
  }

  # 10. Task files — inlined to capture taskFilesToRun without <<-
  task_check <- tryCatch({
    if (!dir.exists(tasksFolderPath)) {
      stop(paste0("Tasks folder not found: ", tasksFolderPath))
    }

    files <- fs::dir_ls(tasksFolderPath, type = "file") |> basename() |> sort()

    if (length(files) == 0) {
      stop("No task files found in analysis/tasks")
    }

    list(status = "pass", message = paste0(length(files), " task file(s) found"), files = files)
  }, error = function(e) {
    msg <- strsplit(cli::ansi_strip(conditionMessage(e)), "\n")[[1]][1]
    list(status = "fail", message = msg, files = character(0))
  })

  taskFilesToRun <- task_check$files
  results[["Tasks"]] <- list(
    name = "Tasks",
    status = task_check$status,
    message = task_check$message
  )

  # 11. Task source() dependencies (warn-only)
  task_deps <- validateTaskDependencies(tasksFolderPath)
  results[["Task deps"]] <- if (task_deps$total == 0L) {
    list(name = "Task deps", status = "pass", message = "No source() dependencies")
  } else if (length(task_deps$missing) > 0) {
    list(name = "Task deps", status = "warn",
         message = paste0(length(task_deps$missing), " missing source() path(s) of ", task_deps$total))
  } else {
    list(name = "Task deps", status = "pass",
         message = paste0("All ", task_deps$total, " source() path(s) resolved"))
  }

  # 12. Release branch freshness (warn-only; skip in test mode)
  results[["Branch sync"]] <- if (testMode) {
    list(name = "Branch sync", status = "skip", message = "Test mode")
  } else {
    freshness <- validateReleaseBranchFreshness()

    if (identical(freshness, "no_develop")) {
      list(name = "Branch sync", status = "skip", message = "No 'develop' branch \u2014 skipped")
    } else if (identical(freshness, "stale")) {
      list(name = "Branch sync", status = "warn",
           message = "Branch may not include all commits from develop")
    } else if (identical(freshness, "error")) {
      list(name = "Branch sync", status = "skip", message = "Could not check branch history")
    } else {
      list(name = "Branch sync", status = "pass", message = "Branch is current with develop")
    }
  }

  # --- Display consolidated checklist ---
  checkNames <- names(results)
  maxNameLen <- max(nchar(checkNames))

  cli::cli_rule("Pre-flight Checks")

  for (nm in checkNames) {
    r <- results[[nm]]
    icon <- switch(r$status,
      pass = "\u2713", #checkmark
      fail = "\u2717", #cross
      warn = "~",
      skip = "-",
      "?"
    )
    padded_name <- formatC(nm, width = maxNameLen + 2, flag = "-")
    message(sprintf("  %s %s %s", icon, padded_name, r$message))
  }

  failCount <- sum(vapply(results, function(r) r$status == "fail", logical(1)))
  warnCount <- sum(vapply(results, function(r) r$status == "warn", logical(1)))

  cli::cli_rule()

  if (failCount > 0) {
    suffix <- if (warnCount > 0) paste0(" (", warnCount, " warning(s) noted)") else ""
    cli::cli_abort(
      paste0(failCount, " pre-flight check(s) failed", suffix, ". Fix above and re-run.")
    )
  }

  if (warnCount > 0) {
    cli::cli_alert_warning("{warnCount} warning(s) noted above \u2014 proceeding")
  } else {
    cli::cli_alert_success("All pre-flight checks passed")
  }

  # --- Interactive missing-cohort prompt (fires after full checklist) ---
  if (nrow(missingCohorts) > 0) {
    cli::cli_rule("Missing Cohort Files")
    cli::cli_alert_danger("{nrow(missingCohorts)} cohort file(s) are active in the manifest but missing from disk:")

    for (i in seq_len(nrow(missingCohorts))) {
      cohort <- missingCohorts[i, ]
      cli::cli_bullets(c("x" = "ID {cohort$id}: {cohort$label}"))
    }

    cli::cli_alert_warning("Do you want to continue? Missing cohorts will be skipped.")
    cli::cli_bullets(c(
      "i" = "Yes: pipeline continues, missing cohorts are skipped",
      "i" = "No:  stop and restore files, or run {.code manifest$cleanupMissing()}"
    ))

    response <- readline(prompt = "Continue with pipeline? (yes/no): ")

    if (!tolower(trimws(response)) %in% c("yes", "y")) {
      cli::cli_abort("Pipeline cancelled due to missing cohorts")
    }

    cli::cli_alert_success("Continuing despite {nrow(missingCohorts)} missing cohort(s)...")
  }

  invisible(list(
    lockfileHash = lockfileHash,
    taskFilesToRun = taskFilesToRun
  ))
}
