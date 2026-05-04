#' Initialize a New Cohort Manifest
#'
#' Creates a blank `cohortManifest.sqlite` database with the new schema.
#' Directory creation (`json/`, `sql/`, `derived/`) is handled by the study repo
#' initialization (see `listDefaultFolders()` in `R/Ulysses.R`).
#'
#' @param path Character. Path to the cohorts folder where the SQLite file will be created.
#'   Defaults to `"inputs/cohorts"`.
#'
#' @return A `CohortManifest` R6 object (empty, ready for `$add*()` calls).
#'
#' @export
initCohortManifest <- function(path = "inputs/cohorts") {
  dbPath <- fs::path(path, "cohortManifest.sqlite")

  if (file.exists(dbPath)) {
    cli::cli_alert_warning("Manifest already exists at {fs::path_rel(dbPath)}.")
    cli::cli_alert_info("Use loadCohortManifest() to load the existing manifest.")
    cli::cli_alert_info("Use resetCohortManifest() to delete and start fresh.")
    return(invisible(NULL))
  }

  # Ensure directory exists

  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }

  cm <- CohortManifest$new(dbPath = dbPath)
  cli::cli_alert_success("Initialized empty cohort manifest at {fs::path_rel(dbPath)}")
  cli::cli_alert_info("Add cohorts with $addAtlasCohort(), $addCaprCohort(), $addSqlCohort(), or $importAtlasCohorts()")

  return(cm)
}


#' Load Cohort Manifest from SQLite Database
#'
#' Loads a CohortManifest R6 object from an existing `cohortManifest.sqlite` database.
#' This is a pure read from SQLite — it does not scan directories or auto-add new files.
#' If new files exist on disk that aren't in the manifest, a warning is printed
#' suggesting the appropriate `$add*()` method.
#'
#' @param cohortsFolderPath Character. Path to the cohorts folder containing the manifest
#'   database. Defaults to `here::here("inputs/cohorts")`.
#' @param executionSettings An ExecutionSettings object containing database configuration
#'   for cohort generation. Optional; can be added later using `$setExecutionSettings()`.
#' @param verbose Logical. If TRUE, prints informative messages. Defaults to TRUE.
#'
#' @return A CohortManifest R6 object.
#'
#' @details
#' If no SQLite database exists at the expected path, the function stops with an
#' error directing the user to `initCohortManifest()`.
#'
#' After loading, the function checks for new files in `json/`, `sql/`, and `derived/`
#' directories that are not tracked in the manifest. These are reported as warnings
#' but NOT auto-added (because `category` is required and cannot be guessed).
#'
#' @export
loadCohortManifest <- function(cohortsFolderPath = here::here("inputs/cohorts"),
                               executionSettings = NULL,
                               verbose = TRUE) {
  dbPath <- fs::path(cohortsFolderPath, "cohortManifest.sqlite")

  # Require existing database
  if (!file.exists(dbPath)) {
    cli::cli_abort(c(
      "Cohort manifest not found at {.path {fs::path_rel(dbPath)}}.",
      "i" = "Use {.code initCohortManifest()} to create a new manifest.",
      "i" = "Use {.code migrateCohortManifest()} if upgrading from picard <= 0.0.3."
    ))
  }

  # Load manifest from SQLite
  cm <- CohortManifest$new(dbPath = dbPath)

  # Attach execution settings if provided
  if (!is.null(executionSettings)) {
    cm$setExecutionSettings(executionSettings)
  }

  if (verbose) {
    n_cohorts <- length(cm$getManifest())
    cli::cli_alert_success("Loaded cohort manifest: {n_cohorts} active cohort(s)")
  }

  # Check for untracked files on disk
  if (verbose) {
    .warn_untracked_files(cohortsFolderPath, cm)
  }

  return(cm)
}


#' @noRd
.warn_untracked_files <- function(cohortsFolderPath, cm) {
  # Get file paths from manifest
  manifest_files <- vapply(cm$getManifest(), function(cd) cd$getFilePath(), character(1))


  # Scan directories for all cohort files
  json_dir <- fs::path(cohortsFolderPath, "json")
  sql_dir <- fs::path(cohortsFolderPath, "sql")
  derived_dir <- fs::path(cohortsFolderPath, "derived")

  all_files <- character(0)
  if (dir.exists(json_dir)) {
    all_files <- c(all_files, list.files(json_dir, pattern = "\\.(json|sql)$", full.names = TRUE, recursive = TRUE))
  }
  if (dir.exists(sql_dir)) {
    all_files <- c(all_files, list.files(sql_dir, pattern = "\\.sql$", full.names = TRUE, recursive = TRUE))
  }
  if (dir.exists(derived_dir)) {
    all_files <- c(all_files, list.files(derived_dir, pattern = "\\.sql$", full.names = TRUE, recursive = TRUE))
  }

  # Compare (using relative paths)
  all_files_rel <- fs::path_rel(all_files)
  untracked <- all_files_rel[!all_files_rel %in% manifest_files]

  if (length(untracked) > 0) {
    cli::cli_alert_warning("{length(untracked)} file(s) on disk not in manifest:")
    for (f in utils::head(untracked, 5)) {
      cli::cli_bullets(c("!" = "{f}"))
    }
    if (length(untracked) > 5) {
      cli::cli_bullets(c("!" = "... and {length(untracked) - 5} more"))
    }
    cli::cli_alert_info("Use $addAtlasCohort(), $addSqlCohort(), or $importAtlasCohorts() to register them.")
  }
}

#' Reset Cohort Manifest Database
#'
#' Deletes the cohortManifest.sqlite database file. Use this function when you need
#' to reset the manifest and rebuild it from the available cohort files.
#'
#' @param cohortsFolderPath Character. Path to the cohorts folder containing the manifest
#'   database. Defaults to "inputs/cohorts".
#'
#' @return Invisibly returns NULL. Deletes the manifest file and prints status messages.
#'
#' @details
#' This function is useful for:
#' - Starting fresh with a new set of cohorts
#' - Clearing cached manifest data
#' - Resolving manifest corruption issues
#'
#' After resetting, call [loadCohortManifest()] to rebuild the manifest from
#' the available cohort files in the json/ and sql/ subdirectories.
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   # Reset the manifest
#'   resetCohortManifest()
#'
#'   # Rebuild it (with or without settings)
#'   manifest <- loadCohortManifest()
#' }
#'
resetCohortManifest <- function(cohortsFolderPath = here::here("inputs/cohorts")) {
  dbPath <- fs::path(cohortsFolderPath, "cohortManifest.sqlite")

  if (file.exists(dbPath)) {
    file.remove(dbPath)
    cli::cli_alert_success("Cohort manifest database deleted: {fs::path_rel(dbPath)}")
    cli::cli_alert_info("To rebuild the manifest, call loadCohortManifest() with your ExecutionSettings")
  } else {
    cli::cli_alert_warning("Cohort manifest database not found at: {fs::path_rel(dbPath)}")
  }

  invisible(NULL)
}



#' Create Blank Cohorts Load File
#'
#' Creates a blank cohortsLoad.csv template file in the specified folder
#' with proper column structure. Users can fill this file manually in Excel,
#' Google Sheets, or any text editor, then place it in the inputs/cohorts folder.
#'
#' @param cohortsFolderPath Character. Path where the blank file will be created.
#'   Defaults to "inputs/cohorts". Creates the folder if it doesn't exist.
#'
#' @return Invisibly returns the file path. Prints informative messages with tips.
#'
#' @details
#' **Column Guide:**
#' - `atlasId` (numeric): The ATLAS cohort ID. Get this from ATLAS > Cohort Definitions
#' - `label` (character): Display name for your cohort (e.g., "Type 2 Diabetes patients")
#' - `category` (character): Broad grouping category (e.g., "Disease Populations", "Treatment Groups")
#' - `subCategory` (character): Optional sub-grouping within category
#' - `file_name` (character): Path to JSON file (e.g., "json/t2dm_patients.json"). Note this is a placeholder will be replaced when you import from ATLAS.
#'
#' **Tips for Filling Out:**
#' 1. Each row represents one cohort
#' 2. Use forward slashes (/) in file paths
#' 3. Ensure file_name matches the JSON files you'll import from ATLAS
#' 4. Logical sub-grouping in category/subCategory helps with organization
#' 5. Save as UTF-8 CSV when exporting from Excel to avoid encoding issues
#'
#' **Workflow:**
#' 1. Call this function to create blank template
#' 2. Open cohortsLoad.csv in your preferred spreadsheet application
#' 3. Fill in your cohort metadata
#' 4. Save the file
#' 5. Use [importAtlasCohorts()] to import the actual JSON definitions from ATLAS
#' 6. Use [loadCohortManifest()] to load into your study
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   # Create blank template in default location
#'   createBlankCohortsLoadFile()
#'   # File created at: inputs/cohorts/cohortsLoad.csv
#' }
#'
createBlankCohortsLoadFile <- function(cohortsFolderPath = here::here("inputs/cohorts")) {
  checkmate::assert_string(cohortsFolderPath)
  
  # Create directory if it doesn't exist
  fs::dir_create(cohortsFolderPath)
  
  # Create blank template with proper structure
  template <- data.frame(
    atlasId = integer(1),
    label = character(1),
    category = character(1),
    subCategory = character(1),
    file_name = character(1),
    stringsAsFactors = FALSE
  )
  
  file_path <- fs::path(cohortsFolderPath, "cohortsLoad.csv")
  readr::write_csv(template, file = file_path)
  
  # Print informative messages
  cli::cli_rule("Blank Cohorts Load File Created")
  cli::cli_text("File created at: {.file {fs::path_rel(file_path)}}")
  cli::cli_text("")
  cli::cli_h3("Column Guide:")
  cli::cli_ul(c(
    "{.field atlasId} - ATLAS cohort ID (numeric)",
    "{.field label} - Display name (e.g., 'Type 2 Diabetes patients')",
    "{.field category} - Broad category (e.g., 'Disease Populations')",
    "{.field subCategory} - Optional sub-grouping",
    "{.field file_name} - Path to JSON file (e.g., 'json/t2dm_patients.json'). Note this is a placeholder will be replaced when you import from ATLAS."
  ))
  cli::cli_text("")
  cli::cli_h3("Tips for Filling Out:")
  cli::cli_ul(c(
    "Each row = one cohort",
    "Use forward slashes (/) in file paths",
    "Logical grouping helps with organization and querying",
    "Save as UTF-8 CSV from Excel to avoid encoding issues"
  ))
  cli::cli_text("")
  cli::cli_h3("Next Steps:")
  cli::cli_ol(c(
    "Open {.file inputs/cohorts/cohortsLoad.csv} in Excel or your text editor",
    "Fill in your cohort metadata",
    "Save the file",
    "Use {.code importAtlasCohorts()} to import JSON definitions from ATLAS",
    "Use {.code loadCohortManifest()} to load into your study"
  ))
  
  invisible(file_path)
}


#' Function to parse tags string from database into a named list
#' @keywords internal
#'
#' @param tags_str Character. Tags string in format "name: value | name: value"
#'
#' @return List. Named list of tags
#'
parseTagsString <- function(tags_str) {
  if (is.na(tags_str) || tags_str == "") {
    return(list())
  }

  # Split by pipe separator
  tag_pairs <- strsplit(tags_str, " \\| ")[[1]]

  # Parse each pair
  tags_list <- list()
  for (pair in tag_pairs) {
    parts <- strsplit(pair, ":\\s*")[[1]]
    if (length(parts) == 2) {
      tag_name <- trimws(parts[1])
      tag_value <- trimws(parts[2])
      tags_list[[tag_name]] <- tag_value
    }
  }

  return(tags_list)
}





#' Import CIRCE Cohort Definitions from ATLAS
#'
#' Imports CIRCE JSON cohort definitions from an ATLAS WebAPI instance and registers
#' them in the manifest database. This is a wrapper around [CohortManifest]`$importAtlasCohorts()`
#' that provides a convenient standalone interface.
#'
#' @note This function is deprecated. Use [CohortManifest]`$importAtlasCohorts()` method directly instead.
#'
#' @param atlasConnection An ATLAS connection object (typically from ROhdsiWebApi package)
#'   with a method `getCohortDefinition(cohortId)` that returns a list containing
#'   an `expression` element with the CIRCE JSON string.
#' @param manifestPath Character. Path to the cohort manifest database. Defaults to
#'   `here::here("inputs/cohorts/cohortManifest.sqlite")`. If the database doesn't
#'   exist, it will be created.
#' @param cohortsLoadPath Character. Path to the CSV file containing cohort metadata.
#'   Defaults to `here::here("inputs/cohorts/cohortsLoad.csv")`.
#'   The CSV must have columns: `atlasId`, `label`, `category`
#'   (plus optional extra columns for tags).
#'
#' @return Invisibly returns a tibble with columns: id, label, status.
#'   Each row represents an import attempt.
#'
#' @details
#' **Workflow:**
#' 1. Loads or initializes the CohortManifest at `manifestPath`
#' 2. Calls `manifest$importAtlasCohorts(atlasConnection, cohortsLoadPath)`
#' 3. Returns the import results tibble
#'
#' **CSV Format:**
#' The cohortsLoad.csv file must have at minimum these columns:
#' - `atlasId`: ATLAS cohort definition ID (integer)
#' - `label`: Cohort name/label (character)
#' - `category`: Broad category for the cohort (character)
#' - Any additional columns are treated as tags (name = column name, value = cell value)
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   # Assuming ATLAS connection is set up
#'   results <- importAtlasCohorts(
#'     atlasConnection = setAtlasConnection()
#'   )
#'
#'   # View import results
#'   print(results)
#'
#'   # Load the manifest to work with the imported cohorts
#'   manifest <- loadCohortManifest()
#' }
#'
importAtlasCohorts <- function(atlasConnection,
                               manifestPath = here::here("inputs/cohorts/cohortManifest.sqlite"),
                               cohortsLoadPath = here::here("inputs/cohorts/cohortsLoad.csv")) {
  # Deprecation warning
  lifecycle::deprecate_warn(
    "0.1.0",
    "importAtlasCohorts()",
    details = c(
      "i" = "Use CohortManifest$importAtlasCohorts() method directly:",
      "i" = "  manifest <- CohortManifest$new(dbPath = '...')",
      "i" = "  manifest$importAtlasCohorts(atlasConnection, cohortsLoadPath)"
    )
  )

  # Load or initialize manifest
  if (file.exists(manifestPath)) {
    manifest <- CohortManifest$new(dbPath = manifestPath)
  } else {
    # Initialize new manifest
    cohorts_folder <- dirname(manifestPath)
    if (!dir.exists(cohorts_folder)) {
      dir.create(cohorts_folder, recursive = TRUE, showWarnings = FALSE)
    }
    manifest <- CohortManifest$new(dbPath = manifestPath)
  }

  # Call the class method to do the actual import
  results <- manifest$importAtlasCohorts(
    atlasConnection = atlasConnection,
    cohortsLoadPath = cohortsLoadPath
  )

  return(invisible(results))
}

#' Visualize Cohort Dependencies in a Report
#'
#' Creates a comprehensive markdown report visualizing the dependency structure
#' of all cohorts in a CohortManifest. The report includes a mermaid diagram
#' showing the dependency graph and a detailed table of all cohorts with their
#' relationships.
#'
#' @param manifest A CohortManifest object containing loaded cohorts.
#' @param outputPath Character. Optional path to save the markdown report. If NULL,
#'   the report is not saved to file. If a folder path is provided, the report is
#'   saved as "cohort_dependencies.md" in that folder. Defaults to NULL.
#'
#' @return Character. The markdown report content (invisibly if saved to file).
#'
#' @details
#' The report includes:
#' - **Overview**: Summary statistics (total cohorts, base cohorts, dependent cohorts)
#' - **Dependency Diagram**: Mermaid graph showing how cohorts depend on each other
#' - **Cohort Summary Table**: Details on each cohort including type and dependencies
#' - **Dependency Tree**: Hierarchical view of base cohorts and their dependents
#'
#' The mermaid diagram uses:
#' - Rectangles for CIRCE (base) cohorts
#' - Circles for subset cohorts
#' - Diamonds for union cohorts  
#' - Hexagons for complement cohorts
#' - Arrows showing dependency direction (parent → dependent)
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   manifest <- loadCohortManifest()
#'   
#'   # View report in console
#'   report <- visualizeCohortDependencies(manifest)
#'   
#'   # Save report to cohorts folder
#'   visualizeCohortDependencies(manifest, outputPath = "inputs/cohorts")
#' }
#'
visualizeCohortDependencies <- function(manifest, outputPath = NULL) {
  checkmate::assert_r6(manifest, classes = "CohortManifest")
  checkmate::assert_character(outputPath, len = 1, null.ok = TRUE)
  
  # Get the list of R6 CohortDef objects from the manifest
  cohort_list <- manifest$getManifest()
  
  if (length(cohort_list) == 0) {
    cli::cli_alert_warning("No cohorts found in manifest")
    return(invisible(NULL))
  }
  
  # Build summary statistics
  total_cohorts <- length(cohort_list)
  cohort_types <- sapply(cohort_list, function(c) c$getCohortType())
  
  type_counts <- table(cohort_types)
  base_cohort_count <- ifelse("circe" %in% names(type_counts), type_counts[["circe"]], 0)
  dependent_cohort_count <- total_cohorts - base_cohort_count
  
  # Build mermaid diagram
  mermaid_lines <- c("graph TD")
  
  # Process each cohort for mermaid nodes and edges
  node_defs <- character()
  edge_defs <- character()
  
  for (cohort in cohort_list) {
    cohort_id <- cohort$getId()
    cohort_label <- cohort$label
    cohort_type <- cohort$getCohortType()
    
    # Create node definition based on cohort type
    if (cohort_type == "circe") {
      node_shape <- "[\"{cohort_label}\"]"  # Rectangle for CIRCE
    } else if (cohort_type == "subset") {
      node_shape <- "(\"{cohort_label}\")"  # Circle for subset
    } else if (cohort_type == "union") {
      node_shape <- "{{\"{cohort_label}\"}}"  # Diamond for union
    } else {
      node_shape <- "{{{{\"{cohort_label}\"}}}}}"  # Hexagon for complement
    }
    
    node_id <- paste0("c", cohort_id)
    node_defs <- c(node_defs, paste0(node_id, node_shape))
    
    # Get dependencies from sidecar JSON and create edges
    file_path <- cohort$getFilePath()
    metadata_path <- gsub("\\.sql$", ".json", file_path)
    parent_ids <- if (file.exists(metadata_path)) {
      meta <- tryCatch(jsonlite::fromJSON(metadata_path), error = function(e) list())
      if (!is.null(meta$dependsOnCohortIds)) as.integer(meta$dependsOnCohortIds) else integer(0)
    } else {
      integer(0)
    }
    if (length(parent_ids) > 0) {
      for (parent_id in parent_ids) {
        parent_node_id <- paste0("c", parent_id)
        edge_defs <- c(edge_defs, paste0(parent_node_id, " --> ", node_id))
      }
    }
  }
  
  mermaid_lines <- c(mermaid_lines, node_defs, edge_defs)
  mermaid_diagram <- paste(mermaid_lines, collapse = "\n")
  
  # Build cohort summary table
  cohort_rows <- character()
  
  for (cohort in cohort_list) {
    cohort_id <- cohort$getId()
    cohort_label <- cohort$label
    cohort_type <- cohort$getCohortType()
    
    # Get dependencies from sidecar JSON
    file_path <- cohort$getFilePath()
    metadata_path <- gsub("\\.sql$", ".json", file_path)
    parent_ids <- if (file.exists(metadata_path)) {
      meta <- tryCatch(jsonlite::fromJSON(metadata_path), error = function(e) list())
      if (!is.null(meta$dependsOnCohortIds)) as.integer(meta$dependsOnCohortIds) else integer(0)
    } else {
      integer(0)
    }
    depends_on_str <- ifelse(length(parent_ids) == 0, "None", paste(parent_ids, collapse = ", "))
    
    cohort_rows <- c(
      cohort_rows,
      paste0(
        "| ", cohort_id, " | ", cohort_label, " | ",
        cohort_type, " | ", depends_on_str, " |"
      )
    )
  }
  
  # Build dependency tree (hierarchical view)
  tree_lines <- character()
  processed_env <- new.env()
  processed_env$ids <- integer()
  
  # Start with base cohorts
  for (cohort in cohort_list) {
    if (cohort$getCohortType() == "circe") {
      cohort_id <- cohort$getId()
      tree_lines <- c(
        tree_lines,
        paste0("- **", cohort$label, "** (ID: ", cohort_id, ")")
      )
      processed_env$ids <- c(processed_env$ids, cohort_id)
      
      # Find dependents
      result <- .build_dependency_tree(
        cohort_id = cohort_id,
        cohort_list = cohort_list,
        processed_env = processed_env,
        indent = "  ",
        tree_lines = tree_lines
      )
      tree_lines <- result$tree_lines
      processed_env <- result$processed_env
    }
  }
  
  # Add orphaned dependent cohorts (if any exist without base cohort loaded)
  for (cohort in cohort_list) {
    if (!(cohort$getId() %in% processed_env$ids)) {
      cohort_id <- cohort$getId()
      cohort_type <- cohort$getCohortType()
      tree_lines <- c(
        tree_lines,
        paste0("- **", cohort$label, "** (ID: ", cohort_id, ", Type: ", cohort_type, ")")
      )
      processed_env$ids <- c(processed_env$ids, cohort_id)
    }
  }
  
  # Construct the markdown report
  report <- paste0(
    "# Cohort Dependency Report\n\n",
    "**Generated**: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n",
    "## Overview\n\n",
    "| Metric | Count |\n",
    "|--------|-------|\n",
    "| Total Cohorts | ", total_cohorts, " |\n",
    "| Base Cohorts (CIRCE) | ", base_cohort_count, " |\n",
    "| Dependent Cohorts | ", dependent_cohort_count, " |\n",
    "\n",
    "### Cohort Type Breakdown\n\n",
    paste(
      sapply(
        names(type_counts),
        function(type) paste0("- **", type, "**: ", type_counts[[type]])
      ),
      collapse = "\n"
    ),
    "\n\n",
    "## Dependency Diagram\n\n",
    "```mermaid\n",
    mermaid_diagram,
    "\n```\n\n",
    "**Legend:**\n",
    "- ▭ Rectangle: CIRCE (base) cohort\n",
    "- ◯ Circle: Subset cohort\n",
    "- ◇ Diamond: Union cohort\n",
    "- ⬡ Hexagon: Complement cohort\n\n",
    "## Cohort Summary Table\n\n",
    "| ID | Label | Type | Depends On |\n",
    "|----|----|------|----------|\n",
    paste(cohort_rows, collapse = "\n"),
    "\n\n",
    "## Dependency Hierarchy\n\n",
    paste(tree_lines, collapse = "\n"),
    "\n\n",
    "---\n",
    "*Report generated by picard dependency visualizer*\n"
  )
  
  # Save to file if outputPath specified
  if (!is.null(outputPath)) {
    # Ensure output folder exists
    if (!dir.exists(outputPath)) {
      dir.create(outputPath, recursive = TRUE, showWarnings = FALSE)
    }
    
    output_file <- fs::path(outputPath, "cohort_dependencies.md")
    readr::write_file(report, file = output_file)
    
    cli::cli_alert_success(
      "Dependency report saved to: {fs::path_rel(output_file)}"
    )
  }
  
  invisible(report)
}

# Helper function to recursively build dependency tree
.build_dependency_tree <- function(cohort_id, cohort_list, processed_env, indent = "", tree_lines = character()) {
  # Find all cohorts that depend on this cohort_id
  dependents <- list()

  for (cohort in cohort_list) {
    file_path <- cohort$getFilePath()
    metadata_path <- gsub("\\.sql$", ".json", file_path)
    parent_ids <- if (file.exists(metadata_path)) {
      meta <- tryCatch(jsonlite::fromJSON(metadata_path), error = function(e) list())
      if (!is.null(meta$dependsOnCohortIds)) as.integer(meta$dependsOnCohortIds) else integer(0)
    } else {
      integer(0)
    }
    if (cohort_id %in% parent_ids && !(cohort$getId() %in% processed_env$ids)) {
      dependents[[length(dependents) + 1]] <- cohort
      processed_env$ids <- c(processed_env$ids, cohort$getId())
    }
  }
  
  # Add dependents to tree
  for (dependent in dependents) {
    dep_id <- dependent$getId()
    dep_label <- dependent$label
    dep_type <- dependent$getCohortType()
    tree_lines <- c(
      tree_lines,
      paste0(indent, "- *", dep_label, "* (ID: ", dep_id, ", Type: ", dep_type, ")")
    )
    
    # Recursively add sub-dependents
    result <- .build_dependency_tree(
      cohort_id = dep_id,
      cohort_list = cohort_list,
      processed_env = processed_env,
      indent = paste0(indent, "  "),
      tree_lines = tree_lines
    )
    tree_lines <- result$tree_lines
    processed_env <- result$processed_env
  }
  
  return(list(tree_lines = tree_lines, processed_env = processed_env))
}


# ---- Custom Cohort Validation & Definition ----

#' Validate a Custom SQL Cohort for Picard Compatibility
#'
#' @description
#' Checks a custom SQL string for common portability and correctness issues.
#' Issues are reported as warnings — this function never errors or blocks execution.
#'
#' Checks performed:
#' - Required SqlRender parameters present (`@target_cohort_id`, `@target_database_schema`, `@target_cohort_table`)
#' - DELETE statement present to ensure idempotency on re-run
#' - INSERT includes all four required cohort table columns
#' - No apparent hardcoded schema references
#'
#' @param sql Character. The SQL string to validate.
#' @param label Character. Cohort label for use in warning messages.
#'
#' @return Invisibly returns a character vector of warning messages (empty if none).
#'
#' @noRd
.validateCustomSql <- function(sql, label = "custom cohort") {
  # Required SqlRender parameters
  if (!grepl("@target_cohort_id", sql, fixed = TRUE)) {
    cli::cli_alert_warning("[{label}] SQL does not contain `@target_cohort_id` - the cohort ID will not be injected at execution time")
  }

  if (!grepl("@target_database_schema", sql, fixed = TRUE)) {
    cli::cli_alert_warning("[{label}] SQL does not contain `@target_database_schema` - target schema will not be injected at execution time")
  }

  if (!grepl("@target_cohort_table", sql, fixed = TRUE)) {
    cli::cli_alert_warning("[{label}] SQL does not contain `@target_cohort_table` - cohort table name will not be injected at execution time")
  }

  # Idempotency: DELETE step
  has_delete <- grepl("DELETE", sql, ignore.case = TRUE) &&
    grepl("@target_cohort_id", sql, fixed = TRUE)

  if (!has_delete) {
    cli::cli_alert_warning("[{label}] SQL does not include a DELETE step using `@target_cohort_id` - re-running will duplicate rows instead of replacing them")
  }

  # INSERT column completeness
  required_cols <- c("cohort_definition_id", "subject_id", "cohort_start_date", "cohort_end_date")
  if (grepl("INSERT", sql, ignore.case = TRUE)) {
    missing_cols <- required_cols[!sapply(required_cols, function(col) grepl(col, sql, ignore.case = TRUE))]
    if (length(missing_cols) > 0) {
      cli::cli_alert_warning(
        "[{label}] INSERT statement appears to be missing required cohort column(s): {paste(missing_cols, collapse = ', ')}"
      )
    }
  }

  # Hardcoded schema detection: pattern like WORD_WORD.tablename (all-caps schema prefix)
  if (grepl("[A-Z][A-Z0-9_]{4,}\\.[a-z]", sql, perl = TRUE)) {
    cli::cli_alert_warning("[{label}] Possible hardcoded schema reference detected - consider replacing with `@cdm_database_schema` for portability across databases")
  }

  invisible(NULL)
}


#' Define (Enrich) a Custom SQL Cohort in the Manifest
#'
#' @description
#' Enriches a cohort that has already been discovered by [loadCohortManifest()] with
#' a user-friendly label, tags, and the `"custom"` cohort type. Updates both the
#' in-memory manifest and the SQLite database so the enrichment persists across sessions.
#'
#' @details
#' **Workflow:**
#' 1. Place your custom SQL file in `inputs/cohorts/sql/`
#' 2. Call [loadCohortManifest()] — the file is auto-discovered with `cohortType = "circe"`
#'    and the filename as its label
#' 3. Call `defineCustomCohort()` to give it a proper label, tags, and mark it as `"custom"`
#' 4. Subsequent [loadCohortManifest()] calls restore the label/tags/type from the database
#'
#' **SQL requirements:**
#' Your SQL must use SqlRender parameters instead of hardcoded values. The following
#' parameters are automatically injected by [CohortManifest]`$executeCohortGeneration()`:
#' - `@target_cohort_id` — the cohort definition ID assigned by the manifest
#' - `@target_database_schema` — the schema where the cohort table resides
#' - `@target_cohort_table` — the cohort table name
#' - `@cdm_database_schema` — the CDM schema (for referencing OMOP clinical tables)
#'
#' A DELETE step before the INSERT is strongly recommended for idempotency:
#' ```sql
#' DELETE FROM @target_database_schema.@target_cohort_table
#'   WHERE cohort_definition_id = @target_cohort_id;
#' ```
#'
#' SQL portability warnings are automatically shown when you call this function and
#' again at execution time.
#'
#' @param manifest A [CohortManifest] R6 object returned by [loadCohortManifest()].
#' @param label Character. The user-friendly display name for the cohort
#'   (e.g., `"High-dose corticosteroid initiators"`).
#' @param tags Named list. Optional metadata tags (e.g., `list(category = "Exposure")`).
#'   Defaults to `list()`.
#' @param cohortId Integer. The cohort ID assigned in the manifest. Provide either
#'   `cohortId` or `sqlFilePath`, not both.
#' @param sqlFilePath Character. Path to the SQL file (relative or absolute). Provide
#'   either `sqlFilePath` or `cohortId`, not both.
#'
#' @return Invisibly returns `NULL`. Prints status messages on success.
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   # Step 1: place my_cohort.sql in inputs/cohorts/sql/
#'   # Step 2: load manifest
#'   manifest <- loadCohortManifest()
#'
#'   # Step 3: enrich the cohort by file path
#'   defineCustomCohort(
#'     manifest = manifest,
#'     sqlFilePath = "inputs/cohorts/sql/my_cohort.sql",
#'     label = "My Custom Cohort",
#'     tags = list(category = "Exposure", subCategory = "Corticosteroids")
#'   )
#'
#'   # Or enrich by cohort ID
#'   defineCustomCohort(
#'     manifest = manifest,
#'     cohortId = 5L,
#'     label = "My Custom Cohort",
#'     tags = list(category = "Exposure")
#'   )
#' }
defineCustomCohort <- function(manifest,
                                label,
                                tags = list(),
                                cohortId = NULL,
                                sqlFilePath = NULL) {
  checkmate::assert_class(x = manifest, classes = "CohortManifest")
  checkmate::assert_string(x = label, min.chars = 1)
  checkmate::assert_list(x = tags, names = "named")

  # Exactly one of cohortId / sqlFilePath must be provided
  has_id <- !is.null(cohortId)
  has_path <- !is.null(sqlFilePath)

  if (has_id && has_path) {
    cli::cli_abort("Provide either `cohortId` or `sqlFilePath`, not both.")
  }

  if (!has_id && !has_path) {
    cli::cli_abort("One of `cohortId` or `sqlFilePath` must be provided.")
  }

  if (has_id) {
    checkmate::assert_int(x = cohortId, lower = 1)
  }

  if (has_path) {
    checkmate::assert_string(x = sqlFilePath, min.chars = 1)
  }

  # Locate the CohortDef in the manifest
  cohort <- NULL

  if (has_id) {
    cohort <- manifest$getCohortById(as.integer(cohortId))
    if (is.null(cohort)) {
      cli::cli_abort("No cohort with ID {cohortId} found in the manifest.")
    }
  } else {
    # Match by file path (normalise separators for comparison)
    norm_target <- normalizePath(sqlFilePath, mustWork = FALSE)
    all_cohorts <- manifest$getManifest()

    for (cd in all_cohorts) {
      norm_fp <- normalizePath(cd$getFilePath(), mustWork = FALSE)
      if (norm_fp == norm_target || fs::path_rel(cd$getFilePath()) == fs::path_rel(sqlFilePath)) {
        cohort <- cd
        break
      }
    }

    if (is.null(cohort)) {
      cli::cli_abort(
        "No cohort with file path '{sqlFilePath}' found in the manifest. \\
        Ensure the file has been discovered by loadCohortManifest() first."
      )
    }
  }

  cohort_id <- cohort$getId()

  # Run SQL portability validation (warnings only)
  cohort_sql <- cohort$getSql()
  if (!is.null(cohort_sql) && nchar(cohort_sql) > 0) {
    .validateCustomSql(cohort_sql, label)
  }

  # Update in-memory CohortDef
  cohort$label <- label
  cohort$tags <- tags
  cohort$setCohortType("custom")

  # Persist to SQLite
  conn <- DBI::dbConnect(RSQLite::SQLite(), manifest$getDbPath())
  on.exit(DBI::dbDisconnect(conn))

  tags_str <- cohort$formatTagsAsString()

  DBI::dbExecute(
    conn,
    "UPDATE cohort_manifest SET label = ?, tags = ?, cohortType = 'custom' WHERE id = ?",
    list(label, tags_str, cohort_id)
  )

  cli::cli_alert_success("Defined custom cohort {cohort_id}: {label}")

  if (length(tags) > 0) {
    cli::cli_alert_info("Tags: {tags_str}")
  }

  invisible(NULL)
}


#' Update the label and/or tags of an existing manifest cohort
#'
#' @description
#' Updates the `label`, `tags`, or both on any cohort already present in the
#' manifest, regardless of cohort type. Changes are applied to both the
#' in-memory `CohortManifest` and the SQLite database. Only the fields
#' explicitly supplied are modified; omitted arguments are left unchanged.
#'
#' @param manifest A `CohortManifest` object.
#' @param cohortId Integer. The ID of the cohort to update.
#' @param label Character or `NULL`. New label for the cohort. If `NULL`, the
#'   existing label is preserved.
#' @param tags Named list or `NULL`. New tags for the cohort. If `NULL`, the
#'   existing tags are preserved.
#'
#' @return Invisibly returns `NULL`. Called for side effects.
#' @export
updateCohortMetadata <- function(manifest,
                                 cohortId,
                                 label = NULL,
                                 tags = NULL) {
  checkmate::assert_class(x = manifest, classes = "CohortManifest")
  checkmate::assert_int(x = cohortId, lower = 1)

  if (is.null(label) && is.null(tags)) {
    cli::cli_abort("At least one of `label` or `tags` must be provided.")
  }

  if (!is.null(label)) {
    checkmate::assert_string(x = label, min.chars = 1)
  }

  if (!is.null(tags)) {
    checkmate::assert_list(x = tags, names = "named")
  }

  cohort <- manifest$getCohortById(as.integer(cohortId))

  if (is.null(cohort)) {
    cli::cli_abort("No cohort with ID {cohortId} found in the manifest.")
  }

  # Apply in-memory updates for only the supplied fields
  if (!is.null(label)) {
    cohort$label <- label
  }

  if (!is.null(tags)) {
    cohort$tags <- tags
  }

  # Build a dynamic SET clause covering only the changed columns
  set_parts <- character(0)
  params <- list()

  if (!is.null(label)) {
    set_parts <- c(set_parts, "label = ?")
    params <- c(params, list(label))
  }

  if (!is.null(tags)) {
    tags_str <- cohort$formatTagsAsString()
    set_parts <- c(set_parts, "tags = ?")
    params <- c(params, list(tags_str))
  }

  params <- c(params, list(as.integer(cohortId)))

  sql <- paste(
    "UPDATE cohort_manifest SET",
    paste(set_parts, collapse = ", "),
    "WHERE id = ?"
  )

  conn <- DBI::dbConnect(RSQLite::SQLite(), manifest$getDbPath())
  on.exit(DBI::dbDisconnect(conn))

  DBI::dbExecute(conn, sql, params)

  # Report what changed
  changed <- character(0)

  if (!is.null(label)) {
    changed <- c(changed, "label \u2192 {label}")
  }

  if (!is.null(tags)) {
    changed <- c(changed, "tags \u2192 {tags_str}")
  }

  cli::cli_alert_success("Updated cohort {cohortId}: {paste(changed, collapse = ', ')}")

  invisible(NULL)
}
