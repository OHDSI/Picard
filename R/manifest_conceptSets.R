
#' Initialize a New Concept Set Manifest
#'
#' Creates a blank `conceptSetManifest.sqlite` database with the new schema.
#' Directory creation (`json/`) is handled by the study repo
#' initialization (see `listDefaultFolders()` in `R/Ulysses.R`).
#'
#' @param path Character. Path to the conceptSets folder where the SQLite file will be created.
#'   Defaults to `"inputs/conceptSets"`.
#'
#' @return A `ConceptSetManifest` R6 object (empty, ready for `$add*()` calls).
#'
#' @export
initConceptSetManifest <- function(path = "inputs/conceptSets") {
  dbPath <- fs::path(path, "conceptSetManifest.sqlite")

  if (file.exists(dbPath)) {
    cli::cli_alert_warning("Manifest already exists at {fs::path_rel(dbPath)}.")
    cli::cli_alert_info("Use loadConceptSetManifest() to load the existing manifest.")
    cli::cli_alert_info("Use resetConceptSetManifest() to delete and start fresh.")
    return(invisible(NULL))
  }

  # Ensure directory exists
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }

  csm <- ConceptSetManifest$new(dbPath = dbPath)
  cli::cli_alert_success("Initialized empty concept set manifest at {fs::path_rel(dbPath)}")
  cli::cli_alert_info("Add concept sets with $addConceptSetFile(), $addAtlasConceptSet(), $addCaprConceptSet(), or $importAtlasConceptSets()")

  return(csm)
}


#' Load Concept Set Manifest
#'
#' Loads or creates a concept set manifest from CIRCE JSON files located in the
#' inputs/conceptSets/json folder. The manifest is stored in an SQLite database
#' for efficient querying and metadata persistence. ExecutionSettings are optional
#' and only required if you plan to extract source codes or access vocabularies.
#'
#' @param conceptSetsFolderPath Character. Path to the conceptSets folder containing the manifest
#'   database. Defaults to "inputs/conceptSets".
#' @param executionSettings ExecutionSettings object. Optional. Defaults to NULL. 
#'   Only required for operations like extractSourceCodes(). You can add settings later 
#'   using setExecutionSettings() on the returned ConceptSetManifest object.
#' @param verbose Logical. If TRUE (default), prints informative messages about the
#'   loading process and any issues encountered. Set to FALSE to suppress routine
#'   output; file-level errors inside tryCatch handlers are always shown.
#'
#' @return ConceptSetManifest object containing all loaded concept sets with metadata.
#'
#' @details
#' **Workflow:**
#' 1. Checks if conceptSetManifest.sqlite database exists
#' 2. If it exists, loads concept set entries from the json/ directory using cached metadata
#' 3. If not, scans the json/ directory for CIRCE JSON files
#' 4. Creates ConceptSetDef objects for each JSON file
#' 5. Enriches metadata from conceptSetsLoad.csv if available
#' 6. Returns a ConceptSetManifest object
#'
#' **Metadata CSV Format:**
#' The conceptSetsLoad.csv file (optional) should contain:
#' - `file_name`: Relative path to JSON file (e.g., "conceptSet1.json")
#' - `label`: Display name for the concept set
#' - `atlasId`: ATLAS concept set ID
#' - `domain`: OMOP domain classification
#' - `sourceCode`: Whether the concept set represents source codes
#'
#' **Post-Load:**
#' After loading, use manifest methods to query concept sets:
#' - `queryConceptSetsByIds(ids)` - Query by one or more IDs; returns data frame
#' - `queryConceptSetsByTag(tagStrings, match)` - Query by tag(s); returns data frame
#' - `queryConceptSetsByLabel(labels, matchType)` - Query by label(s); returns data frame
#' - `getConceptSetById(id)` - Get ConceptSetDef object by ID
#' - `getConceptSetsByTag(tagStrings, match)` - Get ConceptSetDef objects by tag(s)
#' - `tabulateManifest()` - Tabular view of all concept sets
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   # Load concept set manifest (no settings required for metadata review)
#'   manifest <- loadConceptSetManifest()
#'   
#'   # Or load from custom path
#'   manifest <- loadConceptSetManifest(conceptSetsFolderPath = "path/to/conceptsets")
#'   
#'   # Add execution settings later if needed for source code extraction
#'   settings <- createExecutionSettings(
#'     connectionString = "Server=localhost;Database=mydb"
#'   )
#'   manifest$setExecutionSettings(settings)
#'   manifest$extractSourceCodes(sourceVocabs = c("ICD10CM"))
#' }
#'
loadConceptSetManifest <- function(conceptSetsFolderPath = here::here("inputs/conceptSets"),
                                   executionSettings = NULL,
                                   verbose = TRUE) {
  checkmate::assert_class(executionSettings, "ExecutionSettings", null.ok = TRUE)
  checkmate::assert_logical(verbose, len = 1)
  dbPath <- fs::path(conceptSetsFolderPath, "conceptSetManifest.sqlite")

  # Create manifest (initializes DB schema, loads active entries from SQLite)
  manifest <- ConceptSetManifest$new(dbPath = dbPath, executionSettings = executionSettings)

  # Discover JSON files in json/ that are not yet registered in the manifest
  json_dir <- fs::path(conceptSetsFolderPath, "json")

  if (dir.exists(json_dir)) {
    on_disk <- list.files(json_dir, pattern = "\\.json$", full.names = TRUE, recursive = TRUE)

    if (length(on_disk) > 0) {
      # Check which on-disk files are not in the manifest DB
      conn <- DBI::dbConnect(RSQLite::SQLite(), dbPath)
      on.exit(DBI::dbDisconnect(conn))

      registered_paths <- DBI::dbGetQuery(
        conn,
        "SELECT filePath FROM concept_set_manifest WHERE status = 'active'"
      )$filePath

      new_files <- on_disk[!(fs::path_rel(on_disk) %in% registered_paths)]

      if (length(new_files) > 0) {
        if (verbose) {
          cli::cli_alert_info("Registering {length(new_files)} new concept set file(s) found in {fs::path_rel(json_dir)}")
        }

        for (file_path in new_files) {
          label <- tools::file_path_sans_ext(basename(file_path))
          tryCatch({
            manifest$addConceptSetFile(filePath = file_path, label = label)
          }, error = function(e) {
            cli::cli_alert_warning("Skipping {label}: {e$message}")
          })
        }
      }
    }
  }

  # Alert about any active records whose files are missing
  if (verbose) {
    validation_status <- manifest$validateManifest()
    missing_conceptsets <- validation_status[
      !is.na(validation_status$status) &
        validation_status$status == "active" &
        !validation_status$file_exists,
    ]

    if (nrow(missing_conceptsets) > 0) {
      cli::cli_rule("Missing Concept Set Files Detected")
      cli::cli_alert_warning("{nrow(missing_conceptsets)} concept set file(s) are missing:")

      for (i in seq_len(nrow(missing_conceptsets))) {
        cs_info <- missing_conceptsets[i, ]
        cli::cli_bullets(c("x" = "ID {cs_info$id}: {cs_info$label}"))
      }

      cli::cli_rule()
      cli::cli_bullets(c(
        "i" = "Use {.code manifest$validateManifest()} to see full status",
        "i" = "Use {.code manifest$cleanupMissing()} to remove missing concept sets",
        "i" = "Or restore the missing files and reload"
      ))
    }
  }

  return(manifest)
}



#' Reset Concept Set Manifest Database
#'
#' Deletes the conceptSetManifest.sqlite database file. Use this function when you need
#' to reset the manifest and rebuild it from the available concept set files.
#'
#' @param conceptSetsFolderPath Character. Path to the conceptSets folder containing the manifest
#'   database. Defaults to "inputs/conceptSets".
#'
#' @return Invisibly returns NULL. Deletes the manifest file and prints status messages.
#'
#' @details
#' This function is useful for:
#' - Starting fresh with a new set of concept sets
#' - Clearing cached manifest data
#' - Resolving manifest corruption issues
#'
#' After resetting, call [loadConceptSetManifest()] to rebuild the manifest from
#' the available concept set files in the json/ subdirectory.
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   # Reset the manifest
#'   resetConceptSetManifest()
#'
#'   # Rebuild it (with or without settings)
#'   manifest <- loadConceptSetManifest()
#' }
#'
resetConceptSetManifest <- function(conceptSetsFolderPath = here::here("inputs/conceptSets")) {
  dbPath <- fs::path(conceptSetsFolderPath, "conceptSetManifest.sqlite")

  if (file.exists(dbPath)) {
    file.remove(dbPath)
    cli::cli_alert_success("Concept set manifest database deleted: {fs::path_rel(dbPath)}")
    cli::cli_alert_info("To rebuild the manifest, call loadConceptSetManifest() with your ExecutionSettings")
  } else {
    cli::cli_alert_warning("Concept set manifest database not found at: {fs::path_rel(dbPath)}")
  }

  invisible(NULL)
}




#' Create Blank Concept Sets Load File
#'
#' Creates a blank conceptSetsLoad.csv template file in the specified folder
#' with proper column structure. Users can fill this file manually in Excel,
#' Google Sheets, or any text editor, then place it in the inputs/conceptSets folder.
#'
#' @param conceptSetsFolderPath Character. Path where the blank file will be created.
#'   Defaults to "inputs/conceptSets". Creates the folder if it doesn't exist.
#'
#' @return Invisibly returns the file path. Prints informative messages with tips.
#'
#' @details
#' **Column Guide:**
#' - `atlasId` (numeric): The ATLAS concept set ID. Get this from ATLAS > Concept Sets
#' - `label` (character): Display name for your concept set (e.g., "Hypertension diagnoses")
#' - `category` (character): Broad grouping category (e.g., "Cardiovascular", "Medications")
#' - `subCategory` (character): Optional sub-grouping within category
#' - `sourceCode` (TRUE/FALSE): Whether this represents source codes (rarely TRUE for concept sets)
#' - `domain` (character): OMOP domain - must be one of:
#'   - `drug_exposure` - medication concept sets
#'   - `condition_occurrence` - diagnosis concept sets
#'   - `measurement` - lab/measurement concept sets
#'   - `procedure` - procedure concept sets
#'   - `observation` - observation concept sets
#'   - `visit_occurrence` - visit type concept sets
#' - `file_name` (character): Path to JSON file (e.g., "json/hypertension.json"). Note this is a placeholder will be replaced when you import from ATLAS.
#'
#' **Tips for Filling Out:**
#' 1. Each row represents one concept set
#' 2. Use forward slashes (/) in file paths
#' 3. Ensure file_name matches the JSON files you'll import from ATLAS
#' 4. domain field is critical for vocabulary suggestions in extractSourceCodes()
#' 6. Save as UTF-8 CSV when exporting from Excel to avoid encoding issues
#'
#' **Workflow:**
#' 1. Call this function to create blank template
#' 2. Open conceptSetsLoad.csv in your preferred spreadsheet application
#' 3. Fill in your concept set metadata
#' 4. Save the file
#' 5. Use [importAtlasConceptSets()] to import the actual JSON definitions from ATLAS
#' 6. Use [loadConceptSetManifest()] to load into your study
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   # Create blank template in default location
#'   createBlankConceptSetsLoadFile()
#'   # File created at: inputs/conceptSets/conceptSetsLoad.csv
#' }
#'
createBlankConceptSetsLoadFile <- function(conceptSetsFolderPath = here::here("inputs/conceptSets")) {
  checkmate::assert_string(conceptSetsFolderPath)
  
  # Create directory if it doesn't exist
  fs::dir_create(conceptSetsFolderPath)
  
  # Create blank template with proper structure
  template <- data.frame(
    atlasId = integer(1),
    label = character(1),
    category = character(1),
    subCategory = character(1),
    sourceCode = character(1),
    domain = character(1),
    file_name = character(1),
    stringsAsFactors = FALSE
  )
  
  file_path <- fs::path(conceptSetsFolderPath, "conceptSetsLoad.csv")
  readr::write_csv(template, file = file_path)
  
  # Print informative messages
  cli::cli_rule("Blank Concept Sets Load File Created")
  cli::cli_text("File created at: {.file {fs::path_rel(file_path)}}")
  cli::cli_text("")
  cli::cli_h3("Column Guide:")
  cli::cli_ul(c(
    "{.field atlasId} - ATLAS concept set ID (numeric)",
    "{.field label} - Display name (e.g., 'Hypertension diagnoses')",
    "{.field category} - Broad category (e.g., 'Cardiovascular')",
    "{.field subCategory} - Optional sub-grouping",
    "{.field sourceCode} - TRUE/FALSE (usually FALSE for concept sets)",
    "{.field domain} - One of: drug_exposure, condition_occurrence, measurement, procedure, observation, visit_occurrence",
    "{.field file_name} - Path to JSON file (e.g., 'json/hypertension.json'). Note this is a placeholder will be replaced when you import from ATLAS."
  ))
  cli::cli_text("")
  cli::cli_h3("Tips for Filling Out:")
  cli::cli_ul(c(
    "Each row = one concept set",
    "Use forward slashes (/) in file paths",
    "{.emph domain} field is critical for vocabulary suggestions",
    "Save as UTF-8 CSV from Excel to avoid encoding issues"
  ))
  cli::cli_text("")
  cli::cli_h3("Next Steps:")
  cli::cli_ol(c(
    "Open {.file inputs/conceptSets/conceptSetsLoad.csv} in Excel or your text editor",
    "Fill in your concept set metadata",
    "Save the file",
    "Use {.code importAtlasConceptSets()} to import JSON definitions from ATLAS",
    "Use {.code loadConceptSetManifest()} to load into your study"
  ))
  
  invisible(file_path)
}

#' Launch Interactive Concept Set Load Editor
#'
#' Opens an interactive Shiny application for creating, viewing and editing the concept
#' sets load metadata file (conceptSetsLoad.csv). This allows you to add, remove,
#' and modify concept set metadata including labels, tags, domain, and ATLAS IDs
#' without manually editing the CSV file.
#'
#'
#' @param conceptSetsFolderPath Character. Path to conceptSets folder where conceptSetsLoad.csv
#'   will be saved. Defaults to "inputs/conceptSets".
#'
#' @return Invisibly launches a Shiny app. Saves conceptSetsLoad.csv when the user user clicks "Save".
#'
#' @details
#' **Features:**
#' - View existing concept sets in a data table
#' - Edit cells directly in the table
#' - Add new concept sets rows with form inputs
#' - Delete selected rows
#' - Save to conceptSetsLoad.csv
#' - Input validation for required fields
#'
#' **Table Columns:**
#' - `atlasId`: ATLAS cohort definition ID (numeric)
#' - `label`: Cohort name/label (character) - editing updates file_name automatically
#' - `category`: Broad category (character)
#' - `subCategory`: Sub-category (character)
#' - `sourceCode`: Whether this concept set represents source codes (TRUE/FALSE)
#' - `domain`: OMOP domain (drug_exposure, condition_occurrence, measurement, procedure)
#' - `file_name`: Auto-generated as `json/{label}.json` (read-only)
#'
#' **Workflow:**
#' 1. Call this function to launch the editor app
#' 2. Add/edit concept sets as needed
#' 3. Click "Save Concept Set Load File" to save to inputs/conceptSets/conceptSetsLoad.csv
#' 4. Use [importAtlasConceptSets()] to import conceptSets from ATLAS
#' 5. Use [loadConceptSetManifest()] to load the imported conceptSets
#' @export
#'
#' @keywords internal
#' @noRd
launchConceptSetsLoadEditor <- function(conceptSetsFolderPath = here::here("inputs/conceptSets")) {
  lifecycle::deprecate_soft(
    when = "3.0.0",
    what = "launchConceptSetsLoadEditor()",
    details = c(
      "The interactive Shiny editor has been discontinued.",
      i = "To create concept set metadata, use this workflow:",
      "  1. Run createBlankConceptSetsLoadFile() to create a template",
      "  2. Edit inputs/conceptSets/conceptSetsLoad.csv directly in Excel",
      "  3. Use conceptSetManifest$importAtlasConceptSets() to import"
    )
  )
}


#' Import CIRCE Concept Sets from ATLAS
#'
#' Imports CIRCE JSON concept set definitions from an ATLAS WebAPI instance and
#' saves them to the inputs/conceptSets/json folder. This function reads a CSV file
#' containing concept set metadata and fetches the actual concept set definitions
#' from ATLAS.
#'
#' @description This function looks for a CSV file called conceptSetsLoad.csv
#'   containing concept set metadata. Must be located in or accessible from the
#'   inputs/conceptSets folder. The CSV must have the following columns:
#'   - `atlasId`: ATLAS concept set definition ID (integer)
#'   - `label`: Concept set name/label (character)
#'   - `domain`: OMOP domain (drug_exposure, condition_occurrence, measurement, procedure)
#'   - `sourceCode`: Whether the concept set represents source codes (logical)
#'
#' The function will read this CSV, fetch the concept set definitions from ATLAS
#' using the provided atlasConnection, extract the CIRCE JSON expressions, and
#' save them to the specified output folder with filenames based on the label.
#' Finally it updates the concept set load CSV with the relative file paths to
#' the saved JSON files.
#'
#' @param conceptSetsFolderPath Character. Path to conceptSets folder in the project.
#'
#' @param atlasConnection An ATLAS connection object (typically from ROhdsiWebApi
#'   package) with a method `getConceptSetDefinition(conceptSetId)` that returns
#'   a list containing an `expression` element with the CIRCE JSON string.
#'
#' @param outputFolder Character. Path to the output folder where concept set JSON
#'   files will be saved. Defaults to inputs/conceptSets/json. Files are saved as
#'   `{label}.json`.
#'
#' @return Invisibly returns the updated concept set load dataframe. Saves CIRCE
#'   JSON files to outputFolder and prints status messages via cli alerts.
#'
#' @details
#' **Workflow:**
#' 1. Reads the concept set load CSV file
#' 2. Validates that all required columns are present
#' 3. For each row with a valid atlasId:
#'    - Fetches the concept set definition from ATLAS WebAPI
#'    - Extracts the CIRCE JSON expression
#'    - Saves to `outputFolder/{label}.json`
#' 4. Skips rows with missing atlasId with a warning
#' 5. Catches and reports errors per concept set without stopping the entire import
#'
#' **Post-Import:**
#' After running this function, use [loadConceptSetManifest()] to load the saved
#' concept set JSON files and build the manifest with metadata.
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   # Assuming ATLAS connection is set up
#'   importAtlasConceptSets(
#'     conceptSetsFolderPath = here::here("inputs/conceptSets"),
#'     atlasConnection = setAtlasConnection()
#'   )
#'
#'   # Then load the manifest
#'   manifest <- loadConceptSetManifest(
#'     conceptSetsFolderPath = here::here("inputs/conceptSets")
#'   )
#' }
#'
importAtlasConceptSets <- function(conceptSetsFolderPath = here::here("inputs/conceptSets"),
                                    atlasConnection) {
  lifecycle::deprecate_warn(
    when = "0.1.0",
    what = "importAtlasConceptSets()",
    details = c(
      "i" = "Use ConceptSetManifest$importAtlasConceptSets() instead:",
      "i" = "  manifest <- ConceptSetManifest$new(dbPath = '...')",
      "i" = "  manifest$importAtlasConceptSets(atlasConnection)"
    )
  )

  dbPath <- fs::path(conceptSetsFolderPath, "conceptSetManifest.sqlite")
  manifest <- ConceptSetManifest$new(dbPath = dbPath)
  conceptSetsLoadPath <- fs::path(conceptSetsFolderPath, "conceptSetsLoad.csv")
  result <- manifest$importAtlasConceptSets(
    atlasConnection = atlasConnection,
    conceptSetsLoadPath = conceptSetsLoadPath
  )

  return(invisible(result))
}