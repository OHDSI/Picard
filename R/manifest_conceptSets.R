
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
                                   executionSettings = NULL) {
  checkmate::assert_class(executionSettings, "ExecutionSettings", null.ok = TRUE)
  dbPath <- fs::path(conceptSetsFolderPath, "conceptSetManifest.sqlite")
  concept_set_entries <- list()

  # Check if database already exists and has entries
  if (file.exists(dbPath)) {
    conn <- DBI::dbConnect(RSQLite::SQLite(), dbPath)
    on.exit(DBI::dbDisconnect(conn))

    # Query existing concept sets from database
    existing_concept_sets <- DBI::dbGetQuery(
      conn,
      "SELECT id, label, tags, filePath, hash FROM concept_set_manifest"
    )

    # Only load from manifest if it has entries
    if (nrow(existing_concept_sets) > 0) {
      cli::cli_alert_info("Loading concept sets from existing manifest: {dbPath}")

      # Process each concept set from database
      for (i in seq_len(nrow(existing_concept_sets))) {
        record <- existing_concept_sets[i, ]
        label <- record$label
        # Resolve stored path to absolute so checks work regardless of working directory
        file_path <- fs::path_abs(record$filePath)
        stored_hash <- record$hash
        tags_string <- record$tags
        concept_set_id <- record$id

        # Check if file still exists
        if (!file.exists(file_path)) {
          cli::cli_alert_warning("Concept set file missing (will be marked): {record$label} ({record$filePath})")
          # Don't skip - we'll track this in the database with status='missing'
          # For now, skip it from loading into memory but it will be in the database
          next
        }

        tryCatch({
          # Create ConceptSetDef from file (this computes current hash)
          concept_set_def <- ConceptSetDef$new(
            label = label,
            filePath = file_path
        )

          # Set the ID from the database to preserve it
          concept_set_def$setId(as.integer(concept_set_id))

          # Backfill tags from database
          if (!is.na(tags_string) && tags_string != "") {
            parsed_tags <- parseTagsString(tags_string)
            concept_set_def$tags <- parsed_tags
          }

          concept_set_entries[[length(concept_set_entries) + 1]] <- concept_set_def
        }, error = function(e) {
          cli::cli_alert_danger("Error loading concept set {record$label}: {e$message}")
        })
      }

      if (length(concept_set_entries) > 0) {
        cli::cli_alert_success("Loaded {length(concept_set_entries)} concept sets from manifest")
        # Successfully loaded from manifest; now check for new files added manually since
        # the manifest was last created (mirrors loadCohortManifest incremental discovery)
        json_dir <- fs::path(conceptSetsFolderPath, "json")
        all_files <- character(0)

        if (dir.exists(json_dir)) {
          all_files <- list.files(json_dir, pattern = "\\.json$", full.names = TRUE, recursive = TRUE)
        }

        # Compare normalized relative paths against stored manifest file paths
        existing_file_paths <- existing_concept_sets$filePath
        new_files_mask <- !(fs::path_rel(all_files) %in% existing_file_paths)
        new_files <- all_files[new_files_mask]

        if (length(new_files) > 0) {
          cli::cli_alert_info("Found {length(new_files)} new concept set file(s) not in manifest")

          for (file_path in new_files) {
            label <- tools::file_path_sans_ext(basename(file_path))
            tryCatch({
              new_cs_def <- ConceptSetDef$new(label = label, filePath = file_path)
              concept_set_entries[[length(concept_set_entries) + 1]] <- new_cs_def
              cli::cli_alert_success("Added new concept set from file: {label}")
            }, error = function(e) {
              cli::cli_alert_warning("Error adding new concept set {label}: {e$message}")
            })
          }
        }
      } else {
        # Database had entries but none could be loaded, fall through to scan directories
        cli::cli_alert_warning("No valid concept sets could be loaded from manifest. Scanning directories...")
        concept_set_entries <- list()  # Reset to empty for directory scan
      }
    } else {
      # Manifest exists but is empty, scan directories
      cli::cli_alert_warning("Manifest exists but contains no concept set entries. Scanning directories...")
    }
  }

  # If no concept sets loaded from manifest (or manifest didn't exist), scan directories
  if (length(concept_set_entries) == 0) {
    cli::cli_alert_info("Scanning concept set directories...")

    # Define directory to search
    json_dir <- fs::path(conceptSetsFolderPath, "json")

    # Process JSON directory if it exists
    if (dir.exists(json_dir)) {
      json_files <- list.files(json_dir, pattern = "\\.json$", full.names = TRUE, recursive = TRUE)

      for (file_path in json_files) {
        label <- tools::file_path_sans_ext(basename(file_path))
        tryCatch({
          concept_set_def <- ConceptSetDef$new(
            label = label,
            filePath = file_path
        )
          concept_set_entries[[length(concept_set_entries) + 1]] <- concept_set_def
          cli::cli_alert_success("Loaded concept set: {label}")
        }, error = function(e) {
          cli::cli_alert_danger("Error loading concept set {label}: {e$message}")
        })
      }
    }

    if (length(concept_set_entries) == 0) {
      stop("No concept set files found in conceptSets/json directory")
    }

    cli::cli_alert_success("Found {length(concept_set_entries)} total concept sets")
  }

  # Check for conceptSetsLoad.csv file to enrich entries with tags and labels
  concept_sets_load_path <- fs::path(conceptSetsFolderPath, "conceptSetsLoad.csv")
  if (file.exists(concept_sets_load_path)) {
    cli::cli_alert_info("Found conceptSetsLoad.csv. Enriching entries with load metadata...")

    tryCatch({
      concept_sets_load <- readr::read_csv(concept_sets_load_path, show_col_types = FALSE)

      # Validate required columns (label is optional)
      required_cols <- c("file_name", "atlasId", "category", "subCategory", "domain", "sourceCode")
      missing_cols <- setdiff(required_cols, names(concept_sets_load))

      if (length(missing_cols) == 0) {
        # Process each concept set entry to find matching load record
        tags_added <- 0
        labels_updated <- 0
        for (i in seq_along(concept_set_entries)) {
          entry <- concept_set_entries[[i]]
          entry_filepath_rel <- fs::path_rel(entry$getFilePath())

          # Find matching record in conceptSetsLoad by file_name
          matching_idx <- which(entry_filepath_rel == concept_sets_load$file_name)

          if (length(matching_idx) > 0) {
            load_record <- concept_sets_load[matching_idx[1], ]

            # Update label if provided in conceptSetsLoad.csv
            if ("label" %in% names(concept_sets_load) && !is.na(load_record$label)) {
              entry$label <- as.character(load_record$label)
              labels_updated <- labels_updated + 1
            }

            # Add tags from load record
            entry_tags <- list()
            if (!is.na(load_record$atlasId)) {
              entry_tags[["atlasId"]] <- as.character(load_record$atlasId)
            }
            if (!is.na(load_record$domain)) {
              entry_tags[["domain"]] <- as.character(load_record$domain)
            }
            if (!is.na(load_record$category)) {
              entry_tags[["category"]] <- as.character(load_record$category)
            }
            if (!is.na(load_record$sourceCode)) {
              entry_tags[["sourceCode"]] <- as.character(load_record$sourceCode)
            }
            if (!is.na(load_record$subCategory)) {
              entry_tags[["subCategory"]] <- as.character(load_record$subCategory)
            }

            if (length(entry_tags) > 0) {
              entry$tags <- entry_tags
              tags_added <- tags_added + 1
              cli::cli_alert_success("Added metadata to concept set: {entry$label}")
            }
          }
        }

        cli::cli_alert_success("Updated {labels_updated} labels and added tags to {tags_added} concept set entries from conceptSetsLoad.csv")
      } else {
        cli::cli_alert_warning("conceptSetsLoad.csv is missing required columns: {paste(missing_cols, collapse = ', ')}")
      }
    }, error = function(e) {
      cli::cli_alert_danger("Error reading conceptSetsLoad.csv: {e$message}")
    })
  }

  # Create and return the ConceptSetManifest
  manifest <- ConceptSetManifest$new(
    conceptSetEntries = concept_set_entries,
    executionSettings = executionSettings,
    dbPath = dbPath
  )

  # Detect and alert about missing concept sets using the public validateManifest() method
  validation_status <- manifest$validateManifest()
  missing_conceptsets <- validation_status[validation_status$status == "active" & !validation_status$file_exists, ]

  if (nrow(missing_conceptsets) > 0) {
    cli::cli_rule("Missing Concept Set Files Detected")
    cli::cli_alert_warning("{nrow(missing_conceptsets)} concept set file(s) are missing:")

    for (i in seq_len(nrow(missing_conceptsets))) {
      cs_info <- missing_conceptsets[i, ]
      cli::cli_bullets(c(
        "x" = "ID {cs_info$id}: {cs_info$label}"
      ))
    }

    cli::cli_rule()
    cli::cli_bullets(c(
      i = "Use {.code manifest$validateManifest()} to see full status",
      i = "Use {.code manifest$cleanupMissing()} to remove missing concept sets",
      i = "Or restore the missing files and reload"
    ))
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
    "Open {.file conceptSetsLoad.csv} in Excel or your text editor",
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
#' @examples
#' \dontrun{
#'   # Launch the concept set load editor
#'   launchConceptSetsLoadEditor()
#' }
#'
launchConceptSetsLoadEditor <- function(conceptSetsFolderPath = here::here("inputs/conceptSets")) {
  # Check if Shiny is installed
  if (!requireNamespace("shiny", quietly = TRUE)) {
    stop("The 'shiny' package is required to use this function. Install it with: install.packages('shiny')")
  }
  if (!requireNamespace("DT", quietly = TRUE)) {
    stop("The 'DT' package is required to use this function. Install it with: install.packages('DT')")
  }

  # Try to load existing conceptSetsLoad.csv
  existing_load <- NULL
  load_path <- fs::path(conceptSetsFolderPath, "conceptSetsLoad.csv")
  if (file.exists(load_path)) {
    existing_load <- readr::read_csv(load_path, show_col_types = FALSE)
    
    # Ensure file_name column exists; generate if missing
    if (!"file_name" %in% names(existing_load)) {
      existing_load$file_name <- fs::path("json", paste0(existing_load$label, ".json"))
    }
    
    # Ensure columns are in the correct order
    existing_load <- existing_load[, c("atlasId", "label", "category", "subCategory", "sourceCode", "domain", "file_name")]
  }

  # Create the Shiny app
  app <- shiny::shinyApp(
    ui = function() {
      shiny::fluidPage(
        shiny::titlePanel("Concept Set Load File Editor"),
        shiny::sidebarLayout(
          shiny::sidebarPanel(
            shiny::h4("Add New Concept Set"),
            shiny::numericInput("atlas_id", "ATLAS ID:", value = NA, min = 1),
            shiny::textInput("label", "Label:", ""),
            shiny::textInput("category", "Category:", ""),
            shiny::textInput("sub_category", "Sub-Category (optional):", ""),
            shiny::textInput("source_code", "Source Code (TRUE/FALSE):", ""),
            shiny::selectInput("domain", "Domain:", choices = c("","drug_exposure", "condition_occurrence", "measurement", "procedure")),
            shiny::actionButton("add_row", "Add Concept Set", class = "btn-primary"),
            shiny::hr(),
            shiny::h4("Actions"),
            shiny::actionButton("delete_rows", "Delete Selected Rows", class = "btn-danger"),
            shiny::hr(),
            shiny::h4("Templates"),
            shiny::downloadButton("download_template", "Download Blank Template", class = "btn-info"),
            shiny::hr(),
            shiny::actionButton("save_file", "Save Concept Set Load File", class = "btn-success"),
            shiny::actionButton("cancel", "Cancel", class = "btn-secondary")
          ),
          shiny::mainPanel(
            DT::DTOutput("concept_set_table"),
            shiny::br(),
            shiny::uiOutput("status_message")
          )
        )
      )
    },
    server = function(input, output, session) {
      # Reactive values to store the data
      rv <- shiny::reactiveValues(
        data = if (!is.null(existing_load)) existing_load else data.frame(
          atlasId = integer(),
          label = character(),
          category = character(),
          subCategory = character(),
          sourceCode = logical(),
          domain = character(),
          file_name = character(),
          stringsAsFactors = FALSE
        ),
        message = NULL,
        message_type = NULL
      )

      # Display the data table
      output$concept_set_table <- DT::renderDT({
        DT::datatable(
          rv$data,
          editable = list(target = "cell", disable = list(columns = 5)),
          selection = "multiple",
          rownames = FALSE,
          options = list(pageLength = 10)
        )
      })

      # Handle table edits
      shiny::observeEvent(input$concept_set_table_cell_edit, {
        info <- input$concept_set_table_cell_edit
        rv$data[info$row, info$col] <- info$value

        # Update file_name automatically if label (column 2) changed
        if (info$col == 2) {
          rv$data$file_name[info$row] <- fs::path("json", paste0(info$value, ".json"))
          rv$message <- "Label updated - file_name auto-generated"
          rv$message_type <- "info"
        }
      })

      # Add new concept set
      shiny::observeEvent(input$add_row, {
        # Validate inputs
        if (is.na(input$atlas_id) || input$atlas_id == "") {
          rv$message <- "ATLAS ID is required"
          rv$message_type <- "danger"
          return()
        }
        if (input$label == "") {
          rv$message <- "Label is required"
          rv$message_type <- "danger"
          return()
        }
        if (input$category == "") {
          rv$message <- "Category is required"
          rv$message_type <- "danger"
          return()
        }
        if (input$domain == "") {
          rv$message <- "Domain is required"
          rv$message_type <- "danger"
          return()
        }

        # Add row
        new_row <- data.frame(
          atlasId = as.integer(input$atlas_id),
          label = input$label,
          category = input$category,
          subCategory = if (input$sub_category == "") NA_character_ else input$sub_category,
          sourceCode = input$source_code, 
          domain = input$domain,
          file_name = fs::path("json", paste0(input$label, ".json")),
          stringsAsFactors = FALSE
        )

        rv$data <- rbind(rv$data, new_row)
        rv$message <- paste("Added concept set:", input$label)
        rv$message_type <- "success"

        # Clear inputs
        shiny::updateNumericInput(session, "atlas_id", value = NA)
        shiny::updateTextInput(session, "label", value = "")
        shiny::updateTextInput(session, "category", value = "")
        shiny::updateTextInput(session, "sub_category", value = "")
        shiny::updateTextInput(session, "source_code", value = "")
        shiny::updateSelectInput(session, "domain", selected = "")
      })

      # Delete selected rows
      shiny::observeEvent(input$delete_rows, {
        selected <- input$concept_set_table_rows_selected
        if (length(selected) == 0) {
          rv$message <- "No rows selected"
          rv$message_type <- "warning"
        } else {
          deleted_labels <- rv$data$label[selected]
          rv$data <- rv$data[-selected, ]
          rv$message <- paste("Deleted", length(selected), "concept set(s):", paste(deleted_labels, collapse = ", "))
          rv$message_type <- "info"
        }
      })

      # Save file
      shiny::observeEvent(input$save_file, {
        if (nrow(rv$data) == 0) {
          rv$message <- "Cannot save: No concept sets in table"
          rv$message_type <- "danger"
          return()
        }

        fs::dir_create(conceptSetsFolderPath)
        save_path <- fs::path(conceptSetsFolderPath, "conceptSetsLoad.csv")
        readr::write_csv(rv$data, file = save_path)

        rv$message <- paste("Concept Set Load file saved successfully!\nLocation:", fs::path_rel(save_path))
        rv$message_type <- "success"

        shiny::showNotification(
          paste("Saved", nrow(rv$data), "concept sets to conceptSetLoad.csv"),
          type = "message",
          duration = 3
        )
      })

      # Download blank template
      output$download_template <- shiny::downloadHandler(
        filename = function() {
          paste0("conceptSetsLoad_template_", format(Sys.Date(), "%Y%m%d"), ".csv")
        },
        content = function(file) {
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
          readr::write_csv(template, file = file)
        }
      )

      # Cancel
      shiny::observeEvent(input$cancel, {
        shiny::stopApp()
      })

      # Display status message
      output$status_message <- shiny::renderUI({
        if (!is.null(rv$message)) {
          class_name <- switch(rv$message_type,
            success = "alert alert-success",
            danger = "alert alert-danger",
            warning = "alert alert-warning",
            info = "alert alert-info"
          )
          shiny::div(class = class_name, HTML(gsub("\n", "<br/>", rv$message)))
        }
      })

      # Stop app on session end
      shiny::onSessionEnded(function() {
        shiny::stopApp()
      })
    }
  )

  shiny::runApp(app)
  invisible(NULL)

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
  conceptSetLoadPath <- fs::path(conceptSetsFolderPath, "conceptSetsLoad.csv")

  # Read concept set load CSV file
  if (!file.exists(conceptSetLoadPath)) {
    stop("Concept set load file not found: ", conceptSetLoadPath)
  }

  concept_set_load <- readr::read_csv(conceptSetLoadPath, show_col_types = FALSE)

  # Validate required columns
  required_cols <- c("atlasId", "label", "domain", "sourceCode")
  missing_cols <- setdiff(required_cols, names(concept_set_load))

  if (length(missing_cols) > 0) {
    stop("Concept set load is missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  # Initialize file_name column
  concept_set_load$file_name <- NA_character_

  cli::cli_alert_info("Importing {nrow(concept_set_load)} concept sets from ATLAS...")

  # Process each concept set
  for (i in seq_len(nrow(concept_set_load))) {
    atlas_id <- concept_set_load$atlasId[i]
    label <- concept_set_load$label[i]
    domain <- concept_set_load$domain[i]
    source_code <- concept_set_load$sourceCode[i]

    # Skip rows with missing atlasId
    if (is.na(atlas_id)) {
      cli::cli_alert_warning("Row {i}: Skipping concept set with missing atlasId")
      next
    }

    tryCatch({
      # Get concept set definition from ATLAS
      cli::cli_alert_info("Fetching concept set {atlas_id}: {label}...")
      cs_def <- atlasConnection$getConceptSetDefinition(conceptSetId = atlas_id)

      # Extract expression
      cs_expression <- cs_def$expression[1]

      # Extract concept set name from definition (fallback to label if not available)
      cs_name <- ifelse(!is.null(cs_def$saveName[1]) && cs_def$saveName[1] != "",
        cs_def$saveName[1], label
      )

      # Ensure output folder exists
      outputFolder <- fs::path(conceptSetsFolderPath, "json")
      fs::dir_create(outputFolder)

      # Create file name from cs_name (make it file-system friendly)
      file_name <- fs::path(outputFolder, cs_name, ext = "json")

      # Write concept set JSON to file
      readr::write_file(cs_expression, file = file_name)

      # Store the relative file name in the data frame
      concept_set_load$file_name[i] <- fs::path_rel(file_name)

      cli::cli_alert_success(
        "Imported concept set {crayon::magenta(cs_name)} (ID: {atlas_id}) to {crayon::cyan(fs::path_rel(outputFolder))}"
      )
    }, error = function(e) {
      cli::cli_alert_danger(
        "Error importing concept set {label} (ID: {atlas_id}): {e$message}"
      )
    })
  }

  # Save the updated concept_set_load file with file_name column
  readr::write_csv(concept_set_load, file = conceptSetLoadPath)
  cli::cli_alert_success("Updated concept set load file saved to: {fs::path_rel(conceptSetLoadPath)}")

  cli::cli_alert_success("ATLAS concept set import complete")
  invisible(concept_set_load)
}