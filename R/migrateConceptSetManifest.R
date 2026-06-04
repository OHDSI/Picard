#' Migrate Old ConceptSetManifest SQLite to New Schema
#'
#' @description
#' One-time migration utility that converts an existing `conceptSetManifest.sqlite`
#' (picard <= 0.0.3.1) to the new schema with `category`, `status`, `deleted_at` columns,
#' and converts tags from pipe-delimited string format to JSON.
#'
#' @details
#' The migration performs the following steps:
#' 1. Backs up the old database to `conceptSetManifest_backup_{timestamp}.sqlite`
#' 2. Reads all rows from the old schema
#' 3. Assigns `category` from the tag keywords (e.g., "domain: condition_occurrence" -> "condition_occurrence")
#'    or defaults to "init" if not found
#' 4. Converts tags from pipe-delimited string (e.g., "name: value | name: value") to JSON named list
#' 5. Adds missing columns (category, status, deleted_at) if they don't exist
#' 6. Creates new schema with proper structure
#' 7. Inserts migrated rows
#' 8. Prints migration summary
#'
#' @param dbPath Character. Path to the existing `conceptSetManifest.sqlite` file.
#'   Defaults to `"inputs/conceptSets/conceptSetManifest.sqlite"`.
#' @param categoryMap Named list. Maps concept set labels to categories.
#'   Example: `list("BMI Ratio" = "measurement", "Diabetes" = "condition_occurrence")`.
#'   Concept sets not in the map will be assigned from tag keywords or "init".
#'
#' @return Invisible tibble of migrated rows with their assigned categories.
#'
#' @export
migrateConceptSetManifest <- function(dbPath = "inputs/conceptSets/conceptSetManifest.sqlite",
                                       categoryMap = NULL) {

  # Validate inputs
  checkmate::assert_file_exists(dbPath)
  if (!is.null(categoryMap)) {
    checkmate::assert_list(categoryMap, names = "named", types = "character")
  }

  # Step 1: Backup
  timestamp_str <- format(Sys.time(), "%Y%m%d_%H%M%S")
  backup_path <- sub("\\.sqlite$", paste0("_backup_", timestamp_str, ".sqlite"), dbPath)
  file.copy(dbPath, backup_path)
  cli::cli_alert_success("Backup saved to {fs::path_rel(backup_path)}")

  # Step 2: Read old schema
  conn <- DBI::dbConnect(RSQLite::SQLite(), dbPath)
  on.exit(DBI::dbDisconnect(conn))

  # Check if this is already the new schema
  schema_info <- DBI::dbGetQuery(conn, "PRAGMA table_info(concept_set_manifest)")
  col_names <- schema_info$name

  if ("category" %in% col_names) {
    cli::cli_alert_warning("Database already appears to have the new schema. Aborting migration.")
    return(invisible(NULL))
  }

  old_rows <- DBI::dbGetQuery(conn, "SELECT * FROM concept_set_manifest")

  if (nrow(old_rows) == 0) {
    cli::cli_alert_info("No rows in manifest. Creating new schema on empty database.")
    .migrate_create_new_concept_set_schema(conn)
    cli::cli_alert_success("Migration complete (empty manifest)")
    return(invisible(tibble::tibble()))
  }

  cli::cli_alert_info("Found {nrow(old_rows)} concept set(s) to migrate")

  # Step 3-6: Transform each row
  migrated <- lapply(seq_len(nrow(old_rows)), function(i) {
    row <- old_rows[i, ]

    # Assign category from categoryMap or extract from tags
    category <- .assign_concept_set_category(row$label, row$tags, categoryMap)

    # Convert tags from pipe-delimited to JSON
    tags_json <- .convert_concept_set_tags_to_json(row$tags)

    list(
      id = row$id,
      label = row$label,
      category = category,
      tags = tags_json,
      filePath = row$filePath,
      hash = row$hash,
      timestamp = row$timestamp,
      status = if (!is.null(row$status) && !is.na(row$status)) row$status else "active",
      deleted_at = if (!is.null(row$deleted_at)) row$deleted_at else NA_character_
    )
  })

  # Step 7: Drop old table and create new schema
  DBI::dbExecute(conn, "DROP TABLE IF EXISTS concept_set_manifest")
  .migrate_create_new_concept_set_schema(conn)

  # Step 8: Insert migrated rows
  for (entry in migrated) {
    DBI::dbExecute(
      conn,
      "INSERT INTO concept_set_manifest (id, label, category, tags, filePath, hash, timestamp, status, deleted_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
      list(
        entry$id,
        entry$label,
        entry$category,
        entry$tags,
        entry$filePath,
        entry$hash,
        entry$timestamp,
        entry$status,
        entry$deleted_at
      )
    )
  }

  # Step 9: Summary
  categories <- vapply(migrated, function(x) x$category, character(1))

  cli::cli_rule("Migration Summary")
  cli::cli_alert_success("Migrated {length(migrated)} concept set(s)")
  cli::cli_alert_info("Categories assigned: {paste(table(categories), collapse = ', ')}")

  result <- tibble::tibble(
    id = vapply(migrated, function(x) x$id, integer(1)),
    label = vapply(migrated, function(x) x$label, character(1)),
    category = categories
  )

  cli::cli_alert_success("Migration complete. Load with: csm <- loadConceptSetManifest()")
  return(invisible(result))
}


# ============================================================================
# Internal helpers for concept set migration
# ============================================================================

#' @noRd
.migrate_create_new_concept_set_schema <- function(conn) {
  DBI::dbExecute(
    conn,
    "CREATE TABLE concept_set_manifest (
      id INTEGER PRIMARY KEY,
      label TEXT NOT NULL,
      category TEXT NOT NULL,
      tags TEXT,
      filePath TEXT NOT NULL,
      hash TEXT NOT NULL,
      timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      status TEXT DEFAULT 'active',
      deleted_at DATETIME DEFAULT NULL
    )"
  )
}

#' @noRd
.assign_concept_set_category <- function(label, tags_str, categoryMap) {
  # If in categoryMap, use that
  if (!is.null(categoryMap) && label %in% names(categoryMap)) {
    return(categoryMap[[label]])
  }

  # Try to extract from tags
  if (!is.null(tags_str) && !is.na(tags_str) && nchar(trimws(tags_str)) > 0) {
    # Look for "domain: ..." pattern
    if (grepl("domain:\\s*", tags_str, ignore.case = TRUE)) {
      # Extract domain value
      domain_match <- regmatches(tags_str, regexec("domain:\\s*([^|]+)", tags_str, ignore.case = TRUE))
      if (length(domain_match) > 0 && length(domain_match[[1]]) > 1) {
        return(trimws(domain_match[[1]][2]))
      }
    }
  }

  # Default to "init"
  return("init")
}

#' @noRd
.convert_concept_set_tags_to_json <- function(tags_str) {
  if (is.null(tags_str) || is.na(tags_str) || nchar(trimws(tags_str)) == 0) {
    return(NA_character_)
  }

  # Parse pipe-delimited pairs into a named list
  pairs <- strsplit(trimws(tags_str), "\\|")[[1]]
  tags_list <- list()

  for (pair in pairs) {
    pair <- trimws(pair)
    if (nchar(pair) > 0 && grepl(":", pair)) {
      parts <- strsplit(pair, ":")[[1]]
      if (length(parts) == 2) {
        name <- trimws(parts[1])
        value <- trimws(parts[2])
        tags_list[[name]] <- value
      }
    }
  }

  if (length(tags_list) == 0) {
    return(NA_character_)
  }

  # Convert to JSON
  jsonlite::toJSON(tags_list, auto_unbox = TRUE)
}
