#' @title Set Ulysses Contributor
#' @importFrom rlang "%||%"
#' @param name the name of the contributor as a character string
#' @param email the email of the contributor as a character string
#' @param role the role of the contirbutor as a character string
#' @returns A ContributorLine R6 class with the contributor info
#' @export
setContributor <- function(name, email, role) {
  ContributorLine$new(name = name, email = email, role = role)
}

#' @title Make Study Meta for Ulysses
#' @param studyTitle the title of the study as a character string
#' @param therapeuticArea the TA as a character string
#' @param studyType the study type (typically characterization)
#' @param studyLinks a list of study links
#' @param studyTags a list of study tags
#' @returns A StudyMeta R6 class with the study meta
#' @export
makeStudyMeta <- function(studyTitle,
                          therapeuticArea,
                          studyType,
                          contributors,
                          studyLinks = NULL,
                          studyTags = NULL) {
  StudyMeta$new(
    studyTitle = studyTitle,
    therapeuticArea = therapeuticArea,
    studyType = studyType,
    contributors = contributors,
    studyLinks = studyLinks,
    studyTags = studyTags
  )
}
#' @title set the config block for a database
#' @param configBlockName the name of the config block
#' @param cdmDatabaseSchema the cdmDatabaseSchema specified as a character string
#' @param cohortTable a character string specifying the way you want to name your cohort table
#' @param databaseName the name of the database, typically uses the db name and id. For example optum_dod_202501
#' @param databaseLabel the labelling name of the database, typically a common name for a db. For example Optum DOD
#' @returns A StudyMeta R6 class with the study meta
#' @export
setDbConfigBlock <- function(configBlockName,
                             cdmDatabaseSchema,
                             cohortTable,
                             databaseName = NULL,
                             databaseLabel = NULL) {
  DbConfigBlock$new(
    configBlockName = configBlockName,
    cdmDatabaseSchema = cdmDatabaseSchema,
    cohortTable = cohortTable,
    databaseName = databaseName,
    databaseLabel = databaseLabel
  )
}

#' @title set the execOptions as placeholder.
#' @description use this function if there is not a dbms connection for the study such as using a proprietary tool for the analysis
#' @returns A ExecOptions R6 class with the execOptions
#' @export
placeHolderExecOptions <- function() {
  ExecOptions$new()
}


#' @title Make ExecOptions for Ulysses
#' @param dbms specify the dbms used in the exec options
#' @param workDatabaseSchema the name of the workDatabaseSchema as a character string, location in DB where user has write access
#' @param tempEmulationSchema he name of the tempEmulationSchema as a character strings
#' @param dbConnectionBlocks a list of DbConfigBlock R6 classes specifying the dbs to connect
#' @returns A ExecOptions R6 class with the execOptions
#' @export
makeExecOptions <- function(dbms,
                            workDatabaseSchema,
                            tempEmulationSchema = NULL,
                            dbConnectionBlocks) {
  ExecOptions$new(
    dbms = dbms,
    workDatabaseSchema = workDatabaseSchema,
    tempEmulationSchema = tempEmulationSchema,
    dbConnectionBlocks = dbConnectionBlocks
  )
}


#' @title Make Ulysses Study Settings
#' @param repoName the name of repo as a character string
#' @param repoFolder the folder path where the repo is stored in local as a character string
#' @param studyMeta a StudyMeta R6 class with the details describing the study
#' @param execOptions a ExecOptions R6 class with the execution details needed for the study
#' @param gitRemote a remote url used to clone and set remote git
#' @param renvLockFile file path to a renvLockFile file
#' @returns A UlyssesStudy R6 class with the ulysses study details to make
#' @export
makeUlyssesStudySettings <- function(repoName,
                                     repoFolder,
                                     toolType = c("dbms", "external"),
                                     studyMeta,
                                     execOptions = NULL,
                                     gitRemote = NULL,
                                     renvLockFile = NULL) {
  UlyssesStudy$new(
    repoName = repoName,
    repoFolder = repoFolder,
    toolType = toolType,
    studyMeta = studyMeta,
    execOptions = execOptions,
    gitRemote = gitRemote,
    renvLockFile = renvLockFile
  )
}

# Users can call initUlyssesRepo directly on UlyssesStudy object:
# ulyssesStudySettings$initUlyssesRepo(verbose = TRUE, openProject = FALSE)


#' @title
#' Create an ExecutionSettings object and set its attributes
#'
#' @param connectionDetails A DatabaseConnector connectionDetails object (optional if connection is specified)
#' @param connection A DatabaseConnector connection object (optional if connectionDetails is specified)
#' @param cdmDatabaseSchema The schema of the OMOP CDM database
#' @param workDatabaseSchema The schema to which results will be written
#' @param tempEmulationSchema Some database platforms like Oracle and Snowflake do not truly support temp tables. To emulate temp tables, provide a schema with write privileges where temp tables can be created.
#' @param cohortTable The name of the table where the cohort(s) are stored
#' @param databaseName A human-readable name for the OMOP CDM database
#'
#' @return An ExecutionSettings object
#' @export
createExecutionSettings <- function(connectionDetails,
                                    connection = NULL,
                                    cdmDatabaseSchema,
                                    workDatabaseSchema,
                                    tempEmulationSchema,
                                    cohortTable,
                                    databaseName) {
  ExecutionSettings$new(
    connectionDetails = connectionDetails,
    connection = connection,
    cdmDatabaseSchema = cdmDatabaseSchema,
    workDatabaseSchema = workDatabaseSchema,
    tempEmulationSchema = tempEmulationSchema,
    cohortTable = cohortTable,
    databaseName = databaseName
  )
}

#' @title Create ExecutionSettings from Config Block
#' @description Load database connection details and execution parameters from a config.yml file
#'   and create both connectionDetails and ExecutionSettings objects. Supports multiple DBMS types
#'   including Snowflake with connectionString, PostgreSQL with server/port, and others.
#' @param configBlock Character. The name of the config block to load (e.g., "optum_dod")
#' @param configFilePath Character. Path to the config.yml file. If NULL, looks for config.yml in the current directory.
#' @param cdmDatabaseSchema Character. The schema containing the OMOP CDM (overrides config value if provided)
#' @param workDatabaseSchema Character. The schema for writing results (overrides config value if provided)
#' @param tempEmulationSchema Character. Schema for temp table emulation (overrides config value if provided)
#' @param cohortTable Character. The name of the cohort table (overrides config value if provided)
#' @param databaseName Character. Human-readable database name (overrides config value if provided)
#'
#' @details
#' The config.yml file supports multiple DBMS connection styles:
#'
#' For Snowflake (using connectionString):
#' \preformatted{
#' optum_dod:
#'   dbms: snowflake
#'   connectionString: !expr Sys.getenv('dbConnectionString')
#'   user: !expr Sys.getenv('dbUser')
#'   password: !expr Sys.getenv('dbPassword')
#'   cdmDatabaseSchema: my_schema
#'   workDatabaseSchema: results_schema
#'   tempEmulationSchema: temp_schema
#'   cohortTable: cohort
#'   databaseName: Optum DOD
#' }
#'
#' For PostgreSQL (using server/port):
#' \preformatted{
#' database1:
#'   dbms: postgresql
#'   server: localhost
#'   port: 5432
#'   user: dbuser
#'   password: dbpass
#'   cdmDatabaseSchema: public
#'   workDatabaseSchema: results
#'   cohortTable: cohort
#'   databaseName: My Database
#' }
#'
#' The config package automatically evaluates !expr blocks using Sys.getenv() for environment variables.
#'
#' @return An ExecutionSettings object with populated connectionDetails
#' @export
createExecutionSettingsFromConfig <- function(
    configBlock,
    configFilePath = here::here("config.yml"),
    cdmDatabaseSchema = NULL,
    workDatabaseSchema = NULL,
    tempEmulationSchema = NULL,
    cohortTable = NULL,
    databaseName = NULL,
    pipelineVersion = "prod") {

  if (!file.exists(configFilePath)) {
    stop("Config file not found: ", configFilePath)
  }

  # Get the config block
  blockConfig <- tryCatch(
    config::get(config = configBlock, file = configFilePath),
    error = function(e) {
      stop("Config block '", configBlock, "' not found in ", configFilePath, "\n",
           "Error: ", e$message)
    }
  )

  # Extract database connection parameters
  dbms <- blockConfig$dbms
  if (is.null(dbms)) {
    stop("'dbms' not found in config block '", configBlock, "'")
  }

  # Prepare connectionDetails based on DBMS type
  connDetailsArgs <- list(dbms = dbms)

  # Handle Snowflake-specific connection (uses connectionString)
  if (tolower(dbms) == "snowflake") {
    connectionString <- blockConfig$connectionString
    if (is.null(connectionString)) {
      stop("'connectionString' not found in Snowflake config block '", configBlock, "'")
    }
    connDetailsArgs$connectionString <- connectionString
  } else {
    # Handle other DBMS types (server/port style)
    server <- blockConfig$server %||% NA
    port <- blockConfig$port %||% NA

    if (!is.na(server)) {
      connDetailsArgs$server <- server
    }
    if (!is.na(port)) {
      connDetailsArgs$port <- port
    }
  }

  # Add credentials (common to all DBMS)
  user <- blockConfig$user %||% NA
  password <- blockConfig$password %||% NA

  if (!is.na(user)) {
    connDetailsArgs$user <- user
  }
  if (!is.na(password)) {
    connDetailsArgs$password <- password
  }

  # Add optional extra settings
  extraSettings <- blockConfig$extraSettings %||% NULL
  if (!is.null(extraSettings)) {
    connDetailsArgs$extraSettings <- extraSettings
  }

  # Create connectionDetails using DatabaseConnector
  connectionDetails <- tryCatch(
    do.call(DatabaseConnector::createConnectionDetails, connDetailsArgs),
    error = function(e) {
      stop("Failed to create connectionDetails for '", configBlock, "': ", e$message)
    }
  )

  # Override with explicit parameters if provided, otherwise use config values
  if (is.null(cdmDatabaseSchema)) {
    cdmDatabaseSchema <- blockConfig$cdmDatabaseSchema %||% NA
  }
  if (is.null(workDatabaseSchema)) {
    workDatabaseSchema <- blockConfig$workDatabaseSchema %||% NA
  }
  if (is.null(tempEmulationSchema)) {
    tempEmulationSchema <- blockConfig$tempEmulationSchema %||% NA
  }
  if (is.null(cohortTable)) {
    cohortTable <- blockConfig$cohortTable %||% NA
  }
  if (is.null(databaseName)) {
    databaseName <- blockConfig$databaseName %||% NA
  }

  # Validate required fields
  if (is.na(cdmDatabaseSchema)) {
    stop("'cdmDatabaseSchema' not specified in config or as parameter")
  }
  if (is.na(workDatabaseSchema)) {
    stop("'workDatabaseSchema' not specified in config or as parameter")
  }
  if (is.na(cohortTable)) {
    stop("'cohortTable' not specified in config or as parameter")
  }

  # Route to dev cohort table for any non-semver pipeline version (e.g. "dev", "test").
  # Semantic versions ("1.0.0", "2.1.3") always use the production table from config.
  is_dev_version <- !grepl("^\\d+\.\\d+\.\\d+$", pipelineVersion)
  if (is_dev_version) {
    cohortTable <- paste0(cohortTable, "_dev")
    cli::cli_alert_info("Dev pipeline version ({pipelineVersion}) — cohort table set to: {.val {cohortTable}}")
  }

  # Create and return ExecutionSettings
  ExecutionSettings$new(
    connectionDetails = connectionDetails,
    connection = NULL,
    cdmDatabaseSchema = cdmDatabaseSchema,
    workDatabaseSchema = workDatabaseSchema,
    tempEmulationSchema = if (is.na(tempEmulationSchema)) NULL else tempEmulationSchema,
    cohortTable = cohortTable,
    databaseName = databaseName
  )
}

#' @title Set Output Folder for Task
#' @description Create an output folder for a specific task within the results directory, organized by database name and pipelineVersion.
#' @param executionSettings An ExecutionSettings object containing the databaseName attribute
#' @param pipelineVersion A character string specifying the pipelineVersion of the analysis (e.g., "0.0.1", "1.0.2")
#' @param taskName The name of the task for which to create the output folder
#' @param execPath The base path for results (default is "exec/results" within the project)
#' @return The path to the created output folder
#' @export
setOutputFolder <- function(executionSettings, pipelineVersion, taskName, execPath = here::here("exec/results")) {
  dbNameSnake <- snakecase::to_snake_case(executionSettings$databaseName)
  outputFolder <- fs::path(execPath, dbNameSnake, pipelineVersion, taskName) |>
    fs::dir_create()
  return(outputFolder)
}

#' @title Function initializing an R file for an analysis task
#' @param nameOfTask The name of the analysis task script
#' @param author the name of the person authoring the file. Defaults to template text if NULL
#' @param description a description of the analysis task. Defaults to template text if NULL
#' @param projectPath the path to the project
#' @param openFile toggle on whether the file should be opened
#' @export
makeTaskFile <- function(
    nameOfTask,
    author = NULL,
    description = NULL,
    projectPath = here::here(),
    openFile = TRUE) {

  analysisFolderPath <- fs::path(projectPath, "analysis/tasks")
  dirF <- fs::dir_ls(path = analysisFolderPath, type = "file")
  nFiles <- length(dirF) + 1
  numLead <- stringr::str_pad(nFiles, width = 2, side = "left", pad = "0")
  nameOfTask <- snakecase::to_snake_case(nameOfTask)
  newName <- glue::glue("{numLead}_{nameOfTask}")


  # glue items
  taskName <- glue::glue("{newName}.R")
  studyName <- config::get("projectName", file = fs::path(projectPath, "config.yml"))
  if (is.null(author)) {
    author <- "ADD AUTHOR NAME HERE"
  }
  if (is.null(description)) {
    description <- "The purpose of this script is to....."
  }

  taskTemplate <- fs::path_package(
    package = "picard",
    "templates/task.R"
  ) |>
    readr::read_file() |>
    glue::glue(
      taskName = newName,
      author = author,
      description = description,
      studyName = studyName
    )


  txt <- glue::glue_col("Write {cyan {taskName}} to {yellow {analysisFolderPath}}")
  cli::cat_bullet(
    txt,
    bullet = "tick",
    bullet_col = "green"
  )

  # write the new file to analysis/task
  readr::write_file(
    x = taskTemplate,
    file = fs::path(analysisFolderPath, newName, ext = "R")
  )

  if (openFile) {
    rstudioapi::navigateToFile(file = fs::path(analysisFolderPath, newName, ext = "R"))
    cli::cat_bullet(
      "Navigating to new task file",
      bullet = "info",
      bullet_col = "blue"
    )
  }

  invisible(taskTemplate)

}

#' @title Create a Source Utility File
#' @description Creates a new R script in the analysis/src folder for storing reusable utility functions.
#'   Unlike task files, source files have no naming conventions or execution order requirements.
#' @param fileName The name of the source file (e.g., "custom_analysis_functions")
#' @param author The name of the author. Defaults to template text if NULL
#' @param description A brief description of what the utilities in this file do. Defaults to template text if NULL
#' @param projectPath The path to the project (defaults to current project)
#' @param openFile Whether to open the file after creating it (default TRUE)
#' @return Invisible character string containing the template content
#' @details Source files are utility files that contain reusable functions sourced by one or more task files.
#'   They have no naming convention requirements and execute in no particular order.
#'   Create them as you need utility functions to avoid code duplication across tasks.
#' @export
#' @examples
#' \dontrun{
#' # Create a source file for custom analysis functions
#' makeSrcFile(
#'   fileName = "custom_analysis_functions",
#'   author = "Jane Doe",
#'   description = "Helper functions for cohort calculations and data validation"
#' )
#'
#' # Create with minimal arguments (uses template defaults)
#' makeSrcFile(fileName = "plotting_utilities")
#' }
makeSrcFile <- function(
    fileName,
    author = NULL,
    description = NULL,
    projectPath = here::here(),
    openFile = TRUE) {

  srcFolderPath <- fs::path(projectPath, "analysis/src")

  # Ensure src directory exists
  fs::dir_create(srcFolderPath, recurse = TRUE)

  # Clean up filename
  fileName <- snakecase::to_snake_case(fileName)

  # Set defaults
  if (is.null(author)) {
    author <- "ADD AUTHOR NAME HERE"
  }
  if (is.null(description)) {
    description <- "Reusable utility functions"
  }

  # Get study name from config
  studyName <- config::get("projectName", file = fs::path(projectPath, "config.yml"))

  # Read and populate template
  srcTemplate <- fs::path_package(
    package = "picard",
    "templates/src.R"
  ) |>
    readr::read_file() |>
    glue::glue(
      fileName = fileName,
      author = author,
      description = description,
      studyName = studyName,
      .open = "<<",
      .close = ">>"
    )

  # Display message
  txt <- glue::glue_col("Write {cyan {fileName}.R} to {yellow {srcFolderPath}}")
  cli::cat_bullet(
    txt,
    bullet = "tick",
    bullet_col = "green"
  )

  # Write the file
  readr::write_file(
    x = srcTemplate,
    file = fs::path(srcFolderPath, fileName, ext = "R")
  )

  if (openFile) {
    rstudioapi::navigateToFile(file = fs::path(srcFolderPath, fileName, ext = "R"))
    cli::cat_bullet(
      "Navigating to new source file",
      bullet = "info",
      bullet_col = "blue"
    )
  }

  invisible(srcTemplate)

}

#' @title Create a SqlRender SQL File
#' @description Creates a new SQL script in the analysis/src/sql folder for storing parameterized OMOP queries.
#'   These files are rendered using SqlRender and executed against the CDM.
#' @param fileName The name of the SQL file (e.g., "condition_occurrence_query")
#' @param author The name of the author. Defaults to template text if NULL
#' @param description A brief description of what this query does. Defaults to template text if NULL
#' @param projectPath The path to the project (defaults to current project)
#' @param openFile Whether to open the file after creating it (default TRUE)
#' @return Invisible character string containing the template content
#' @details SQL files in src/sql are parameterized queries meant to be rendered with SqlRender::render()
#'   before execution. They should use @ notation for parameters (e.g., @cdmDatabaseSchema).
#'   Document all parameters used in your query with comments at the top of the file.
#' @export
#' @examples
#' \dontrun{
#' # Create a SQL query for analyzing condition_occurrence
#' makeSrcSqlFile(
#'   fileName = "condition_occurrence_counts",
#'   author = "Jane Doe",
#'   description = "Count conditions by month in the CDM"
#' )
#'
#' # Create with minimal arguments
#' makeSrcSqlFile(fileName = "get_person_demographics")
#' }
makeSrcSqlFile <- function(
    fileName,
    author = NULL,
    description = NULL,
    projectPath = here::here(),
    openFile = TRUE) {

  sqlFolderPath <- fs::path(projectPath, "analysis/src/sql")

  # Ensure sql directory exists
  fs::dir_create(sqlFolderPath, recurse = TRUE)

  # Clean up filename
  fileName <- snakecase::to_snake_case(fileName)

  # Set defaults
  if (is.null(author)) {
    author <- "ADD AUTHOR NAME HERE"
  }
  if (is.null(description)) {
    description <- "SqlRender parameterized query"
  }

  # Get study name from config
  studyName <- config::get("projectName", file = fs::path(projectPath, "config.yml"))

  # Read and populate template
  sqlTemplate <- fs::path_package(
    package = "picard",
    "templates/src_sql.sql"
  ) |>
    readr::read_file() |>
    glue::glue(
      fileName = fileName,
      author = author,
      description = description,
      studyName = studyName
    )

  # Display message
  txt <- glue::glue_col("Write {cyan {fileName}.sql} to {yellow {sqlFolderPath}}")
  cli::cat_bullet(
    txt,
    bullet = "tick",
    bullet_col = "green"
  )

  # Write the file
  readr::write_file(
    x = sqlTemplate,
    file = fs::path(sqlFolderPath, fileName, ext = "sql")
  )

  if (openFile) {
    rstudioapi::navigateToFile(file = fs::path(sqlFolderPath, fileName, ext = "sql"))
    cli::cat_bullet(
      "Navigating to new SQL file",
      bullet = "info",
      bullet_col = "blue"
    )
  }

  invisible(sqlTemplate)

}

#' Generate Print-Friendly Cohort Documentation from JSON
#' @description Converts CIRCE-based JSON cohort definitions to human-readable R Markdown files
#'   using CirceR print-friendly formatting. Preserves category subdirectories (e.g., target/, comparator/)
#'   in output structure.
#' @param cohorts_dir Character. Path to cohorts folder containing json/ subdirectory.
#'   Default: "inputs/cohorts" (Ulysses standard structure)
#' @param output_base Character. Path to base output directory where printFriendly/ subdirectory
#'   will be created. Default: "AI_translation" (created at repo root, separate from inputs/)
#' @param verbose Logical. Print progress messages. Default: TRUE
#' @return Invisibly returns character vector of generated file paths
#' @details
#' Input folder structure expected:
#' ```
#' inputs/cohorts/
#'   └── json/
#'       ├── target/
#'       │   ├── cohort1.json
#'       │   └── cohort2.json
#'       └── comparator/
#'           └── cohort3.json
#' ```
#'
#' Output folder structure created:
#' ```
#' AI_translation/
#'   └── printFriendly/
#'       ├── target/
#'       │   ├── cohort1 - cohort_print_friendly.Rmd
#'       │   └── cohort2 - cohort_print_friendly.Rmd
#'       └── comparator/
#'           └── cohort3 - cohort_print_friendly.Rmd
#' ```
#'
#' Each generated Rmd file contains a human-readable specification of the cohort definition
#' suitable for publication or documentation. CirceR must be installed.
#' @export
#' @examples
#' \dontrun{
#'   # Generate print-friendly files with defaults
#'   makePrintFriendlyFile()
#'
#'   # Custom locations
#'   makePrintFriendlyFile(
#'     cohorts_dir = "path/to/cohorts",
#'     output_base = "path/to/output"
#'   )
#' }
makePrintFriendlyFile <- function(cohorts_dir = "inputs/cohorts",
                                  output_base = "AI_translation",
                                  verbose = TRUE) {

  # Set up paths
  json_dir <- file.path(cohorts_dir, "json")
  output_dir <- file.path(output_base, "printFriendly")

  # Validate input directory
  if (!dir.exists(json_dir)) {
    cli::cli_abort("json_dir not found: {json_dir}")
  }

  # Check CirceR is available
  if (!requireNamespace("CirceR", quietly = TRUE)) {
    cli::cli_abort(
      "Package 'CirceR' is required.",
      "i" = "Install with: remotes::install_github('ohdsi/CirceR')"
    )
  }

  # Find all JSON files
  json_paths <- list.files(json_dir, pattern = "\\.json$", full.names = TRUE, recursive = TRUE)

  if (length(json_paths) == 0) {
    cli::cli_abort("No .json files found in {json_dir}")
  }

  if (verbose) {
    cli::cli_alert_info("Found {length(json_paths)} JSON file(s) to process")
  }

  # Process each JSON file
  output_files <- character()

  for (json_path in json_paths) {
    cohort_basename <- tools::file_path_sans_ext(basename(json_path))

    # Preserve category subfolder structure (e.g., target/, comparator/)
    rel_dir <- dirname(sub(
      paste0("^", normalizePath(json_dir), "/?"),
      "",
      normalizePath(json_path)
    ))

    category_out_dir <- if (rel_dir == ".") output_dir else file.path(output_dir, rel_dir)

    # Create output directory if needed
    if (!dir.exists(category_out_dir)) {
      dir.create(category_out_dir, recursive = TRUE)
      if (verbose) {
        cli::cli_alert_success("Created: {fs::path_rel(category_out_dir)}")
      }
    }

    # Convert JSON to print-friendly Rmd
    tryCatch(
      {
        json_text <- paste(readLines(json_path, warn = FALSE), collapse = "\n")
        cohort_def <- CirceR::cohortExpressionFromJson(json_text)
        rmd_content <- CirceR::cohortPrintFriendly(cohort_def)

        # Write output file
        out_rmd <- file.path(category_out_dir, paste0(cohort_basename, " - cohort_print_friendly.Rmd"))
        writeLines(rmd_content, out_rmd)
        output_files <- c(output_files, out_rmd)

        if (verbose) {
          cli::cli_alert_success("Wrote: {fs::path_rel(out_rmd)}")
        }
      },
      error = function(e) {
        cli::cli_alert_danger("Error processing {basename(json_path)}: {e$message}")
      }
    )
  }

  # Summary
  if (verbose) {
    cli::cli_alert_success("Generated {length(output_files)} print-friendly Rmd file(s)")
    cli::cli_alert_info("Output location: {fs::path_rel(output_dir)}")
  }

  invisible(output_files)
}


#' @title Initialize or Restore Agent Mode for Cloned Repository
#' @description When a Picard repository is cloned, agent mode files (.gitignored) won't be present.
#'   This function checks if agent mode is available and restores it using metadata from existing repo files.
#'   Agent mode provides VS Code Copilot with study context through copilot-instructions.md and reference docs.
#'
#' @param projectPath Character. Path to the Picard repository. Defaults to current working directory.
#' @param verbose Logical. Display informative messages during initialization. Default: TRUE
#'
#' @return Invisibly returns a list with:
#'   - `agent_mode_active`: Logical. TRUE if agent mode files are now available
#'   - `files_created`: Character vector of files that were created/restored
#'   - `already_existed`: Logical. TRUE if agent mode files already existed
#'
#' @details
#' Agent mode setup consists of:
#' - `.agent/` folder with reference documentation
#' - `copilot-instructions.md` at workspace root (auto-loaded by VS Code Copilot)
#' - `.agent/copilot-instructions.md` (backup/reference)
#'
#' Study metadata is extracted from existing repo files:
#' - Study title and project name from README.md
#' - Tool type from config.yml
#' - Repository name from the repo folder name
#'
#' @export
#' @examples
#' \dontrun{
#'   # Restore agent mode in current repository
#'   initAgentMode()
#'
#'   # Restore in specific repository
#'   initAgentMode(projectPath = "/path/to/study_repo")
#' }
initAgentMode <- function(projectPath = here::here(), verbose = TRUE) {
  projectPath <- fs::path_expand(projectPath)
  repoPath <- projectPath

  if (verbose) cli::cli_h2("Initializing Agent Mode Configuration")

  # Check if agent mode already exists
  agent_folder <- fs::path(repoPath, ".agent")
  root_instructions <- fs::path(repoPath, "copilot-instructions.md")
  reference_docs_folder <- fs::path(agent_folder, "reference-docs")

  agent_mode_exists <- fs::dir_exists(agent_folder) &&
    fs::file_exists(root_instructions) &&
    fs::dir_exists(reference_docs_folder)

  if (agent_mode_exists) {
    if (verbose) cli::cli_alert_info("Agent mode already initialized")
    ll <- list(
      agent_mode_active = TRUE,
      files_created = character(0),
      already_existed = TRUE
    )
    return(ll)
  }

  if (verbose) cli::cli_inform("Agent mode not found. Restoring from package templates...")

  tryCatch({
    # Extract study metadata from repository
    if (verbose) cli::cli_inform("Extracting study metadata from repository...")

    # Get repository name from folder
    repoName <- basename(repoPath)

    # Extract from README.md
    readme_path <- fs::path(repoPath, "README.md")
    if (!fs::file_exists(readme_path)) {
      cli::cli_alert_warning("README.md not found. Using defaults for study metadata.")
      studyName <- repoName
      projectName <- repoName
    } else {
      readme_content <- readr::read_file(readme_path)

      # Try to extract study title from "Study Title:" field
      study_title_match <- stringr::str_match(
        readme_content,
        "Study Title:\\s*([^\n]+)"
      )
      studyName <- if (!is.na(study_title_match[1, 2])) {
        stringr::str_trim(study_title_match[1, 2])
      } else {
        repoName
      }

      # Use project name if available, otherwise use repoName
      projectName <- repoName
    }

    # Extract toolType from config.yml
    config_path <- fs::path(repoPath, "config.yml")
    if (!fs::file_exists(config_path)) {
      cli::cli_alert_warning("config.yml not found. Using 'dbms' as default toolType.")
      toolType <- "dbms"
    } else {
      toolType <- tryCatch(
        {
          # Try to extract toolType if it exists, otherwise default to checking database blocks
          config_content <- readr::read_file(config_path)
          if (grepl("database:", config_content)) {
            "dbms"
          } else {
            "external"
          }
        },
        error = function(e) {
          cli::cli_alert_warning("Could not parse config.yml. Using 'dbms' as default.")
          "dbms"
        }
      )
    }

    databaseLabel <- "Database"

    if (verbose) {
      cli::cli_inform(c(
        "Extracted metadata:",
        "  Repository: {repoName}",
        "  Study: {studyName}",
        "  Project: {projectName}",
        "  Tool Type: {toolType}"
      ))
    }

    # Create .agent folder
    fs::dir_create(agent_folder)

    # Read and substitute copilot-instructions.md template
    if (verbose) cli::cli_inform("Copying and customizing instructions template...")
    instructions_template <- fs::path_package("picard", "agent/copilot-instructions.md") |>
      readr::read_file()

    instructions_content <- glue::glue(instructions_template, .open = "{{", .close = "}}")

    # Write to .agent folder for reference
    instructions_file <- fs::path(agent_folder, "copilot-instructions.md")
    readr::write_file(x = instructions_content, file = instructions_file)
    cli::cli_alert_success("Created {.file {fs::path_rel(instructions_file)}}")

    # Write to workspace root so Copilot automatically picks it up
    root_instructions_file <- fs::path(repoPath, "copilot-instructions.md")
    readr::write_file(x = instructions_content, file = root_instructions_file)
    cli::cli_alert_success("Created {.file {fs::path_rel(root_instructions_file)}} (workspace root)")

    # Copy reference documentation files
    if (verbose) cli::cli_inform("Copying reference documentation...")
    fs::dir_create(reference_docs_folder)

    # Get list of reference files from inst/agent
    agent_package_folder <- fs::path_package("picard", "agent")

    # List all markdown files and filter for numbered ones
    all_files <- fs::dir_ls(agent_package_folder, type = "file", recurse = FALSE)
    reference_files <- all_files[grepl("^\\d{2}-.*\\.md$", fs::path_file(all_files))]

    # Copy each reference file
    if (length(reference_files) > 0) {
      purrr::walk(reference_files, function(ref_file) {
        base_name <- fs::path_file(ref_file)
        dest_file <- fs::path(reference_docs_folder, base_name)
        fs::file_copy(ref_file, dest_file, overwrite = TRUE)
      })
      cli::cli_alert_success(
        "Copied {length(reference_files)} reference documents to {.file {fs::path_rel(reference_docs_folder)}}"
      )
    } else {
      cli::cli_alert_warning("No numbered reference documentation files found in agent package")
    }

    if (verbose) cli::cli_alert_success("Agent mode successfully initialized")

    files_created <- c(
      "copilot-instructions.md",
      ".agent/copilot-instructions.md",
      paste0(".agent/reference-docs/", fs::path_file(reference_files))
    )

    invisible(list(
      agent_mode_active = TRUE,
      files_created = files_created,
      already_existed = FALSE
    ))
  }, error = function(e) {
    cli::cli_alert_danger("Failed to initialize agent mode: {e$message}")
    stop(e)
  })
}
