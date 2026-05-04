#' @title Function to update the study version
#' @param versionNumber the semantic version number to set as the new project version: 1.0.0
#' @param projectPath the path of the project, defaults to the directory of the active Ulysses project
#' @description Updates the version across the project including config.yml, README.md, and NEWS.md.
#'   Prompts the user to document changes from the pipeline run as bullet points which are added to NEWS.
#' @return Invisibly returns the version number
#' @export
updateStudyVersion <- function(versionNumber, projectPath = here::here()) {
  
  cli::cli_rule("Update Study Version")
  
  # Validate semantic versioning format (MAJOR.MINOR.PATCH)
  tryCatch({
    versionParts <- strsplit(versionNumber, "\\.")[[1]]
    
    if (length(versionParts) != 3) {
      cli::cli_alert_danger("Invalid version format: {versionNumber}")
      cli::cli_bullets(c(
        x = "Expected format: MAJOR.MINOR.PATCH",
        i = "Example: 1.2.3",
        i = "Got: {length(versionParts)} part(s) instead of 3"
      ))
      stop("Version must follow semantic versioning (MAJOR.MINOR.PATCH)")
    }
    
    # Verify each part is a non-negative integer
    versionIntegers <- suppressWarnings(as.integer(versionParts))
    
    if (any(is.na(versionIntegers))) {
      cli::cli_alert_danger("Invalid version format: {versionNumber}")
      cli::cli_bullets(c(
        x = "Each version part must be a non-negative integer",
        i = "Example: 1.2.3 (not 1.2.x or 1.2a.3)"
      ))
      stop("Version parts must be valid integers")
    }
    
    if (any(versionIntegers < 0)) {
      cli::cli_alert_danger("Invalid version format: {versionNumber}")
      cli::cli_bullets(c(
        x = "Version parts must be non-negative",
        i = "Example: 1.2.3 (not 1.-2.3)"
      ))
      stop("Version parts must be non-negative")
    }
    
    cli::cli_alert_success("Version format valid: {versionNumber}")
    
  }, error = function(e) {
    if (grepl("Version", e$message)) {
      stop(e$message)
    } else {
      cli::cli_alert_danger("Failed to validate version: {e$message}")
      stop("Invalid version format")
    }
  })
  
  cli::cli_alert_info("Updating project version to: {versionNumber}")
  
  # Update config.yml
  tryCatch({
    configPath <- fs::path(projectPath, "config.yml")
    configYml <- readr::read_lines(configPath)
    versionLine <- which(grepl("  version: ", configYml))
    
    if (length(versionLine) == 0) {
      cli::cli_alert_danger("Version line not found in config.yml")
      stop("Cannot find version configuration in config.yml")
    }
    
    configYml[versionLine] <- glue::glue("  version: {versionNumber}")
    readr::write_lines(x = configYml, file = configPath)
    cli::cli_alert_success("Updated config.yml")
    
  }, error = function(e) {
    cli::cli_alert_danger("Failed to update config.yml: {e$message}")
    stop("Error updating config.yml")
  })
  
  # Update README.md
  tryCatch({
    readmePath <- fs::path(projectPath, "README.md")
    
    if (!file.exists(readmePath)) {
      cli::cli_alert_warning("README.md not found - skipping README version update")
    } else {
      readmeLines <- readr::read_lines(readmePath)
      
      # Look for version badge or version reference
      versionPatterns <- which(grepl("version|Version|VERSION", readmeLines, ignore.case = TRUE))
      
      if (length(versionPatterns) > 0) {
        # Update first occurrence that looks like a version reference
        for (idx in versionPatterns) {
          if (grepl("\\d+\\.\\d+\\.\\d+", readmeLines[idx])) {
            readmeLines[idx] <- gsub("\\d+\\.\\d+\\.\\d+", versionNumber, readmeLines[idx])
            readr::write_lines(x = readmeLines, file = readmePath)
            cli::cli_alert_success("Updated README.md")
            break
          }
        }
      }
    }
    
  }, error = function(e) {
    cli::cli_alert_warning("Failed to update README.md: {e$message}")
  })
  
  # Prompt user for change summary
  cli::cli_rule("Document Changes")
  cli::cli_alert_info("Enter a summary of changes from this pipeline run.")
  cli::cli_bullets(c(i = "Use bullet points separated by new lines", i = "Type 'END' on a new line when finished"))
  
  changeLines <- character()
  repeat {
    userInput <- readline(prompt = "Change (or 'END' to finish): ")
    
    if (tolower(trimws(userInput)) == "end") {
      break
    }
    
    if (trimws(userInput) != "") {
      # Add bullet point formatting if not already present
      if (!grepl("^\\s*[-*+]", userInput)) {
        userInput <- glue::glue("- {userInput}")
      }
      changeLines <- c(changeLines, userInput)
    }
  }
  
  # Update NEWS file
  tryCatch({
    newsPath <- fs::path(projectPath, "NEWS.md")
    
    # Create NEWS file if it doesn't exist
    if (!file.exists(newsPath)) {
      cli::cli_alert_info("Creating NEWS.md file")
      newsContent <- c(
        "# News",
        ""
      )
    } else {
      newsContent <- readr::read_lines(newsPath)
    }
    
    # Format new version entry
    currentDate <- format(Sys.time(), "%Y-%m-%d")
    versionEntry <- c(
      glue::glue("## Version {versionNumber} ({currentDate})"),
      ""
    )
    
    if (length(changeLines) > 0) {
      versionEntry <- c(versionEntry, changeLines, "")
    } else {
      versionEntry <- c(versionEntry, "- No specific changes documented", "")
    }
    
    versionEntry <- c(versionEntry, "")
    
    # Prepend new version to NEWS content (keep existing content)
    updatedNews <- c(versionEntry, newsContent)
    
    readr::write_lines(x = updatedNews, file = newsPath)
    cli::cli_alert_success("Updated NEWS.md")
    
  }, error = function(e) {
    cli::cli_alert_danger("Failed to update NEWS.md: {e$message}")
    stop("Error updating NEWS file")
  })
  
  # Confirmation summary
  cli::cli_rule("Version Update Summary")
  cli::cli_alert_success("Version updated to: {versionNumber}")
  cli::cli_alert_success("Changes documented: {length(changeLines)} item(s)")
  cli::cli_alert_info("Files updated:")
  cli::cli_bullets(c(
    "✓" = "config.yml",
    "✓" = "README.md",
    "✓" = "NEWS.md"
  ))
  cli::cli_rule()
  
  invisible(versionNumber)
}


#' @title Zip and Archive results from a study execution
#' @param input the type of files to zip and archive. There are three options exportMerge, exportPretty and site. exportMerge is the merged results in long format. The exportPretty are xlsx files with formatted output from the study. The site is the html files of the studyHub
#' @returns invisible return. Stores the input as a zip file in the exec/archive folder
#' @export
zipAndArchive <- function(input) {
  #ensure input is one of three options
  checkmate::assert_choice(x = input, choices = c("exportMerge", "exportPretty", "site"))

  # make the archive folder in exec
  if (!dir.exists("exec/archive")) {
    archivePathRoot <- fs::dir_create("exec/archive")
    usethis::use_git_ignore(archivePathRoot)
  }

  # get time stamp of archive
  timeStamp <- lubridate::now() |> as.character() |> snakecase::to_snake_case()

  # pull version number from config
  repoVersion <- config::get(value = "version")

  # if input is exportMerge grab results and prep for archive
  if (input == "exportMerge") {
    files2zip <- fs::dir_ls("dissemination/export/merge", type = "file")
    zipFileName <- glue::glue("exec/archive/export_merge_{repoVersion}_{timeStamp}")
  }

  # if input is exportPretty grab results and prep for archive
  if (input == "exportPretty") {
    files2zip <- fs::dir_ls("dissemination/export/pretty", type = "file")
    zipFileName <- glue::glue("exec/archive/export_pretty_{repoVersion}_{timeStamp}")
  }

  # if input is site grab files and prep for archive
  if (input == "exportMerge") {
    files2zip <- fs::dir_ls("dissemination/quarto/_site", type = "any")
    zipFileName <- glue::glue("exec/archive/quarto_site_{repoVersion}_{timeStamp}")
  }

  # zip results and place in archive
  utils::zip(zipfile = zipFileName, files = files2zip)
  cli::cat_bullet(
    glue::glue("Archived {input} to {zipFileName}."),
    bullet = "tick",
    bullet_col = "green"
  )

  invisible(zipFileName)

}


#' @title Generate Cohorts for Pipeline Execution
#' @description Loads the cohort manifest, displays the cohorts to be generated,
#'   optionally prompts for user confirmation, and then generates the cohorts
#'   and retrieves their counts. This function serves as the foundational step
#'   for all subsequent analytical tasks in the pipeline.
#' @param executionSettings An ExecutionSettings object containing database configuration
#'   for cohort generation. When created via \code{createExecutionSettingsFromConfig()} with
#'   a non-semver \code{pipelineVersion} (e.g. "dev", "test"), the cohort table name will
#'   already have a \code{_dev} suffix applied, keeping dev runs isolated from the
#'   production cohort table.
#' @param pipelineVersion Character. The pipeline version used to organize the output folder structure.
#'   Output will be saved to \code{exec/results/{databaseName}/{pipelineVersion}/00_buildCohorts/}.
#'   Non-semver values (e.g. "dev") also trigger dev cohort table routing via
#'   \code{createExecutionSettingsFromConfig()}.
#' @param override Logical. If TRUE, skips the user confirmation prompt and proceeds
#'   directly with cohort generation. Defaults to FALSE.
#' @return Invisibly returns the cohort counts data frame (id, label, tags, 
#'   cohort_entries, cohort_subjects). Also saves counts to cohortCounts.csv in the 
#'   output folder.
#' @export
generateCohorts <- function(executionSettings, pipelineVersion, override = FALSE) {
  
  # Check if cohortManifest exists
  cohortsFolderPath <- here::here("inputs/cohorts")
  dbPath <- fs::path(cohortsFolderPath, "cohortManifest.sqlite")
  
  if (!file.exists(dbPath)) {
    cli::cli_alert_danger("Cohort Manifest not found!")
    cli::cli_alert_info("Expected location: {fs::path_rel(dbPath)}")
    cli::cli_rule("How to create a Cohort Manifest")
    cli::cli_h2("Step 1: Initialize manifest")
    cli::cli_code("cohortManifest <- initCohortManifest()")
    cli::cli_h2("Step 2: Create cohortsLoad.csv in Excel")
    cli::cli_code("createBlankCohortsLoadFile()")
    cli::cli_h2("Step 3: Import cohorts from ATLAS")
    cli::cli_code("atlasConnection <- setAtlasConnection()")
    cli::cli_code("cohortManifest$importAtlasCohorts(atlasConnection, 'inputs/cohorts/cohortsLoad.csv')")
    cli::cli_h2("Step 4: Load into a new session")
    cli::cli_code("cohortManifest <- loadCohortManifest()")
    cli::cli_bullets(c(
      "Place JSON or SQL files in {.path {cohortsFolderPath}/json} or {.path {cohortsFolderPath}/sql}",
      "Then call: {.code loadCohortManifest()}"
    ))
    cli::cli_rule()
    stop("Cannot proceed without a cohort manifest. Please create one using one of the options above.")
  }
  
  # Load the cohort manifest
  tryCatch({
    cm <- loadCohortManifest(executionSettings = executionSettings)
  }, error = function(e) {
    cli::cli_alert_danger("Failed to load cohort manifest: {e$message}")
    stop("Error loading cohort manifest")
  })
  
  # Get the manifest summary
  cmSummary <- cm$tabulateManifest() # return the dataframe
  
  if (is.null(cmSummary) || nrow(cmSummary) == 0) {
    cli::cli_alert_danger("Cohort manifest is empty!")
    stop("No cohorts found in manifest. Please add cohorts before generating.")
  }
  
  # Display the cohorts that will be generated
  cli::cli_rule("Cohorts to Generate")
  cli::cli_alert_info("Found {nrow(cmSummary)} cohort(s) in manifest")
  
  # Format and display the cohorts
  for (i in seq_len(nrow(cmSummary))) {
    row <- cmSummary[i, ]
    cohort_id <- row$id
    cohort_label <- row$label
    cohort_tags <- row$tags
    
    # Display basic info
    cli::cli_alert_success("Cohort {cohort_id}: {cohort_label}")
    
    # Display tags if available
    if (!is.na(cohort_tags) && cohort_tags != "" && cohort_tags != "NULL") {
      cli::cli_bullets(c(i = "Tags: {cohort_tags}"))
    }
  }
  cli::cli_rule()
  
  # Ask for user confirmation unless override is TRUE
  if (!override) {
    cli::cli_alert_warning("Generate these {nrow(cmSummary)} cohort(s)?")
    response <- readline(prompt = "Continue? (yes/no): ")
    response <- tolower(trimws(response))
    
    if (!(response %in% c("yes", "y"))) {
      cli::cli_alert_info("Cohort generation cancelled by user.")
      cli::cli_bullets(c(
        i = "To modify cohorts, edit cohortsLoad.csv in Excel and re-run",
        i = "To import new cohorts from ATLAS, use {.code importAtlasCohorts()}"
      ))
      return(invisible(NULL))
    }
  }
  
  # Generate cohorts
  cli::cli_alert_info("Starting cohort generation...")
  
  tryCatch({
    cm$createCohortTables()
    cm$executeCohortGeneration()
    counts <- cm$retrieveCohortCounts()
    
    cli::cli_alert_success("Cohort generation completed successfully!")
    cli::cli_rule("Cohort Counts")
    print(counts)
    cli::cli_rule()
    
    # Save cohort counts to output folder
    databaseName <- executionSettings$databaseName
    dbNameSnake <- snakecase::to_snake_case(databaseName)
    
    outputFolder <- fs::path(
      here::here("exec/results"),
      dbNameSnake,
      pipelineVersion,
      "00_buildCohorts"
    )
    
    # Create output folder if it doesn't exist
    if (!dir.exists(outputFolder)) {
      dir.create(outputFolder, recursive = TRUE, showWarnings = FALSE)
      cli::cli_alert_success("Created output folder: {fs::path_rel(outputFolder)}")
    }
    
    # Save cohort counts to CSV
    outputFile <- fs::path(outputFolder, "cohortCounts.csv")
    readr::write_csv(counts, file = outputFile)
    cli::cli_alert_success("Saved cohort counts to: {fs::path_rel(outputFile)}")
    
    return(invisible(counts))
  }, error = function(e) {
    cli::cli_alert_danger("Error during cohort generation: {e$message}")
    stop("Cohort generation failed")
  })
}



#' @title Function to execute a study task in Ulysses
#' @param taskFile the name of the taskFile. Only use the base name
#' @param configBlock the name of the configBlock to use in the execution
#' @param pipelineVersion the version of the pipeline to use in the execution. This is used to set the output folder for the task results. 
#'  the default is "dev" which will place results in a dev folder. This allows users to run and test tasks without impacting the main results folders organized by pipeline version.
#' @param checkStatus Logical. If TRUE, checks if task needs to be rerun
#'  based on file changes, dependencies, cohort changes, and previous errors. Automatically builds execution settings from configBlock.
#'  Default: FALSE
#' @param env the execution environment
#' @keywords internal
execute_task <- function(taskFile, configBlock, pipelineVersion = "dev",
                         checkStatus = FALSE,
                         env = rlang::caller_env()) {

  cli::cat_rule(glue::glue_col("Run Task: {yellow {taskFile}}"))
  cli::cat_bullet(
    glue::glue_col("Using config: {green {configBlock}}"),
    bullet = "info",
    bullet_col = "blue"
  )


  fullTaskFilePath <- fs::path("analysis/tasks", taskFile) |>
    fs::path_expand()

  # Verify task file exists
  if (!file.exists(fullTaskFilePath)) {
    cli::cli_alert_danger("Task file not found: {fs::path_rel(fullTaskFilePath)}")
    recordTaskExecution(taskFile, configBlock, pipelineVersion, "failed",
                        errorMessage = "Task file does not exist")
    stop("Task file does not exist")
  }

  # Check task status if requested
  if (checkStatus) {
    # Build execution settings from configBlock
    tryCatch({
      executionSettings <- createExecutionSettingsFromConfig(configBlock = configBlock)
    }, error = function(e) {
      cli::cli_alert_warning("Could not create execution settings for task status check: {e$message}")
      executionSettings <- NULL
    })
    
    if (!is.null(executionSettings)) {
      statusCheck <- shouldRerunTask(
        taskFile = fullTaskFilePath,
        configBlock = configBlock,
        executionSettings = executionSettings,
        pipelineVersion = pipelineVersion
      )

      if (!statusCheck$should_rerun) {
        cli::cli_alert_success("Task is up to date - skipping execution")
        recordTaskExecution(taskFile, configBlock, pipelineVersion, "skipped")
        return(invisible(NULL))
      }
    }
  }

  # Validate study task structure
  tryCatch({
    validateStudyTask(fullTaskFilePath)
  }, error = function(e) {
    cli::cli_alert_danger("Task validation failed: {e$message}")
    recordTaskExecution(taskFile, configBlock, pipelineVersion, "failed",
                        errorMessage = paste("Validation failed:", e$message))
    stop("Invalid task structure - cannot execute")
  })

  # Read and process the task file
  tryCatch({
    rLines <- readr::read_file(fullTaskFilePath) |>
      stringr::str_replace_all("\r\n", "\n") |>  # Convert CRLF to LF
      stringr::str_replace_all("\r", "\n") |>     # Convert any remaining CR to LF
      glue::glue(.open = "!||", .close = "||!")
  }, error = function(e) {
    cli::cli_alert_danger("Failed to read task file: {e$message}")
    recordTaskExecution(taskFile, configBlock, pipelineVersion, "failed",
                        errorMessage = paste("Read error:", e$message))
    stop("Error reading task file")
  })

  # Parse the expressions
  tryCatch({
    exprs <- rlang::parse_exprs(rLines)
  }, error = function(e) {
    cli::cli_alert_danger("Failed to parse task file: {e$message}")
    recordTaskExecution(taskFile, configBlock, pipelineVersion, "failed",
                        errorMessage = paste("Parse error:", e$message))
    stop("Error parsing task expressions")
  })

  # Execute each expression with error handling
  res <- NULL
  executionError <- NULL
  for (ex in seq_along(exprs)) {
    tryCatch({
      res <- eval(exprs[[ex]], env)
    }, error = function(e) {
      cli::cli_alert_danger("Error executing expression {ex} in task {taskFile}:")
      cli::cli_alert_danger("{e$message}")
      executionError <<- paste("Expression", ex, "failed:", e$message)
      stop(glue::glue("Task execution failed at expression {ex}"))
    })
    if (!is.null(executionError)) {
      break
    }
  }

  # Record success or failure
  if (!is.null(executionError)) {
    recordTaskExecution(taskFile, configBlock, pipelineVersion, "failed",
                        errorMessage = executionError)
    stop(executionError)
  } else {
    recordTaskExecution(taskFile, configBlock, pipelineVersion, "success")
    cli::cli_alert_success("Task {taskFile} completed successfully")
  }

  invisible(res)
}

#' @title Test a Single Study Task
#' @description Executes a single task in test mode using the "dev" pipeline version.
#'   Checks that you're not on main branch, then runs the task with checkStatus = TRUE.
#'   Useful for testing individual task changes before running full pipeline.
#' @param taskFile Character. The name of the task file (base name only, no path).
#' @param configBlock Character. The name of the config block to use.
#' @param env The execution environment. Defaults to caller environment.
#' @return Invisibly returns the task result
#' @export
#' @examples
#' \dontrun{
#' # Test a task on develop branch
#' testStudyTask("01_generate_cohorts.R", configBlock = "myConfig")
#' }
testStudyTask <- function(taskFile, configBlock, env = rlang::caller_env()) {
  checkmate::assert_string(taskFile, min.chars = 1)
  checkmate::assert_string(configBlock, min.chars = 1)
  
  # Check branch
  branch <- get_current_branch()
  if (branch == "main") {
    cli::cli_abort(c(
      "Cannot run test task on main branch!",
      "i" = "Switch to develop or a feature branch: {.code git checkout develop}"
    ))
  }
  
  cli::cli_rule("TEST Mode: Study Task")
  cli::cli_alert_warning("Testing on branch: {branch}")
  cli::cli_alert_info("Using DEV version for test run")
  
  execute_task(
    taskFile = taskFile,
    configBlock = configBlock,
    pipelineVersion = "dev",
    checkStatus = TRUE,
    env = env
  )
}

#' @title Core Pipeline Execution Logic
#' @description Internal function containing all pipeline execution logic.
#'   Called by both testStudyPipeline and execStudyPipeline with different parameters.
#' @param configBlock name of one or multiple configBlock to use in the execution
#' @param updateType the type of version increment: 'major', 'minor', or 'patch'. 
#'   Only used when testMode = FALSE.
#' @param testMode Logical. If TRUE, skips all validations and uses "dev" version.
#'   If FALSE, enforces code validation and version management. Default: FALSE
#' @param skipRenv Logical. If TRUE, skips renv validation. Default: FALSE
#' @param skipConnectivityCheck Logical. If TRUE (default), skips the optional
#'   database connectivity pre-flight check. Set to FALSE to attempt a test
#'   connection to each config block before execution begins.
#' @param env the execution environment
#' @return Invisibly returns task results list
#' @keywords internal
execute_pipeline <- function(configBlock, updateType = NULL, testMode = FALSE,
                             skipRenv = FALSE, skipConnectivityCheck = TRUE,
                             env = rlang::caller_env()) {
  
  # Compute prospective pipeline version (needed for pre-flight checks)
  if (testMode) {
    pipelineVersion <- "dev"
    currentVersion <- NULL
    incrementLabel <- NULL
  } else {
    # Validate updateType
    updateType <- tolower(trimws(updateType))
    if (!(updateType %in% c("major", "minor", "patch"))) {
      cli::cli_abort(c(
        "Invalid updateType: {.val {updateType}}",
        "i" = "Must be one of: major, minor, patch",
        "i" = "MAJOR - Breaking changes, MINOR - New features, PATCH - Bug fixes"
      ))
    }

    # Read current version from config.yml
    configPath <- fs::path(here::here(), "config.yml")
    configYml <- tryCatch(
      readr::read_lines(configPath),
      error = function(e) cli::cli_abort("Cannot read config.yml: {e$message}")
    )
    versionLine <- which(grepl("  version: ", configYml))
    if (length(versionLine) == 0) cli::cli_abort("Version not found in config.yml")
    currentVersion <- trimws(gsub(".*version:\\s*", "", configYml[versionLine[1]]))

    # Compute prospective new version
    versionParts <- as.integer(strsplit(currentVersion, "\\.")[[1]])

    if (updateType == "major") {
      versionParts[1] <- versionParts[1] + 1
      versionParts[2] <- 0
      versionParts[3] <- 0
      incrementLabel <- "MAJOR"
    } else if (updateType == "minor") {
      versionParts[2] <- versionParts[2] + 1
      versionParts[3] <- 0
      incrementLabel <- "MINOR"
    } else if (updateType == "patch") {
      versionParts[3] <- versionParts[3] + 1
      incrementLabel <- "PATCH"
    }

    pipelineVersion <- paste0(versionParts, collapse = ".")
  }

  # Run all pre-flight checks — consolidated banner before any execution
  preFlightResult <- runPreflightChecks(
    configBlock = configBlock,
    pipelineVersion = pipelineVersion,
    testMode = testMode,
    skipRenv = skipRenv,
    skipConnectivityCheck = skipConnectivityCheck,
    resultsPath = here::here("exec/results"),
    tasksFolderPath = here::here("analysis/tasks")
  )

  lockfileHash <- preFlightResult$lockfileHash
  taskFilesToRun <- preFlightResult$taskFilesToRun

  if (length(taskFilesToRun) == 0) {
    cli::cli_alert_warning("No task files found in analysis/tasks folder")
    return(invisible(NULL))
  }

  cli::cli_alert_info("Found {length(taskFilesToRun)} task(s) to execute")

  # Apply version increment to files (production only, after pre-flight passes)
  if (!testMode) {
    cli::cli_rule("Version Increment")
    cli::cli_alert_success("{incrementLabel} increment: {currentVersion} → {pipelineVersion}")
    cli::cli_alert_info("Updating version in config.yml...")
    tryCatch({
      updateStudyVersion(versionNumber = pipelineVersion)
    }, error = function(e) {
      cli::cli_alert_danger("Failed to apply version increment: {e$message}")
      stop("Version increment failed")
    })
  }
  
  # Create execution settings from first configBlock.
  # Forwarding pipelineVersion so that dev versions (non-semver) automatically
  # route cohort generation to the _dev table, leaving the production table untouched.
  tryCatch({
    executionSettings <- createExecutionSettingsFromConfig(
      configBlock = configBlock[1],
      pipelineVersion = pipelineVersion
    )
    cli::cli_alert_success("Execution settings created for config: {configBlock[1]}")
  }, error = function(e) {
    cli::cli_alert_danger("Failed to create execution settings: {e$message}")
    stop("Cannot initialize execution settings")
  })
  
  # Setup logging before generating cohorts
  logFilePath <- NULL
  tryCatch({
    logDir <- fs::path(here::here("exec/logs"))
    if (!dir.exists(logDir)) {
      dir.create(logDir, recursive = TRUE, showWarnings = FALSE)
      cli::cli_alert_success("Created logs directory: {fs::path_rel(logDir)}")
    }
    
    # Create log file with version and timestamp
    dateStamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    logFileName <- glue::glue("picard_log_{pipelineVersion}_{dateStamp}.txt")
    logFilePath <- fs::path(logDir, logFileName)
    
    cli::cli_alert_info("Logging pipeline execution to: {fs::path_rel(logFilePath)}")
    
    # Write header to log file
    logHeader <- c(
      "================================================================================",
      glue::glue("Picard Pipeline Execution Log"),
      glue::glue("Pipeline Version: {pipelineVersion}"), # add cohort version 
      glue::glue("Execution Start Time: {format(Sys.time(), '%Y-%m-%d %H:%M:%S')}"),
      glue::glue("Config Blocks: {paste(configBlock, collapse = ', ')}"),
      glue::glue("Update Type: {updateType}"),
      glue::glue("Tasks: {length(taskFilesToRun)}"),
      glue::glue("Test Mode: {testMode}"),
      "================================================================================",
      ""
    )
    
    writeLines(logHeader, con = logFilePath)
    
    # Setup sink for logging to capture all output
    sink(file = logFilePath, append = TRUE, type = "output")
    on.exit(sink(), add = TRUE)
    
    # Log to file that we're starting cohort generation
    cat(glue::glue("[{format(Sys.time(), '%H:%M:%S')}] Starting cohort generation...\n"), sep = "")
    
  }, error = function(e) {
    cli::cli_alert_warning("Failed to setup logging: {e$message}")
  })
  
  # Cohort manifest status and missing-cohort interactive prompt are handled
  # in runPreflightChecks() before pipeline execution begins.
  
  # Generate cohorts before running pipeline
  cli::cli_alert_info("Generating cohorts for pipeline...")
  
  tryCatch({
    generateCohorts(
      executionSettings = executionSettings,
      pipelineVersion = pipelineVersion,
      override = TRUE
    )
  }, error = function(e) {
    cli::cli_alert_danger("Cohort generation failed: {e$message}")
    stop("Pipeline cannot proceed without cohorts")
  })
  
  # Run all tasks across all config blocks
  cli::cli_rule("Running Pipeline Tasks")
  taskResults <- list()
  
  for (db in seq_along(configBlock)) {
    logMsg <- glue::glue("\n[{format(Sys.time(), '%H:%M:%S')}] Processing config block: {configBlock[db]}")
    cat(logMsg, "\n", sep = "")
    
    cli::cli_alert_info("Processing config block: {configBlock[db]}")
    
    for (task in seq_along(taskFilesToRun)) {
      taskName <- taskFilesToRun[task]
      taskKey <- glue::glue("{configBlock[db]}_{taskName}")
      
      taskLogMsg <- glue::glue("  [{format(Sys.time(), '%H:%M:%S')}] Executing task {task}/{length(taskFilesToRun)}: {taskName}")
      cat(taskLogMsg, "\n", sep = "")
      
      tryCatch({
        cli::cli_alert_info("Executing task {task}/{length(taskFilesToRun)}: {taskName}")
        
        result <- execute_task(
          taskFile = taskName,
          configBlock = configBlock[db],
          pipelineVersion = pipelineVersion,
          checkStatus = TRUE,
          env = env
        )
        
        successMsg <- glue::glue("  [{format(Sys.time(), '%H:%M:%S')}] ✓ Task completed successfully")
        cat(successMsg, "\n", sep = "")
        
        taskResults[[taskKey]] <- list(
          status = "success",
          result = result,
          timestamp = Sys.time()
        )
        
      }, error = function(e) {
        errorMsg <- glue::glue("  [{format(Sys.time(), '%H:%M:%S')}] ✗ Task failed with error: {e$message}")
        cat(errorMsg, "\n", sep = "")
        
        cli::cli_alert_danger("Task failed: {taskName}")
        cli::cli_alert_danger("Error: {e$message}")
        
        stop(glue::glue("Pipeline halted at task: {taskName}"))
      })
    }
  }
  
  # Close sink before summary
  if (!is.null(logFilePath)) {
    sink()
  }
  
  # Summary
  cli::cli_rule("Pipeline Execution Complete")
  successCount <- sum(sapply(taskResults, function(x) x$status == "success"))
  failureCount <- sum(sapply(taskResults, function(x) x$status == "failed"))
  
  cli::cli_alert_success("Successful tasks: {successCount}")
  if (failureCount > 0) {
    cli::cli_alert_warning("Failed tasks: {failureCount}")
  }
  
  cli::cli_alert_info("Pipeline version: {pipelineVersion}")
  cli::cli_rule()
  
  # Append summary to log file
  if (!is.null(logFilePath)) {
    summaryLines <- c(
      "",
      "================================================================================",
      "Pipeline Execution Summary",
      "================================================================================",
      glue::glue("Pipeline Version: {pipelineVersion}"),
      glue::glue("Completion Time: {format(Sys.time(), '%Y-%m-%d %H:%M:%S')}"),
      glue::glue("Successful Tasks: {successCount}"),
      glue::glue("Failed Tasks: {failureCount}"),
      glue::glue("Total Tasks: {length(taskResults)}"),
      glue::glue("Log File: {fs::path_rel(logFilePath)}"),
      glue::glue("Test Mode: {testMode}"),
      "================================================================================",
      ""
    )
    
    write(summaryLines, file = logFilePath, append = TRUE)
    cli::cli_alert_success("Pipeline log saved to: {fs::path_rel(logFilePath)}")
  }
  
  invisible(taskResults)
}

#' @title Test Study Pipeline
#' @description Executes the full study pipeline in test mode using the "dev" pipeline version.
#'   Skips all git validation, renv checks, and version management. Useful for iterative 
#'   testing during development.
#' @param configBlock Character or character vector. Name(s) of config block(s) to use.
#' @param env The execution environment. Defaults to caller environment.
#' @return Invisibly returns task results list
#' @export
#' @examples
#' \dontrun{
#' # Test full pipeline on develop branch
#' testStudyPipeline(configBlock = "myConfig")
#' }
testStudyPipeline <- function(configBlock, env = rlang::caller_env()) {
  checkmate::assert_character(configBlock, min.len = 1, any.missing = FALSE)
  
  # Check branch
  branch <- get_current_branch()
  if (branch == "main") {
    cli::cli_abort(c(
      "Cannot run test pipeline on main branch!",
      "i" = "Switch to develop or a feature branch: {.code git checkout develop}"
    ))
  }
  
  cli::cli_rule("TEST Mode: Study Pipeline")
  cli::cli_alert_warning("Testing on branch: {branch}")
  cli::cli_alert_info("Using DEV version for test run")
  
  execute_pipeline(
    configBlock = configBlock,
    testMode = TRUE,
    skipRenv = TRUE,
    env = env
  )
}

#' @title Production Study Pipeline Execution
#' @description Executes the full study pipeline in production mode with full validation,
#'   version management, and reproducibility tracking. Creates a release branch, runs
#'   the complete pipeline, provides PR instructions, and saves reference to PENDING_PR.md.
#' @param configBlock Character or character vector. Name(s) of config block(s) to use.
#' @param updateType Character. Type of version increment: 'major', 'minor', or 'patch'.
#'   - MAJOR: Breaking changes
#'   - MINOR: New features, backward compatible
#'   - PATCH: Bug fixes, no new features
#' @param skipRenv Logical. If TRUE, skips renv validation. Defaults to FALSE.
#'   Useful for testing issues. Default: FALSE
#' @param skipConnectivityCheck Logical. If TRUE (default), skips the optional
#'   database connectivity pre-flight check. Set to FALSE to attempt a test
#'   connection to each config block before execution begins.
#' @param env The execution environment. Defaults to caller environment.
#' @return Invisibly returns task results list
#' @export
#' @examples
#' \dontrun{
#' # Run production pipeline with patch version increment
#' execStudyPipeline(configBlock = "myConfig", updateType = "patch")
#' }
execStudyPipeline <- function(configBlock, updateType, skipRenv = FALSE,
                              skipConnectivityCheck = TRUE, env = rlang::caller_env()) {
  checkmate::assert_character(configBlock, min.len = 1, any.missing = FALSE)
  checkmate::assert_string(updateType, min.chars = 1)
  checkmate::assert_logical(skipRenv, len = 1)
  checkmate::assert_logical(skipConnectivityCheck, len = 1)
  
  # Check current branch
  branch <- get_current_branch()
  if (branch == "main") {
    cli::cli_abort(c(
      "Cannot run production pipeline on main branch!",
      "i" = "Production runs use release branches.",
      "i" = "Create/checkout: {.code git checkout develop}"
    ))
  }
  
  cli::cli_rule("PRODUCTION Mode: Study Pipeline")
  
  # Read current version to determine release branch name
  tryCatch({
    configPath <- fs::path(here::here(), "config.yml")
    configYml <- readr::read_lines(configPath)
    versionLine <- which(grepl("  version: ", configYml))
    
    if (length(versionLine) == 0) {
      cli::cli_alert_danger("Version not found in config.yml")
      stop("Cannot find version in config.yml")
    }
    
    currentVersionLine <- configYml[versionLine[1]]
    currentVersion <- gsub(".*version:\\s*", "", currentVersionLine)
    currentVersion <- trimws(currentVersion)
    
  }, error = function(e) {
    cli::cli_alert_danger("Failed to read version from config.yml: {e$message}")
    stop("Cannot read current version")
  })
  
  # Parse version and increment
  tryCatch({
    versionParts <- as.integer(strsplit(currentVersion, "\\.")[[1]])
    
    updateType <- tolower(trimws(updateType))
    if (!(updateType %in% c("major", "minor", "patch"))) {
      cli::cli_alert_danger("Invalid updateType: {updateType}")
      stop("updateType must be: major, minor, or patch")
    }
    
    if (updateType == "major") {
      versionParts[1] <- versionParts[1] + 1
      versionParts[2] <- 0
      versionParts[3] <- 0
    } else if (updateType == "minor") {
      versionParts[2] <- versionParts[2] + 1
      versionParts[3] <- 0
    } else if (updateType == "patch") {
      versionParts[3] <- versionParts[3] + 1
    }
    
    newVersion <- paste0(versionParts, collapse = ".")
    
  }, error = function(e) {
    cli::cli_alert_danger("Failed to calculate new version: {e$message}")
    stop("Version calculation failed")
  })
  
  # Create/checkout release branch
  releaseBranch <- glue::glue("release/{newVersion}")
  cli::cli_alert_info("Creating/checking out release branch: {.emph {releaseBranch}}")
  
  tryCatch({
    branch_exists <- gert::git_branch_exists(releaseBranch)
    
    if (!branch_exists) {
      gert::git_branch_create(branch = releaseBranch, checkout = TRUE)
      cli::cli_alert_success("Created and checked out: {.emph {releaseBranch}}")
    } else {
      gert::git_branch_checkout(branch = releaseBranch)
      cli::cli_alert_success("Checked out existing: {.emph {releaseBranch}}")
    }
  }, error = function(e) {
    cli::cli_abort("Failed to create/checkout release branch: {e$message}")
  })
  
  # Run pipeline in production mode
  cli::cli_alert_info("Running pipeline on release branch...")
  
  taskResults <- execute_pipeline(
    configBlock = configBlock,
    updateType = updateType,
    testMode = FALSE,
    skipRenv = skipRenv,
    skipConnectivityCheck = skipConnectivityCheck,
    env = env
  )
  
  # After successful execution, create PR metadata
  cli::cli_rule("Production Pipeline Complete")
  
  prMeta <- createPullRequest(
    branchName = releaseBranch,
    title = glue::glue("[Pipeline {newVersion}] {toupper(updateType)} release"),
    description = glue::glue(
      "Automated production pipeline run\n",
      "Version: {newVersion}\n",
      "Type: {toupper(updateType)}\n",
      "Config: {paste(configBlock, collapse = ', ')}"
    ),
    targetBranch = "main"
  )
  
  # Save PR reference file for manual PR creation
  save_pr_reference(prMeta)
  
  cli::cli_alert_success("Production run complete on {.emph {releaseBranch}}")
  cli::cli_alert_info("PR reference saved to: PENDING_PR.md")
  cli::cli_alert_info("Next: Review PENDING_PR.md, create PR in your Git provider, then run clearPendingPR()")
  
  invisible(taskResults)
}


addMainFile <- function(repoName, repoFolder, toolType, configBlocks, studyName) {
  repoPath <- fs::path(repoFolder, repoName) |>
    fs::path_expand()

  if (toolType == "dbms") {
    configBlocks <- paste0(configBlocks, collapse = "\", \"")

    mainR <- fs::path_package("picard", "templates/main.R") |>
      readr::read_file() |>
      glue::glue()

  }

  if (toolType == "external") {
    mainR <- fs::path_package("picard", "templates/main_simple.R") |>
      readr::read_file() |>
      glue::glue()
  }

  actionItem(glue::glue_col("Initialize Main Exec File: {green {fs::path(repoPath, 'main.R')}}"))
  readr::write_file(
    x = mainR,
    file = fs::path(repoPath, "main.R")
  )
  invisible(mainR)

}

#' @title Add Test Main File to Extras Folder
#' @description Creates test_main.R script in the extras folder for development iteration.
#'   This provides a testing variant of the production pipeline that uses testStudyPipeline().
#' @param repoName Character. Name of the repository.
#' @param repoFolder Character. Parent directory of the repository.
#' @param toolType Character. Tool type, either "dbms" or "external".
#' @param configBlocks List or Character vector. Database config blocks (from ExecOptions) or block names.
#' @param studyName Character. Name of the study.
#' @keywords internal
addTestMainFile <- function(repoName, repoFolder, toolType, configBlocks, studyName) {
  repoPath <- fs::path(repoFolder, repoName) |>
    fs::path_expand()
  
  extrasPath <- fs::path(repoPath, "extras")
  
  if (toolType == "dbms") {
    # Extract config block names if objects are passed
    if (!is.character(configBlocks)) {
      configBlocks <- purrr::map_chr(configBlocks, ~.x$configBlockName)
    }
    configBlocks <- paste0(configBlocks, collapse = "\", \"")
  } else {
    configBlocks <- ""
  }
  
  # Create extras directory
  fs::dir_create(extrasPath)
  
  # Read template and substitute using glue
  testMainR <- fs::path_package("picard", "templates/test_main.R") |>
    readr::read_file() |>
    glue::glue()
  
  actionItem(glue::glue_col("Initialize Test Main Exec File: {green {fs::path(extrasPath, 'test_main.R')}}"))
  readr::write_file(
    x = testMainR,
    file = fs::path(extrasPath, "test_main.R")
  )
  invisible(testMainR)
}

#' @title Save PR Reference Information
#' @description Internal function that writes PR metadata to PENDING_PR.md for manual PR creation.
#'   Saves branch name, target, title, and description for user reference.
#' @param prMeta List. PR metadata from createPullRequest()
#' @keywords internal
save_pr_reference <- function(prMeta) {
  tryCatch({
    prFilePath <- fs::path(here::here(), "PENDING_PR.md")
    
    # Create PR reference file content
    prContent <- c(
      "# Pending Pull Request",
      "",
      glue::glue("**Created:** {format(Sys.time(), '%Y-%m-%d %H:%M:%S')}"),
      "",
      "## PR Details",
      "",
      glue::glue("- **Source Branch:** `{prMeta$branch}`"),
      glue::glue("- **Target Branch:** `{prMeta$targetBranch}`"),
      "",
      "## Title",
      "",
      prMeta$title,
      "",
      "## Description",
      "",
      if (!is.null(prMeta$description)) prMeta$description else "No description provided",
      "",
      "---",
      "",
      "## Instructions",
      "",
      "1. Review the changes on the branch",
      "2. Create a new PR in your Git provider with the details above",
      "3. Ensure all checks pass",
      "4. Merge to main when ready",
      "5. Run `clearPendingPR()` to remove this file",
      ""
    )
    
    readr::write_lines(prContent, file = prFilePath)
    cli::cli_alert_success("Saved PR reference to: {fs::path_rel(prFilePath)}")
    
  }, error = function(e) {
    cli::cli_alert_warning("Failed to save PR reference: {e$message}")
  })
}

#' @title Clear Pending PR Reference
#' @description Removes the PENDING_PR.md file after PR has been created and merged.
#'   Safe to call even if file doesn't exist.
#' @return Logical. TRUE if file was deleted, FALSE if it didn't exist
#' @export
#' @examples
#' \dontrun{
#' # After merging PR to main
#' clearPendingPR()
#' }
clearPendingPR <- function() {
  prFilePath <- fs::path(here::here(), "PENDING_PR.md")
  
  if (file.exists(prFilePath)) {
    tryCatch({
      fs::file_delete(prFilePath)
      cli::cli_alert_success("Removed: PENDING_PR.md")
      return(invisible(TRUE))
    }, error = function(e) {
      cli::cli_alert_danger("Failed to remove PENDING_PR.md: {e$message}")
      return(invisible(FALSE))
    })
  } else {
    cli::cli_alert_info("PENDING_PR.md not found (nothing to clean up)")
    return(invisible(FALSE))
  }
}
