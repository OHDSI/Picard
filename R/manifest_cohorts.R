#' Load Cohort Manifest from Database or Cohort Files
#'
#' Loads a CohortManifest R6 object by either reading from an existing
#' cohortManifest.sqlite database or by scanning the inputs/cohorts directories.
#' When a manifest database exists, automatically discovers any new cohort files
#' that have been added to the directories since the manifest was created, allowing
#' for incremental cohort development. ExecutionSettings are optional and only 
#' required if you plan to generate cohorts or retrieve cohort counts. You can load 
#' the manifest without them to review metadata.
#'
#' @param cohortsFolderPath Character. Path to the cohorts folder containing the manifest
#'   database and cohort definition files. Defaults to "inputs/cohorts". The function
#'   will look for:
#'   - `cohortManifest.sqlite` in this folder for existing manifest data
#'   - `json/` subfolder for CIRCE JSON cohort definitions
#'   - `sql/` subfolder for SQL cohort definitions
#' @param executionSettings An ExecutionSettings object containing database configuration
#'   for cohort generation. Optional; only required if you plan to generate cohorts or
#'   retrieve cohort counts. Defaults to NULL. You can add settings later using
#'   `setExecutionSettings()` on the returned CohortManifest object.
#'
#' @return A CohortManifest R6 object initialized with all cohorts found.
#'
#' @details
#' **If database exists:**
#' Loads cohort paths and metadata from the cohortManifest.sqlite database,
#' verifies files still exist, checks if any files have changed by comparing
#' the stored hash with the current file hash, and then scans the directories
#' for any NEW cohort files that have been added since the manifest was created.
#' These new files are automatically discovered and added to the manifest.
#'
#' **If database doesn't exist:**
#' Scans `cohortsFolderPath/json` and `cohortsFolderPath/sql` directories to find cohort
#' definition files and creates a new CohortDef for each file with:
#' - label: The basename of the file without extension
#' - tags: Empty list
#' - filePath: The full path to the cohort file
#'
#' **Metadata Enrichment (optional):**
#' If a `cohortsLoad.csv` file exists in `cohortsFolderPath`, the function will
#' automatically enrich CohortDef objects with tags by matching the `file_name`
#' column from the load file with the `filePath` of each entry. For matching entries,
#' tags are added from the following columns:
#' - `atlasId`: Added as an "atlasId" tag
#' - `category`: Added as a "category" tag
#' - `subCategory`: Added as a "subCategory" tag
#'
#' Hash comparison alerts:
#' - **✓ Unchanged**: Hash matches stored value
#' - **⚠ Changed**: Hash differs from stored value (file was modified)
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   # Load manifest for metadata review (no settings required)
#'   manifest <- loadCohortManifest()
#'   
#'   # Or load from custom path
#'   manifest <- loadCohortManifest(cohortsFolderPath = "path/to/cohorts")
#'   
#'   # Add execution settings later if needed for cohort generation
#'   settings <- ExecutionSettings$new(
#'     databaseName = "mydb",
#'     dbms = "postgresql",
#'     connectionDetails = list(...)
#'   )
#'   manifest$setExecutionSettings(settings)
#' }
#'
loadCohortManifest <- function(cohortsFolderPath = here::here("inputs/cohorts"), executionSettings = NULL, verbose = TRUE) {
  dbPath <- fs::path(cohortsFolderPath, "cohortManifest.sqlite")
  cohort_entries <- list()

  # Check if database already exists and has entries
  if (file.exists(dbPath)) {
    conn <- DBI::dbConnect(RSQLite::SQLite(), dbPath)
    on.exit(DBI::dbDisconnect(conn))

    # Check if cohort_manifest table exists
    table_exists <- DBI::dbExistsTable(conn, "cohort_manifest")
    
    if (!table_exists) {
      if (verbose) {
        cli::cli_alert_warning("Database exists but cohort_manifest table not found. Scanning directories...")
      }
      # Fall through to directory scanning
      DBI::dbDisconnect(conn)
    } else {
      # Query existing cohorts from database
      existing_cohorts <- DBI::dbGetQuery(
        conn,
        "SELECT id, label, tags, filePath, hash, cohortType FROM cohort_manifest"
      )

      # Only load from manifest if it has entries
      if (nrow(existing_cohorts) > 0) {
        if (verbose) {
          cli::cli_alert_info("Loading cohorts from existing manifest: {dbPath}")
        }

        # Process each cohort from database
        for (i in seq_len(nrow(existing_cohorts))) {
          record <- existing_cohorts[i, ]
          file_path <- record$filePath
          stored_hash <- record$hash
          tags_string <- record$tags
          cohort_id <- record$id
          cohort_type <- record$cohortType

          # Check if file still exists
          if (!file.exists(file_path)) {
            if (verbose) {
              cli::cli_alert_warning("Cohort file missing (will be marked): {record$label} ({file_path})")
            }
            # Don't skip - we'll track this in the database with status='missing'
            # For now, skip it from loading into memory but it will be in the database
            next
          }

          tryCatch({
            # Create CohortDef from file (this computes current hash)
            cohort_entry <- CohortDef$new(
              label = record$label,
              tags = list(),
              filePath = file_path
            )

            # Set the ID from the database to preserve it
            cohort_entry$setId(as.integer(cohort_id))

            # Restore cohortType from database
            if (!is.na(cohort_type)) {
              cohort_entry$setCohortType(cohort_type)
            }

            # Backfill tags from database
            if (!is.na(tags_string) && tags_string != "") {
              parsed_tags <- parseTagsString(tags_string)
              cohort_entry$tags <- parsed_tags
            }

            cohort_entries[[length(cohort_entries) + 1]] <- cohort_entry
          }, error = function(e) {
            cli::cli_alert_danger("Error loading cohort {record$label}: {e$message}")
          })
        }

        if (length(cohort_entries) > 0) {
          if (verbose) {
            cli::cli_alert_success("Loaded {length(cohort_entries)} cohorts from manifest")
          }
          # Successfully loaded from manifest, now check for new files in directories
          
          # Scan directories for all files to find any new cohorts not in database
          json_dir <- fs::path(cohortsFolderPath, "json")
          sql_dir <- fs::path(cohortsFolderPath, "sql")
          
          all_files <- c()
          if (dir.exists(json_dir)) {
            all_files <- c(all_files, list.files(json_dir, pattern = "\\.json$", full.names = TRUE, recursive = TRUE))
          }
          if (dir.exists(sql_dir)) {
            all_files <- c(all_files, list.files(sql_dir, pattern = "\\.sql$", full.names = TRUE, recursive = TRUE))
          }
          
          # Find which files are NOT in the database
          existing_file_paths <- existing_cohorts$filePath
          # make sure no new relative paths are accidentally treated as new if they match an existing absolute path
          new_files_mask <- !(fs::path_rel(all_files) %in% existing_file_paths) 
          new_files <- all_files[new_files_mask]  # keep absolute for CohortDef$new()
          
          # For each new file, create CohortDef and add to manifest
          if (length(new_files) > 0) {
            if (verbose) {
              cli::cli_alert_info("Found {length(new_files)} new cohort file(s) not in manifest")
            }
            
            for (file_path in new_files) {
              label <- tools::file_path_sans_ext(basename(file_path))
              tryCatch({
                new_cohort_entry <- CohortDef$new(
                  label = label,
                  tags = list(),
                  filePath = file_path
                )
                cohort_entries[[length(cohort_entries) + 1]] <- new_cohort_entry
                if (verbose) {
                  cli::cli_alert_success("Added new cohort from file: {label}")
                }
              }, error = function(e) {
                cli::cli_alert_warning("Error adding new cohort {label}: {e$message}")
              })
            }
          }
        } else {
          # Database had entries but none could be loaded, fall through to scan directories
          if (verbose) {
            cli::cli_alert_warning("No valid cohorts could be loaded from manifest. Scanning directories...")
          }
          cohort_entries <- list()  # Reset to empty for directory scan
        }
      } else {
        # Manifest exists but is empty, scan directories
        if (verbose) {
          cli::cli_alert_warning("Manifest exists but contains no cohort entries. Scanning directories...")
        }
      }
    }
  }

  # If no cohorts loaded from manifest (or manifest didn't exist), scan directories
  if (length(cohort_entries) == 0) {
    if (verbose) {
      cli::cli_alert_info("Scanning cohort directories...")
    }

    # Define directories to search
    json_dir <- fs::path(cohortsFolderPath, "json")
    sql_dir <- fs::path(cohortsFolderPath, "sql")

    # Process JSON directory if it exists
    if (dir.exists(json_dir)) {
      json_files <- list.files(json_dir, pattern = "\\.json$", full.names = TRUE, recursive = TRUE)

      for (file_path in json_files) {
        label <- tools::file_path_sans_ext(basename(file_path))
        tryCatch({
          cohort_entry <- CohortDef$new(
            label = label,
            tags = list(),
            filePath = file_path
          )
          cohort_entries[[length(cohort_entries) + 1]] <- cohort_entry
          if (verbose) {
            cli::cli_alert_success("Loaded JSON cohort: {label}")
          }
        }, error = function(e) {
          cli::cli_alert_danger("Error loading JSON cohort {label}: {e$message}")
        })
      }
    }

    # Process SQL directory if it exists
    if (dir.exists(sql_dir)) {
      sql_files <- list.files(sql_dir, pattern = "\\.sql$", full.names = TRUE, recursive = TRUE)

      for (file_path in sql_files) {
        label <- tools::file_path_sans_ext(basename(file_path))
        tryCatch({
          cohort_entry <- CohortDef$new(
            label = label,
            tags = list(),
            filePath = file_path
          )
          cohort_entries[[length(cohort_entries) + 1]] <- cohort_entry
          if (verbose) {
            cli::cli_alert_success("Loaded SQL cohort: {label}")
          }
        }, error = function(e) {
          cli::cli_alert_danger("Error loading SQL cohort {label}: {e$message}")
        })
      }
    }

    if (length(cohort_entries) == 0) {
      stop("No cohort files found in cohorts/json or cohorts/sql directories")
    }

    if (verbose) {
      cli::cli_alert_success("Found {length(cohort_entries)} total cohorts")
    }
  }

  # Check for cohortsLoad.csv file to enrich entries with tags and labels
  cohorts_load_path <- fs::path(cohortsFolderPath, "cohortsLoad.csv")
  if (file.exists(cohorts_load_path)) {
    if (verbose) {
      cli::cli_alert_info("Found cohortsLoad.csv. Enriching entries with load metadata...")
    }

    tryCatch({
      cohorts_load <- readr::read_csv(cohorts_load_path, show_col_types = FALSE)

      # Validate required columns (label is optional)
      required_cols <- c("file_name", "atlasId", "category", "subCategory")
      missing_cols <- setdiff(required_cols, names(cohorts_load))

      if (length(missing_cols) == 0) {
        # Process each cohort entry to find matching load record
        tags_added <- 0
        labels_updated <- 0
        for (i in seq_along(cohort_entries)) {
          entry <- cohort_entries[[i]]
          entry_filepath_rel <- fs::path_rel(entry$getFilePath())

          # Find matching record in cohortsLoad by file_name
          matching_idx <- which(entry_filepath_rel == cohorts_load$file_name)

          if (length(matching_idx) > 0) {
            load_record <- cohorts_load[matching_idx[1], ]

            # Update label if provided in cohortsLoad.csv
            if ("label" %in% names(cohorts_load) && !is.na(load_record$label)) {
              entry$label <- as.character(load_record$label)
              labels_updated <- labels_updated + 1
            }

            # Add tags from load record
            entry_tags <- list()
            if (!is.na(load_record$atlasId)) {
              entry_tags[["atlasId"]] <- as.character(load_record$atlasId)
            }
            if (!is.na(load_record$category)) {
              entry_tags[["category"]] <- as.character(load_record$category)
            }
            if (!is.na(load_record$subCategory)) {
              entry_tags[["subCategory"]] <- as.character(load_record$subCategory)
            }

            if (length(entry_tags) > 0) {
              entry$tags <- entry_tags
              tags_added <- tags_added + 1
              if (verbose) {
                cli::cli_alert_success("Added metadata to cohort: {entry$label}")
              }
            }
          }
        }

        if (verbose) {
          cli::cli_alert_success("Updated {labels_updated} labels and added tags to {tags_added} cohort entries from cohortsLoad.csv")
        }
      } else {
        if (verbose) {
          cli::cli_alert_warning("cohortsLoad.csv is missing required columns: {paste(missing_cols, collapse = ', ')}")
        }
      }
    }, error = function(e) {
      cli::cli_alert_danger("Error reading cohortsLoad.csv: {e$message}")
    })
  }

  # Create and return the CohortManifest
  manifest <- CohortManifest$new(
    cohortEntries = cohort_entries,
    executionSettings = executionSettings,
    dbPath = dbPath
  )

  return(manifest)
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
  cli::cli_br()
  cli::cli_h3("Column Guide:")
  cli::cli_ul(c(
    "{.field atlasId} - ATLAS cohort ID (numeric)",
    "{.field label} - Display name (e.g., 'Type 2 Diabetes patients')",
    "{.field category} - Broad category (e.g., 'Disease Populations')",
    "{.field subCategory} - Optional sub-grouping",
    "{.field file_name} - Path to JSON file (e.g., 'json/t2dm_patients.json'). Note this is a placeholder will be replaced when you import from ATLAS."
  ))
  cli::cli_br()
  cli::cli_h3("Tips for Filling Out:")
  cli::cli_ul(c(
    "Each row = one cohort",
    "Use forward slashes (/) in file paths",
    "Logical grouping helps with organization and querying",
    "Save as UTF-8 CSV from Excel to avoid encoding issues"
  ))
  cli::cli_br()
  cli::cli_h3("Next Steps:")
  cli::cli_ol(c(
    "Open {.file cohortsLoad.csv} in Excel or your text editor",
    "Fill in your cohort metadata",
    "Save the file",
    "Use {.code importAtlasCohorts()} to import JSON definitions from ATLAS",
    "Use {.code loadCohortManifest()} to load into your study"
  ))
  
  invisible(file_path)
}

#' Launch Interactive Cohort Load File Editor
#'
#' Opens an interactive Shiny application for creating, viewing and editing the cohort
#' load metadata file (cohortsLoad.csv). This allows you to add, remove,
#' and modify cohort metadata including labels, tags, and ATLAS IDs
#' without manually editing the CSV file.
#'
#' @param cohortsFolderPath Character. Path to the cohorts folder where cohortsLoad.csv
#'   will be saved. Defaults to "inputs/cohorts".
#'
#' @return Invisibly launches a Shiny app. Saves cohortsLoad.csv when the user user clicks "Save".
#'
#' @details
#' **Features:**
#' - View existing cohorts in a data table
#' - Edit cells directly in the table
#' - Add new cohort rows with form inputs
#' - Delete selected rows
#' - Save to cohortsLoad.csv
#' - Input validation for required fields
#'
#' **Table Columns:**
#' - `atlasId`: ATLAS cohort definition ID (numeric)
#' - `label`: Cohort name/label (character) - editing updates file_name automatically
#' - `category`: Broad category (character)
#' - `subCategory`: Sub-category (character)
#' - `file_name`: Auto-generated as `json/{label}.json` (read-only)
#'
#' **Workflow:**
#' 1. Call this function to launch the editor app
#' 2. Add/edit cohorts as needed
#' 3. Click "Save Cohort Load File" to save to inputs/cohorts/cohortsLoad.csv
#' 4. Use [importAtlasCohorts()] to import cohorts from ATLAS
#' 5. Use [loadCohortManifest()] to load the imported cohorts
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   # Launch the editor app
#'   launchCohortsLoadEditor()
#' }
launchCohortsLoadEditor <- function(cohortsFolderPath = here::here("inputs/cohorts")) {
  # Check if Shiny is installed
  if (!requireNamespace("shiny", quietly = TRUE)) {
    stop("The 'shiny' package is required to use this function. Install it with: install.packages('shiny')")
  }
  if (!requireNamespace("DT", quietly = TRUE)) {
    stop("The 'DT' package is required to use this function. Install it with: install.packages('DT')")
  }

  # Try to load existing cohortsLoad.csv
  existing_load <- NULL
  load_path <- fs::path(cohortsFolderPath, "cohortsLoad.csv")
  if (file.exists(load_path)) {
    existing_load <- readr::read_csv(load_path, show_col_types = FALSE)
    
    # Ensure file_name column exists; generate if missing
    if (!"file_name" %in% names(existing_load)) {
      existing_load$file_name <- fs::path("json", paste0(existing_load$label, ".json"))
    }
    
    # Ensure columns are in the correct order
    existing_load <- existing_load[, c("atlasId", "label", "category", "subCategory", "file_name")]
  }

  # Create the Shiny app
  app <- shiny::shinyApp(
    ui = function() {
      shiny::fluidPage(
        shiny::titlePanel("Cohort Load File Editor"),
        shiny::sidebarLayout(
          shiny::sidebarPanel(
            shiny::h4("Add New Cohort"),
            shiny::numericInput("atlas_id", "ATLAS ID:", value = NA, min = 1),
            shiny::textInput("label", "Label:", ""),
            shiny::textInput("category", "Category:", ""),
            shiny::textInput("sub_category", "Sub-Category (optional):", ""),
            shiny::actionButton("add_row", "Add Cohort", class = "btn-primary"),
            shiny::hr(),
            shiny::h4("Actions"),
            shiny::actionButton("delete_rows", "Delete Selected Rows", class = "btn-danger"),
            shiny::hr(),
            shiny::h4("Templates"),
            shiny::downloadButton("download_template", "Download Blank Template", class = "btn-info"),
            shiny::hr(),
            shiny::actionButton("save_file", "Save Cohort Load File", class = "btn-success"),
            shiny::actionButton("cancel", "Cancel", class = "btn-secondary")
          ),
          shiny::mainPanel(
            DT::DTOutput("cohort_table"),
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
          file_name = character(),
          stringsAsFactors = FALSE
        ),
        message = NULL,
        message_type = NULL
      )

      # Display the data table
      output$cohort_table <- DT::renderDT({
        DT::datatable(
          rv$data,
          editable = list(target = "cell", disable = list(columns = 5)),
          selection = "multiple",
          rownames = FALSE,
          options = list(pageLength = 10)
        )
      })

      # Handle table edits
      shiny::observeEvent(input$cohort_table_cell_edit, {
        info <- input$cohort_table_cell_edit
        rv$data[info$row, info$col] <- info$value

        # Update file_name automatically if label (column 2) changed
        if (info$col == 2) {
          rv$data$file_name[info$row] <- fs::path("json", paste0(info$value, ".json"))
          rv$message <- "Label updated - file_name auto-generated"
          rv$message_type <- "info"
        }
      })

      # Add new cohort
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

        # Add row
        new_row <- data.frame(
          atlasId = as.integer(input$atlas_id),
          label = input$label,
          category = input$category,
          subCategory = if (input$sub_category == "") NA_character_ else input$sub_category,
          file_name = fs::path("json", paste0(input$label, ".json")),
          stringsAsFactors = FALSE
        )

        rv$data <- rbind(rv$data, new_row)
        rv$message <- paste("Added cohort:", input$label)
        rv$message_type <- "success"

        # Clear inputs
        shiny::updateNumericInput(session, "atlas_id", value = NA)
        shiny::updateTextInput(session, "label", value = "")
        shiny::updateTextInput(session, "category", value = "")
        shiny::updateTextInput(session, "sub_category", value = "")
      })

      # Delete selected rows
      shiny::observeEvent(input$delete_rows, {
        selected <- input$cohort_table_rows_selected
        if (length(selected) == 0) {
          rv$message <- "No rows selected"
          rv$message_type <- "warning"
        } else {
          deleted_labels <- rv$data$label[selected]
          rv$data <- rv$data[-selected, ]
          rv$message <- paste("Deleted", length(selected), "cohort(s):", paste(deleted_labels, collapse = ", "))
          rv$message_type <- "info"
        }
      })

      # Save file
      shiny::observeEvent(input$save_file, {
        if (nrow(rv$data) == 0) {
          rv$message <- "Cannot save: No cohorts in table"
          rv$message_type <- "danger"
          return()
        }

        fs::dir_create(cohortsFolderPath)
        save_path <- fs::path(cohortsFolderPath, "cohortsLoad.csv")
        readr::write_csv(rv$data, file = save_path)

        rv$message <- paste("Cohort load file saved successfully!\nLocation:", fs::path_rel(save_path))
        rv$message_type <- "success"

        shiny::showNotification(
          paste("Saved", nrow(rv$data), "cohorts to cohortsLoad.csv"),
          type = "message",
          duration = 3
        )
      })

      # Download blank template
      output$download_template <- shiny::downloadHandler(
        filename = function() {
          paste0("cohortsLoad_template_", format(Sys.Date(), "%Y%m%d"), ".csv")
        },
        content = function(file) {
          template <- data.frame(
            atlasId = integer(1),
            label = character(1),
            category = character(1),
            subCategory = character(1),
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
#' Imports CIRCE JSON cohort definitions from an ATLAS WebAPI instance and saves
#' them to the inputs/cohorts/json folder. This function reads a CSV file containing
#' cohort metadata and fetches the actual cohort definitions from ATLAS.
#' 
#' @description this function looks for a CSV file called cohortsLoad.csv containing cohort metadata.
#'   Must be located in or accessible from the inputs/cohorts folder.
#'   The CSV must have the following columns:
#'   - `atlasId`: ATLAS cohort definition ID (integer)
#'   - `label`: Cohort name/label (character)
#'   - `category`: Broad category for the cohort (character)
#'   - `subCategory`: Sub-category for the cohort (character)
#' The function will read this CSV, fetch the cohort definitions from ATLAS using the provided atlasConnection,
#' extract the CIRCE JSON expressions, and save them to the specified output folder with filenames based on the label.
#' Finally it updates the cohort load CSV with the relative file paths to the saved JSON files.
#'
#' @param cohortsFolderPath Character. Path to cohorts folder in Ulysses repo. 
#'
#' @param atlasConnection An ATLAS connection object (typically from ROhdsiWebApi package)
#'   with a method `getCohortDefinition(cohortId)` that returns a list containing
#'   an `expression` element with the CIRCE JSON string.
#'
#' @param outputFolder Character. Path to the output folder where cohort JSON files
#'   will be saved. Defaults to "inputs/cohorts/json". Files are saved as
#'   `{label}.json`.
#'
#' @return Invisibly returns NULL. Saves CIRCE JSON files to outputFolder and
#'   prints status messages via cli alerts.
#'
#' @details
#' **Workflow:**
#' 1. Reads the cohort load CSV file
#' 2. Validates that all required columns are present
#' 3. For each row with a valid atlasId:
#'    - Fetches the cohort definition from ATLAS WebAPI
#'    - Extracts the CIRCE JSON expression
#'    - Saves to `outputFolder/{label}.json`
#' 4. Skips rows with missing atlasId with a warning
#' 5. Catches and reports errors per cohort without stopping the entire import
#'
#' **Post-Import:**
#' After running this function, use [loadCohortManifest()] to load the saved
#' cohort JSON files and build the manifest with metadata.
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   # Assuming ATLAS connection is set up
#'   importAtlasCohorts(
#'     cohortFolderPath = here::here("inputs/cohorts"),
#'     atlasConnection = setAtlasConnection()
#'   )
#'
#'   # Then load the manifest (no settings required for metadata review)
#'   manifest <- loadCohortManifest()
#' }
#'
importAtlasCohorts <- function(cohortsFolderPath = here::here("inputs/cohorts"),
                               atlasConnection) {
  cohortLoadPath <- fs::path(cohortsFolderPath, "cohortsLoad.csv")                              
  # Read cohort manifest CSV file
  if (!file.exists(cohortLoadPath)) {
    stop("Cohort load file not found: ", cohortLoadPath)
  }

  cohort_load <- readr::read_csv(cohortLoadPath, show_col_types = FALSE)

  # Validate required columns
  required_cols <- c("atlasId", "label", "category", "subCategory")
  missing_cols <- setdiff(required_cols, names(cohort_load))

  if (length(missing_cols) > 0) {
    stop("Cohort load is missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  # Initialize file_name column
  cohort_load$file_name <- NA_character_

  cli::cli_alert_info("Importing {nrow(cohort_load)} cohorts from ATLAS...")

  # Process each cohort
  for (i in seq_len(nrow(cohort_load))) {
    atlas_id <- cohort_load$atlasId[i]
    label <- cohort_load$label[i]
    category <- cohort_load$category[i]
    sub_category <- cohort_load$subCategory[i]

    # Skip rows with missing atlasId
    if (is.na(atlas_id)) {
      cli::cli_alert_warning("Row {i}: Skipping cohort with missing atlasId")
      next
    }

    tryCatch({
      # Get cohort definition from ATLAS
      cli::cli_alert_info("Fetching cohort {atlas_id}: {label}...")
      cohort_def <- atlasConnection$getCohortDefinition(cohortId = atlas_id)

      # Extract expression
      cohort_expression <- cohort_def$expression[1]
      # extract cohort name from definition to use as file name (fallback to label if not available)
      cohort_name <- ifelse(!is.null(cohort_def$saveName[1]) && cohort_def$saveName[1] != "", cohort_def$saveName[1], label)
      # Ensure output folder exists
      outputFolder <- fs::path(cohortsFolderPath, "json")
      fs::dir_create(outputFolder)
      save_path_rel <- fs::path_rel(outputFolder)

      # Create file name from cohort_name (make it file-system friendly)
      file_name <- fs::path(outputFolder, cohort_name, ext = "json")

      # Write cohort JSON to file
      readr::write_file(cohort_expression, file = file_name)

      # Store the relative file name in the data frame
      cohort_load$file_name[i] <- fs::path_rel(file_name)

      cli::cli_alert_success(
        "Imported cohort {crayon::magenta(cohort_name)} (ID: {atlas_id}) to {crayon::cyan(save_path_rel)}"
      )
    }, error = function(e) {
      cli::cli_alert_danger(
        "Error importing cohort {cohort_name} (ID: {atlas_id}): {e$message}"
      )
    })
  }

  # Save the updated cohort_load file with file_name column to inputs/cohorts
  # Generate save path from original file path, keeping the original filename
  readr::write_csv(cohort_load, file = cohortLoadPath)
  cli::cli_alert_success("Updated cohort load file saved to: {fs::path_rel(cohortLoadPath)}")

  cli::cli_alert_success("ATLAS cohort import complete")
  invisible(cohort_load)
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
    
    # Get dependencies and create edges
    deps <- cohort$getDependencies()
    if (!is.null(deps) && length(deps$ids) > 0) {
      for (parent_id in deps$ids) {
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
    
    deps <- cohort$getDependencies()
    depends_on_str <- ifelse(
      is.null(deps) || length(deps$ids) == 0,
      "None",
      paste(deps$ids, collapse = ", ")
    )
    
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
    deps <- cohort$getDependencies()
    if (!is.null(deps) && cohort_id %in% deps$ids && !(cohort$getId() %in% processed_env$ids)) {
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
#' parameters are automatically injected by [CohortManifest]`$generateCohorts()`:
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
