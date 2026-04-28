#' Import and Bind Results by Version and Task
#' @description Combines result files across multiple database runs for a specific version and task.
#'   Finds all CSV files in the task folder for each database and combines them into named results,
#'   then saves them to the export folder.
#' @param version Character. Pipeline version (e.g., "1.0.0")
#' @param taskName Character. Name of the task (e.g., "cohortCounts", "characterization")
#' @param dbIds Character vector of database configuration IDs from config.yml
#' @param resultsPath Character. Path to results root folder. Defaults to "exec/results"
#' @param exportPath Character. Path where combined results will be saved. 
#'   Defaults to "dissemination/export/merge"
#' @return Invisibly returns data frame of export summary with columns: fileName, rowCount, databaseCount
#' @details
#' Folder structure expected:
#' ```
#' exec/results/
#'   databaseName1/
#'     version/
#'       taskName/
#'         file1.csv
#'         file2.csv
#'   databaseName2/
#'     version/
#'       taskName/
#'         file1.csv
#'         file2.csv
#' ```
#'
#' All files with the same name from each database are combined with databaseId added and saved to exportPath.
#' @export
importAndBind <- function(version, taskName, dbIds, resultsPath = here::here("exec/results"),
                          exportPath = here::here("dissemination/export/merge")) {
  
  # Get database names from config
  databaseNames <- purrr::map_chr(dbIds, ~config::get("databaseName", config = .x))
  
  # Build task folder paths for each database
  taskFolders <- purrr::map_chr(
    databaseNames,
    ~fs::path(resultsPath, .x, version, taskName)
  )
  
  # Verify task folders exist for all databases
  missingFolders <- taskFolders[!fs::dir_exists(taskFolders)]
  if (length(missingFolders) > 0) {
    cli::cli_alert_warning("Task folder(s) not found:")
    cli::cli_bullets(setNames(fs::path_rel(missingFolders), "x"))
  }
  
  # Get all CSV files from the first database to identify files to combine
  firstValidFolder <- taskFolders[fs::dir_exists(taskFolders)][1]
  
  if (is.na(firstValidFolder)) {
    cli::cli_alert_danger("No valid task folders found for version {version}, task {taskName}")
    stop("Cannot find task results")
  }
  
  # Get all CSV files only - ignore other data file types
  allFiles <- fs::dir_ls(firstValidFolder, glob = "*.csv", type = "file")
  fileNames <- basename(allFiles)
  
  # Filter to ensure only CSV files are included
  fileNames <- fileNames[tolower(tools::file_ext(fileNames)) == "csv"]
  
  # Bundle detection: some packages (e.g. CohortPrevalence) write results into
  # timestamped subdirectories rather than directly into the task folder.
  # When no direct CSVs are found, scan for subdirs that contain CSVs and use
  # the alphabetically-last one (YYYYMMDD_HHMMSS naming = chronologically latest).
  if (length(fileNames) == 0) {
    subDirs <- sort(basename(fs::dir_ls(firstValidFolder, type = "directory")))
    bundleDirs <- subDirs[purrr::map_lgl(
      subDirs,
      ~length(fs::dir_ls(fs::path(firstValidFolder, .x), glob = "*.csv", type = "file")) > 0
    )]
    
    if (length(bundleDirs) == 0) {
      cli::cli_alert_warning("No CSV files found in task folder: {fs::path_rel(firstValidFolder)}")
      return(list())
    }
    
    selectedBundle <- bundleDirs[length(bundleDirs)]
    
    if (length(bundleDirs) > 1) {
      skipped <- bundleDirs[-length(bundleDirs)]
      cli::cli_alert_warning("Multiple result bundles found — skipping {length(skipped)} older run(s):")
      cli::cli_bullets(setNames(skipped, "x"))
    }
    
    cli::cli_alert_info(
      "No direct CSVs — detected {length(bundleDirs)} bundle(s); using latest: {.val {selectedBundle}}"
    )
    
    # Replace task folders with selected bundle subdirectory for all databases
    taskFolders <- fs::path(taskFolders, selectedBundle)
    
    allFiles <- fs::dir_ls(fs::path(firstValidFolder, selectedBundle), glob = "*.csv", type = "file")
    fileNames <- basename(allFiles)
    fileNames <- fileNames[tolower(tools::file_ext(fileNames)) == "csv"]
    
    if (length(fileNames) == 0) {
      cli::cli_alert_warning("No CSV files found in selected bundle: {.val {selectedBundle}}")
      return(list())
    }
  }
  
  cli::cli_alert_info("Found {length(fileNames)} CSV file(s) to combine")
  
  # For each CSV file, read from all databases and combine
  combinedResults <- list()
  exportSummary <- data.frame(
    fileName = character(),
    rowCount = integer(),
    databaseCount = integer(),
    stringsAsFactors = FALSE
  )
  
  for (fileName in fileNames) {
    tryCatch({
      # Only process CSV files - skip any other file types
      if (tolower(tools::file_ext(fileName)) != "csv") {
        cli::cli_alert_warning("Skipping non-CSV file: {fileName}")
        next
      }
      
      fileData <- list()
      successCount <- 0
      
      for (i in seq_along(databaseNames)) {
        filePath <- fs::path(taskFolders[i], fileName)
        
        if (fs::file_exists(filePath)) {
          fileData[[i]] <- readr::read_csv(filePath, show_col_types = FALSE) |>
            dplyr::mutate(
              databaseId = databaseNames[i],
              .before = 1
            )
          successCount <- successCount + 1
        }
      }
      
      if (successCount > 0) {
        # Combine all data frames, keeping only those that were successfully read
        combined <- do.call('rbind', fileData[!sapply(fileData, is.null)]) |>
          tibble::as_tibble()
        
        # Save to export path
        fs::dir_create(exportPath, recurse = TRUE)
        exportFile <- fs::path(exportPath, fileName)
        readr::write_csv(combined, exportFile)
        
        labelName <- tools::file_path_sans_ext(fileName)
        combinedResults[[labelName]] <- combined
        
        cli::cli_alert_success("Combined {fileName}: {nrow(combined)} rows from {successCount} database(s)")
        cli::cli_alert_success("Saved to: {fs::path_rel(exportFile)}")
        
        # Add to summary
        exportSummary <- rbind(
          exportSummary,
          data.frame(
            fileName = fileName,
            rowCount = nrow(combined),
            databaseCount = successCount,
            stringsAsFactors = FALSE
          )
        )
      } else {
        cli::cli_alert_warning("Could not find {fileName} in any database folder")
      }
    }, error = function(e) {
      cli::cli_alert_danger("Error combining {fileName}: {e$message}")
    })
  }
  
  # Return summary invisibly
  if (length(combinedResults) == 0) {
    cli::cli_alert_warning("No files were successfully combined")
  } else {
    cli::cli_alert_success("Export complete: {nrow(exportSummary)} file(s) saved to {fs::path_rel(exportPath)}")
  }
  
  invisible(exportSummary)
}

#' Validate Required Columns in Results
#' @description Checks that a results data frame has the required columns: databaseId, cohortId, cohortLabel
#' @param resultsData Data frame to validate
#' @param stepName Character. Name of the post-processing step (for error messages)
#' @return Logical. TRUE if valid, stops with error if not
#' @keywords internal
validateResultsColumns <- function(resultsData, stepName) {
  requiredCols <- c("databaseId", "cohortId", "cohortLabel")
  missingCols <- setdiff(requiredCols, names(resultsData))
  
  if (length(missingCols) > 0) {
    cli::cli_alert_danger("Results from {stepName} missing required columns:")
    cli::cli_bullets(setNames(missingCols, "x"))
    stop(paste("Missing columns in", stepName))
  }
  
  invisible(TRUE)
}


#' Review Export File Schema
#' @description Examines all CSV files in the export folder and extracts schema information
#'   (column names and data types). Useful for identifying ETL requirements before dissemination.
#' @param exportPath Character. Path to the export folder containing merged results.
#'   Defaults to "dissemination/export/merge"
#' @return Data frame with columns:
#'   - fileName: Name of the CSV file
#'   - columnName: Name of the column
#'   - dataType: R data type as detected by readr (character, numeric, logical, etc.)
#'   - rowCount: Number of rows in the file
#' @details
#' This function helps identify:
#' - Column naming inconsistencies across files
#' - Unexpected data types that may need transformation
#' - Columns that should be renamed or restructured
#' - Data quality issues (e.g., columns with mostly NAs)
#'
#' The data frame can be sorted/filtered to understand transformation requirements.
#' @export
#' @examples
#' \dontrun{
#'   schema <- reviewExportSchema()
#'   
#'   # View all columns and types
#'   print(schema)
#'   
#'   # Check for character columns that should be numeric
#'   schema[schema$dataType == "character", ]
#'   
#'   # Get distinct data types per file
#'   schema |>
#'     dplyr::group_by(fileName) |>
#'     dplyr::summarise(colCount = dplyr::n(), .groups = "drop")
#' }
reviewExportSchema <- function(exportPath = here::here("dissemination/export/merge")) {
  
  cli::cli_rule("Review Export File Schema")
  
  # Check if export path exists
  if (!dir.exists(exportPath)) {
    cli::cli_alert_danger("Export path does not exist: {fs::path_rel(exportPath)}")
    stop("Export folder not found")
  }
  
  # Get all CSV files except schema_review files
  csvFiles <- fs::dir_ls(exportPath, glob = "*.csv", type = "file")
  # exclude any files that are schema reviews (to avoid self-inclusion)
  csvFiles <- csvFiles[!grepl("schema_review", basename(csvFiles))]
  
  if (length(csvFiles) == 0) {
    cli::cli_alert_info("No CSV files found in export path")
    return(data.frame(
      fileName = character(),
      columnName = character(),
      dataType = character(),
      rowCount = integer(),
      stringsAsFactors = FALSE
    ))
  }
  
  cli::cli_alert_info("Reviewing {length(csvFiles)} export file(s)...")
  
  # Extract schema information from each file
  schemaList <- list()
  
  for (filePath in csvFiles) {
    fileName <- basename(filePath)
    
    tryCatch({
      # Read the file to get column information
      # Use spec_csv to get data types without reading all rows
      spec <- readr::spec_csv(filePath)
      
      # Get row count
      rowCount <- length(readr::read_lines(filePath)[-1])   # Count lines minus header
      
      # Extract column specs
      for (colName in names(spec$cols)) {
        colClass <- class(spec$cols[[colName]])[1]
        
        # Simplify class name (e.g., "collector_character" -> "character")
        dataType <- gsub("collector_", "", colClass)
        
        schemaList[[paste0(fileName, "_", colName)]] <- data.frame(
          fileName = fileName,
          columnName = colName,
          dataType = dataType,
          rowCount = rowCount,
          stringsAsFactors = FALSE
        )
      }
      
      cli::cli_alert_success("Reviewed {fileName}: {length(spec$cols)} columns, {rowCount} rows")
    }, error = function(e) {
      cli::cli_alert_danger("Error reviewing {fileName}: {e$message}")
    })
  }
  
  # Combine all schema information
  if (length(schemaList) == 0) {
    return(data.frame(
      fileName = character(),
      columnName = character(),
      dataType = character(),
      rowCount = integer(),
      stringsAsFactors = FALSE
    ))
  }
  
  schema <- do.call('rbind', schemaList) |>
    tibble::as_tibble() |>
    dplyr::arrange(fileName)
  
  rownames(schema) <- NULL
  
  # Print summary
  cli::cli_alert_success("Schema review complete!")
  cli::cli_bullets(c(
    "v" = "{length(unique(schema$fileName))} file(s) reviewed",
    "v" = "{nrow(schema)} total columns"
  ))
  
  return(schema)
}

#' Validate Cohort Results Completeness
#' @description Validates that all cohorts in the cohort key have results and checks for 
#'   non-enumeration. Compares expected cohorts from cohortKey.csv against actual results 
#'   to identify missing or zero-count cohorts.
#' @param exportPath Character. Path to export folder containing results. 
#'   Defaults to "dissemination/export/merge"
#' @param resultsFileName Character. Name of the results file to validate (e.g., "cohortCounts.csv").
#'   If NULL, searches for a file with cohort_id, cohort_entries, and cohort_subjects columns.
#' @return Data frame with columns:
#'   - cohortId: The cohort ID
#'   - label: Cohort label from cohortKey
#'   - validationStatus: "OK", "ZeroCount", or "Missing"
#'   - details: Additional information about the validation result
#' @details
#' The function identifies three validation statuses:
#' - **OK**: Cohort exists in results with non-zero counts
#' - **ZeroCount**: Cohort exists but has zero entries or subjects
#' - **Missing**: Cohort in cohortKey but not found in results (non-enumerated)
#' @export
validateCohortResults <- function(exportPath = here::here("dissemination/export/merge"),
                                  resultsFileName = NULL) {
  
  cli::cli_rule("Validate Cohort Results Completeness")
  
  # Check if export path exists
  if (!dir.exists(exportPath)) {
    cli::cli_alert_danger("Export path does not exist: {fs::path_rel(exportPath)}")
    stop("Export folder not found")
  }
  
  # Load cohort reference from manifest snapshot
  snapshotPath <- fs::path(exportPath, "cohortManifestSnapshot.csv")
  if (!file.exists(snapshotPath)) {
    cli::cli_alert_warning("cohortManifestSnapshot.csv not found: {fs::path_rel(snapshotPath)}")
    return(data.frame(
      cohortId = integer(),
      label = character(),
      validationStatus = character(),
      details = character(),
      stringsAsFactors = FALSE
    ))
  }
  
  tryCatch({
    cohortKey <- readr::read_csv(snapshotPath, show_col_types = FALSE) |>
      dplyr::rename(cohortId = id, cohortLabel = label)
    cli::cli_alert_success("Loaded cohort reference: {nrow(cohortKey)} cohort(s)")
  }, error = function(e) {
    cli::cli_alert_danger("Error reading cohortManifestSnapshot.csv: {e$message}")
    stop(e$message)
  })
  
  # Find cohort results file
  csvFiles <- fs::dir_ls(exportPath, glob = "*.csv", type = "file")
  # Exclude reference files
  csvFiles <- csvFiles[!basename(csvFiles) %in% c("cohortManifestSnapshot.csv", "databaseInfo.csv", "schema_review.csv")]
  
  # If resultsFileName specified, use that; otherwise search for file with cohort_id column
  resultsFile <- NULL
  
  if (!is.null(resultsFileName)) {
    candidate <- fs::path(exportPath, resultsFileName)
    if (file.exists(candidate)) {
      resultsFile <- candidate
    }
  } else {
    # Search for file with cohort_id column
    for (filePath in csvFiles) {
      tryCatch({
        spec <- readr::spec_csv(filePath)
        if ("cohort_id" %in% names(spec$cols)) {
          resultsFile <- filePath
          break
        }
      }, error = function(e) {
        # Skip files with read errors
      })
    }
  }
  
  if (is.null(resultsFile)) {
    cli::cli_alert_warning("No cohort results file found in export path")
    return(data.frame(
      cohortId = integer(),
      label = character(),
      validationStatus = character(),
      details = character(),
      stringsAsFactors = FALSE
    ))
  }
  
  resultsFileName <- basename(resultsFile)
  cli::cli_alert_info("Validating against results file: {resultsFileName}")
  
  # Load results file
  tryCatch({
    results <- readr::read_csv(resultsFile, show_col_types = FALSE)
    
    # Check for required columns
    requiredCols <- c("cohort_id", "cohort_entries", "cohort_subjects")
    missingCols <- setdiff(requiredCols, names(results))
    if (length(missingCols) > 0) {
      cli::cli_alert_warning("Results file missing expected columns: {paste(missingCols, collapse=', ')}")
    }
    
    cli::cli_alert_success("Loaded results: {nrow(results)} row(s)")
  }, error = function(e) {
    cli::cli_alert_danger("Error reading results file: {e$message}")
    stop(e$message)
  })
  
  # Validate completeness
  validation <- data.frame(
    cohortId = integer(),
    label = character(),
    validationStatus = character(),
    details = character(),
    stringsAsFactors = FALSE
  )
  
  for (i in seq_len(nrow(cohortKey))) {
    cohortId <- cohortKey$cohortId[i]
    label <- cohortKey$cohortLabel[i]
    
    # Check if cohort exists in results
    resultRow <- results[results$cohort_id == cohortId, ]
    
    if (nrow(resultRow) == 0) {
      # Missing cohort
      status <- "Missing"
      details <- "Cohort not found in results (non-enumerated)"
    } else {
      # Check for zero counts
      entries <- resultRow$cohort_entries[1]
      subjects <- resultRow$cohort_subjects[1]
      
      if (is.na(entries) || entries == 0 || is.na(subjects) || subjects == 0) {
        status <- "ZeroCount"
        details <- glue::glue("entries: {entries}, subjects: {subjects}")
      } else {
        status <- "OK"
        details <- glue::glue("entries: {entries}, subjects: {subjects}")
      }
    }
    
    validation <- rbind(validation, data.frame(
      cohortId = cohortId,
      label = label,
      validationStatus = status,
      details = details,
      stringsAsFactors = FALSE
    ))
  }
  
  # Print summary
  validation <- tibble::as_tibble(validation)
  
  okCount <- sum(validation$validationStatus == "OK")
  missingCount <- sum(validation$validationStatus == "Missing")
  zeroCount <- sum(validation$validationStatus == "ZeroCount")
  
  cli::cli_alert_success("Validation complete!")
  cli::cli_bullets(c(
    "v" = "{okCount} cohort(s) OK",
    if (zeroCount > 0) c("!" = "{zeroCount} cohort(s) with zero counts") else NULL,
    if (missingCount > 0) c("x" = "{missingCount} cohort(s) missing/non-enumerated") else NULL
  ))
  
  if (missingCount > 0 || zeroCount > 0) {
    cli::cli_text("")
    cli::cli_alert_warning("Review validation details for issues:")
    issues <- validation[validation$validationStatus != "OK", ]
    for (i in seq_len(nrow(issues))) {
      issue <- issues[i, ]
      cli::cli_bullets(c(
        " " = "{issue$cohortId}: {issue$label} - {issue$validationStatus} ({issue$details})"
      ))
    }
  }
  
  return(validation)
}

#' Orchestrate Pipeline Export with Merging and QC
#' @description Orchestrates complete pipeline export process: merges results across all tasks
#'   for a specified pipeline version, generates reference files (cohortKey, databaseInfo,
#'   schema_review), runs QC validation on cohort completeness, and generates execution metadata.
#' @param pipelineVersion Character. Pipeline version (e.g., "1.0.0")
#' @param dbIds Character vector of database configuration IDs from config.yml
#' @param resultsPath Character. Path to results root folder. Defaults to "exec/results"
#' @param exportPath Character. Path where combined results will be saved.
#'   Defaults to "dissemination/export/merge"
#' @param cohortsFolderPath Character. Path to cohorts folder for the CohortManifest.
#'   Defaults to "inputs/cohorts". If the path exists and contains a cohort manifest,
#'   generates a cohortKey reference file with id, label, and tags.
#' @param testMode Logical or NULL. When TRUE, QC checks are non-fatal (errors become
#'   warnings) and qcStatus is set to "DevMode". When NULL (default), testMode is
#'   automatically set to TRUE for non-semver pipeline versions (e.g. "dev", "test")
#'   and FALSE for semantic versions (e.g. "1.0.0").
#' @return Data frame summarizing all merged tasks with columns:
#'   - taskName: Name of the task
#'   - fileCount: Number of result files found for that task
#'   - totalRows: Total rows across all result files
#'   - filesExported: Comma-separated list of exported file names
#' @details
#' The function orchestrates the complete pipeline export:
#' 1. Captures git commit SHA for reproducibility tracking
#' 2. Snapshots environment (renv.lock) for non-dev versions
#' 3. Discovers tasks for the specified pipeline version
#' 4. Merges results across all databases for each task via importAndBind()
#' 5. Generates reference files: cohortKey.csv, databaseInfo.csv
#' 6. Reviews schema of exported files (schema_review.csv)
#' 7. Validates cohort completeness (qc_cohortValidation.csv)
#' 8. Generates execution metadata (qc_processMeta.csv)
#'
#' Output files created in version export folder:
#' - Merged result CSVs (per task)
#' - cohortManifestSnapshot.csv: Active cohort manifest at export time (id, label, filePath, hash, cohortType, timestamp)
#' - databaseInfo.csv: Databases included in merge operation
#' - schema_review.csv: Column-level inspection of all files
#' - qc_cohortValidation.csv: Cohort completeness validation results
#' - qc_processMeta.csv: Execution metadata and summary statistics
#'   - executionTimestamp: When the export ran
#'   - pipelineVersion: Version being exported
#'   - codeCommitSha: Git commit SHA of code at execution time
#'   - lockfileHash: Hash of renv.lock for dependency reproducibility
#'   - filesExported: Comma-separated list of exported file names
#' @details
#' The function:
#' 1. Captures git commit SHA and (optionally) environment snapshot
#' 2. Scans the first database's version folder to discover available tasks
#' 3. For each task found, calls importAndBind() to merge across databases
#' 4. Generates reference and QC files
#' 5. Returns a summary data frame of the merge operation
#'
#' Expected folder structure:
#' ```
#' exec/results/
#'   databaseName1/
#'     version/
#'       task1/
#'         results.csv
#'       task2/
#'         results.csv
#'   databaseName2/
#'     version/
#'       task1/
#'         results.csv
#'       task2/
#'         results.csv
#' ```
#' @export
orchestratePipelineExport <- function(pipelineVersion, dbIds, resultsPath = here::here("exec/results"),
                                    exportPath = here::here("dissemination/export/merge"),
                                    cohortsFolderPath = here::here("inputs/cohorts"),
                                    testMode = NULL) {
  
  cli::cli_rule("Orchestrate Pipeline Export for Version {pipelineVersion}")
  
  # Default testMode: non-semver versions (e.g. "dev", "test") automatically run in test mode
  if (is.null(testMode)) {
    testMode <- !grepl("^\\d+\\.\\d+\\.\\d+$", pipelineVersion)
  }
  
  if (testMode) {
    cli::cli_alert_warning("EXPORT running in TEST MODE \u2014 QC checks non-fatal")
  }
  
  # Get code commit SHA for reproducibility metadata
  codeCommitSha <- tryCatch({
    logs <- gert::git_log()
    if (nrow(logs) > 0) {
      logs$commit[1]
    } else {
      NA_character_
    }
  }, error = function(e) {
    cli::cli_alert_warning("Could not get git commit SHA")
    NA_character_
  })
  
  # Snapshot environment only for production (semver) versions
  if (!testMode) {
    lockfileHash <- snapshotEnvironment(versionLabel = pipelineVersion, savePath = NULL)
  } else {
    lockfileHash <- "dev-skip"
    cli::cli_alert_info("Skipping environment snapshot for non-production version")
  }
  
  # Get database names and labels from config
  databaseNames <- purrr::map_chr(dbIds, ~config::get("databaseName", config = .x))
  databaseLabels <- purrr::map_chr(dbIds, ~config::get("databaseLabel", config = .x))
  cohortTableNames <- purrr::map_chr(dbIds, ~config::get("cohortTable", config = .x))
  
  # Create database info reference file
  databaseInfo <- data.frame(
    databaseId = dbIds,
    databaseName = databaseNames,
    databaseLabel = databaseLabels,
    cohortTable = cohortTableNames,
    stringsAsFactors = FALSE
  )
  
  # Build path to first database's version folder
  firstDbVersionPath <- fs::path(resultsPath, databaseNames[1], pipelineVersion)
  
  if (!dir.exists(firstDbVersionPath)) {
    cli::cli_alert_danger("Version folder not found: {fs::path_rel(firstDbVersionPath)}")
    stop("Cannot find results for version {pipelineVersion}")
  }
  
  # Create version-specific export path
  versionExportPath <- fs::path(exportPath, glue::glue("v{pipelineVersion}"))
  fs::dir_create(versionExportPath, recurse = TRUE)
  cli::cli_alert_info("Export path: {fs::path_rel(versionExportPath)}")
  
  # Discover all task folders for this version
  taskFolders <- fs::dir_ls(firstDbVersionPath, type = "directory")
  
  if (length(taskFolders) == 0) {
    cli::cli_alert_info("No task folders found for version {pipelineVersion}")
    return(data.frame(
      taskName = character(),
      fileCount = integer(),
      totalRows = integer(),
      filesExported = character(),
      stringsAsFactors = FALSE
    ))
  }
  
  taskNames <- basename(taskFolders)
  
  cli::cli_alert_info("Found {length(taskNames)} task(s) for version {pipelineVersion}")
  cli::cli_bullets(setNames(taskNames, "•"))
  
  # Process each task
  mergeSummary <- data.frame(
    taskName = character(),
    fileCount = integer(),
    totalRows = integer(),
    filesExported = character(),
    stringsAsFactors = FALSE
  )
  
  for (taskName in taskNames) {
    cli::cli_h3("Processing task: {taskName}")
    
    tryCatch({
      # Call importAndBind for this task
      exportSummary <- importAndBind(
        version = pipelineVersion,
        taskName = taskName,
        dbIds = dbIds,
        resultsPath = resultsPath,
        exportPath = versionExportPath
      )
      
      if (nrow(exportSummary) > 0) {
        # Calculate merged statistics
        fileCount <- nrow(exportSummary)
        totalRows <- sum(exportSummary$rowCount, na.rm = TRUE)
        filesExported <- paste(exportSummary$fileName, collapse = ", ")
        
        # Add to summary
        mergeSummary <- rbind(
          mergeSummary,
          data.frame(
            taskName = taskName,
            fileCount = fileCount,
            totalRows = totalRows,
            filesExported = filesExported,
            stringsAsFactors = FALSE
          )
        )
      } else {
        cli::cli_alert_warning("No files merged for task {taskName}")
      }
    }, error = function(e) {
      cli::cli_alert_danger("Error processing task {taskName}: {e$message}")
    })
  }
  
  # Print final summary
  if (nrow(mergeSummary) > 0) {
    cli::cli_alert_success("Pipeline merge complete for version {pipelineVersion}")
    cli::cli_bullets(c(
      "v" = "{nrow(mergeSummary)} task(s) processed",
      "v" = "{sum(mergeSummary$fileCount)} total files exported",
      "v" = "{sum(mergeSummary$totalRows)} total rows merged"
    ))
  } else {
    cli::cli_alert_warning("No tasks were successfully processed")
  }
  
  # Review the export schema
  cli::cli_text("")
  tryCatch({
    schema <- reviewExportSchema(exportPath = versionExportPath)
    schemaFilePath <- fs::path(versionExportPath, "schema_review.csv")
    readr::write_csv(schema, schemaFilePath)
    cli::cli_alert_success("Schema review results saved to {fs::path_rel(schemaFilePath)}")
  }, error = function(e) {
    if (testMode) {
      cli::cli_alert_warning("Schema review skipped (test mode): {e$message}")
    } else {
      cli::cli_alert_danger("Error saving schema review: {e$message}")
    }
  })
  
  # Save database info reference file
  tryCatch({
    databaseInfoPath <- fs::path(versionExportPath, "databaseInfo.csv")
    readr::write_csv(databaseInfo, databaseInfoPath)
    cli::cli_alert_success("Database info saved to {fs::path_rel(databaseInfoPath)}: {nrow(databaseInfo)} database(s)")
  }, error = function(e) {
    cli::cli_alert_danger("Error saving database info: {e$message}")
  })
  
  # Create cohortKey reference file if cohorts manifest exists
  if (dir.exists(cohortsFolderPath) && file.exists(fs::path(cohortsFolderPath, "cohortManifest.sqlite"))) {
    tryCatch({
      cli::cli_text("")
      cli::cli_alert_info("Creating cohort key reference file...")
      
      # Load cohort manifest using new API
      cohortManifest <- loadCohortManifest(cohortsFolderPath = cohortsFolderPath, verbose = FALSE)
      
      # Save manifest snapshot for point-in-time cohort provenance.
      # Contains id, label, tags, filePath, hash, cohortType, status, timestamp.
      # The hash column enables recovery via: git log -- <filePath>
      manifestSnapshot <- cohortManifest$tabulateManifest(filter = "active")
      snapshotPath <- fs::path(versionExportPath, "cohortManifestSnapshot.csv")
      readr::write_csv(manifestSnapshot, snapshotPath)
      cli::cli_alert_success("Cohort manifest snapshot saved to {fs::path_rel(snapshotPath)}: {nrow(manifestSnapshot)} cohort(s)")
    }, error = function(e) {
      cli::cli_alert_danger("Error creating cohort key: {e$message}")
    })
  }
  
  # QC Section 1: Validate cohort completeness
  cli::cli_text("")
  cli::cli_h2("QC: Cohort Completeness Validation")
  hasWarnings <- NA
  tryCatch({
    cohortValidation <- validateCohortResults(
      exportPath = versionExportPath,
      resultsFileName = NULL
    )
    
    qcValidationPath <- fs::path(versionExportPath, "qc_cohortValidation.csv")
    readr::write_csv(cohortValidation, qcValidationPath)
    cli::cli_alert_success("Cohort validation saved to {fs::path_rel(qcValidationPath)}")
    
    # Determine QC status based on validation results
    hasWarnings <- any(cohortValidation$validationStatus %in% c("ZeroCount", "Missing"))
  }, error = function(e) {
    if (testMode) {
      cli::cli_alert_warning("Cohort validation skipped (test mode): {e$message}")
    } else {
      cli::cli_alert_warning("Cohort validation skipped: {e$message}")
    }
    hasWarnings <<- NA
  })
  
  # QC Section 2: Generate execution metadata
  cli::cli_text("")
  cli::cli_h2("QC: Execution Metadata")
  tryCatch({
    # Determine QC status
    if (testMode) {
      qcStatus <- "DevMode"
    } else if (is.na(hasWarnings)) {
      qcStatus <- "Completed"
    } else if (hasWarnings) {
      qcStatus <- "HasWarnings"
    } else {
      qcStatus <- "OK"
    }
    
    # Build databases string
    databasesUsed <- paste(databaseLabels, collapse = " | ")
    
    # Create metadata record
    processMeta <- data.frame(
      executionTimestamp = as.character(Sys.time()),
      pipelineVersion = pipelineVersion,
      codeCommitSha = codeCommitSha,
      lockfileHash = lockfileHash,
      databasesIncluded = databasesUsed,
      databaseCount = length(dbIds),
      tasksProcessed = nrow(mergeSummary),
      totalFilesExported = sum(mergeSummary$fileCount),
      totalRowsMerged = sum(mergeSummary$totalRows),
      qcStatus = qcStatus,
      stringsAsFactors = FALSE
    )
    
    # Save process metadata
    processMetaPath <- fs::path(versionExportPath, "qc_processMeta.csv")
    readr::write_csv(processMeta, processMetaPath)
    cli::cli_alert_success("Process metadata saved to {fs::path_rel(processMetaPath)}")
    
    # Print execution summary
    cli::cli_bullets(c(
      "v" = "Timestamp: {processMeta$executionTimestamp}",
      "v" = "Pipeline: v{pipelineVersion}",
      "v" = "Databases: {processMeta$databaseCount} ({databasesUsed})",
      "v" = "Tasks: {processMeta$tasksProcessed}",
      "v" = "Files: {processMeta$totalFilesExported}",
      "v" = "Rows: {processMeta$totalRowsMerged}",
      if (qcStatus != "OK") c("!" = "QC Status: {qcStatus}") else c("v" = "QC Status: {qcStatus}")
    ))
  }, error = function(e) {
    cli::cli_alert_danger("Error generating process metadata: {e$message}")
  })
  
  # Final completion message
  cli::cli_text("")
  cli::cli_alert_success("Pipeline export complete!")
  cli::cli_bullets(c(
    "i" = "Export location: {fs::path_rel(versionExportPath)}",
    "i" = "Reference files: cohortManifestSnapshot.csv, databaseInfo.csv",
    "i" = "Schema review: schema_review.csv",
    "i" = "QC reports: qc_cohortValidation.csv, qc_processMeta.csv"
  ))
  
  # Convert to tibble and return invisibly
  mergeSummary <- tibble::as_tibble(mergeSummary)
  invisible(mergeSummary)
}

#' @title Test Orchestrate Pipeline Export
#' @description Executes the pipeline export in test mode. QC checks are non-fatal
#'   (errors become warnings) and qcStatus is set to "DevMode". Enforces that the
#'   call is made from a non-main branch to prevent accidental test exports on main.
#' @param pipelineVersion Character. Pipeline version label (e.g. "dev").
#' @param dbIds Character vector of database configuration IDs from config.yml.
#' @param resultsPath Character. Path to results root folder. Defaults to "exec/results".
#' @param exportPath Character. Path where combined results will be saved.
#'   Defaults to "dissemination/export/merge".
#' @param cohortsFolderPath Character. Path to cohorts folder for the CohortManifest.
#'   Defaults to "inputs/cohorts".
#' @return Invisibly returns the merge summary data frame from orchestratePipelineExport().
#' @export
testOrchestratePipelineExport <- function(pipelineVersion = "dev", dbIds,
                                          resultsPath = here::here("exec/results"),
                                          exportPath = here::here("dissemination/export/merge"),
                                          cohortsFolderPath = here::here("inputs/cohorts")) {
  checkmate::assert_character(dbIds, min.len = 1, any.missing = FALSE)

  branch <- tryCatch(gert::git_branch(), error = function(e) NA_character_)

  if (!is.na(branch) && branch == "main") {
    cli::cli_abort(c(
      "Cannot run test export on main branch!",
      "i" = "Switch to develop or a feature branch: {.code git checkout develop}"
    ))
  }

  cli::cli_rule("TEST Mode: Pipeline Export")
  cli::cli_alert_warning("Testing on branch: {branch}")

  orchestratePipelineExport(
    pipelineVersion = pipelineVersion,
    dbIds = dbIds,
    resultsPath = resultsPath,
    exportPath = exportPath,
    cohortsFolderPath = cohortsFolderPath,
    testMode = TRUE
  )
}
