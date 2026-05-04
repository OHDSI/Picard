#' Migrate Old CohortManifest SQLite to New Schema
#'
#' @description
#' One-time migration utility that converts an existing `cohortManifest.sqlite`
#' (picard <= 0.0.3) to the new schema with `category`, `source_type`, `cohort_type`,
#' `depends_on`, `dependency_rule`, and timestamp columns.
#'
#' @details
#' The migration performs the following steps:
#' 1. Backs up the old database to `cohortManifest_backup_{timestamp}.sqlite`
#' 2. Reads all rows from the old schema
#' 3. Infers `source_type` from file path (`json/` -> "atlas", `sql/` -> "sql", `derived/` -> "derived")
#' 4. Infers `cohort_type` from old `cohortType` column
#' 5. Assigns `category` from `categoryMap`, tag keywords, or defaults to "unclassified"
#' 6. Converts tags from pipe-delimited string to JSON named list
#' 7. Reads sidecar `.json` metadata for dependent cohorts -> `dependency_rule` and `depends_on`
#' 8. Creates new schema with unique indexes
#' 9. Inserts migrated rows
#' 10. Prints migration summary
#'
#' @param dbPath Character. Path to the existing `cohortManifest.sqlite` file.
#'   Defaults to `"inputs/cohorts/cohortManifest.sqlite"`.
#' @param categoryMap Named list. Maps cohort labels to categories.
#'   Example: `list("Type 2 Diabetes" = "target", "GI Bleed" = "outcome")`.
#'   Cohorts not in the map will be assigned from tag keywords or "unclassified".
#'
#' @return Invisible tibble of migrated rows with their assigned categories.
#'
#' @export
migrateCohortManifest <- function(dbPath = "inputs/cohorts/cohortManifest.sqlite",
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
  schema_info <- DBI::dbGetQuery(conn, "PRAGMA table_info(cohort_manifest)")
  col_names <- schema_info$name

  if ("source_type" %in% col_names) {
    cli::cli_alert_warning("Database already appears to have the new schema. Aborting migration.")
    return(invisible(NULL))
  }

  old_rows <- DBI::dbGetQuery(conn, "SELECT * FROM cohort_manifest")

  if (nrow(old_rows) == 0) {
    cli::cli_alert_info("No rows in manifest. Creating new schema on empty database.")
    .migrate_create_new_schema(conn)
    cli::cli_alert_success("Migration complete (empty manifest)")
    return(invisible(tibble::tibble()))
  }

  cli::cli_alert_info("Found {nrow(old_rows)} cohort(s) to migrate")

  # Step 3-7: Transform each row
  migrated <- lapply(seq_len(nrow(old_rows)), function(i) {
    row <- old_rows[i, ]
    file_path <- row$filePath

    # Infer source_type from file path
    source_type <- .infer_source_type(file_path)

    # Infer cohort_type
    cohort_type <- .infer_cohort_type(row, source_type)

    # Assign category
    category <- .assign_category(row$label, row$tags, categoryMap)

    # Convert tags from pipe-delimited to JSON
    tags_json <- .convert_tags_to_json(row$tags)

    # Load dependency info from sidecar JSON (for derived cohorts)
    dep_info <- .load_dependency_info(file_path, source_type)

    list(
      id = row$id,
      label = row$label,
      category = category,
      tags = tags_json,
      file_path = file_path,
      hash = row$hash,
      source_type = source_type,
      cohort_type = cohort_type,
      depends_on = dep_info$depends_on,
      dependency_rule = dep_info$dependency_rule,
      status = if (!is.null(row$status) && !is.na(row$status)) row$status else "active",
      deleted_at = if (!is.null(row$deleted_at)) row$deleted_at else NA_character_
    )
  })

  # Step 8: Drop old table and create new schema
  DBI::dbExecute(conn, "DROP TABLE IF EXISTS cohort_manifest")
  .migrate_create_new_schema(conn)

  # Step 9: Insert migrated rows
  for (entry in migrated) {
    DBI::dbExecute(
      conn,
      "INSERT INTO cohort_manifest (id, label, category, tags, file_path, hash, source_type, cohort_type, depends_on, dependency_rule, status, created_at, updated_at, deleted_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, ?)",
      list(
        entry$id,
        entry$label,
        entry$category,
        entry$tags,
        entry$file_path,
        entry$hash,
        entry$source_type,
        entry$cohort_type,
        entry$depends_on,
        entry$dependency_rule,
        entry$status,
        entry$deleted_at
      )
    )
  }

  # Step 10: Summary
  categories <- vapply(migrated, function(x) x$category, character(1))
  unclassified_entries <- migrated[categories == "unclassified"]

  cli::cli_rule("Migration Summary")
  cli::cli_alert_success("Migrated {length(migrated)} cohort(s)")
  cli::cli_alert_info("Source types: {paste(table(vapply(migrated, function(x) x$source_type, character(1))), collapse = ', ')}")

  if (length(unclassified_entries) > 0) {
    cli::cli_alert_warning("{length(unclassified_entries)} cohort(s) assigned 'unclassified' category:")
    for (entry in unclassified_entries) {
      cli::cli_bullets(c("!" = "{entry$label} (id: {entry$id})"))
    }
    cli::cli_alert_info("Use cm$updateCohortDef(currentLabel = '...', category = '...') to fix.")
  }

  result <- tibble::tibble(
    id = vapply(migrated, function(x) x$id, integer(1)),
    label = vapply(migrated, function(x) x$label, character(1)),
    category = categories,
    source_type = vapply(migrated, function(x) x$source_type, character(1)),
    cohort_type = vapply(migrated, function(x) x$cohort_type, character(1))
  )

  cli::cli_alert_success("Migration complete. Load with: cm <- loadCohortManifest()")
  return(invisible(result))
}


# ============================================================================
# Internal helpers for migration
# ============================================================================

#' @noRd
.migrate_create_new_schema <- function(conn) {
  DBI::dbExecute(
    conn,
    "CREATE TABLE cohort_manifest (
      id INTEGER PRIMARY KEY,
      label TEXT NOT NULL,
      category TEXT NOT NULL,
      tags TEXT,
      file_path TEXT NOT NULL,
      hash TEXT NOT NULL,
      source_type TEXT NOT NULL,
      cohort_type TEXT NOT NULL,
      depends_on TEXT,
      dependency_rule TEXT,
      status TEXT DEFAULT 'active',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      deleted_at DATETIME DEFAULT NULL
    )"
  )

  DBI::dbExecute(
    conn,
    "CREATE UNIQUE INDEX IF NOT EXISTS idx_label_active
      ON cohort_manifest(label) WHERE status = 'active'"
  )

  DBI::dbExecute(
    conn,
    "CREATE UNIQUE INDEX IF NOT EXISTS idx_filepath_active
      ON cohort_manifest(file_path) WHERE status = 'active'"
  )
}

#' @noRd
.infer_source_type <- function(file_path) {
  if (grepl("/json/", file_path, fixed = TRUE)) {
    return("atlas")
  }

  if (grepl("/sql/", file_path, fixed = TRUE)) {
    return("sql")
  }

  if (grepl("/derived/", file_path, fixed = TRUE)) {
    return("derived")
  }

  # Fallback: check file extension
  ext <- tolower(tools::file_ext(file_path))
  if (ext == "json") return("atlas")
  if (ext == "sql") return("sql")


  return("sql")
}

#' @noRd
.infer_cohort_type <- function(row, source_type) {
  # Use existing cohortType column if available
  if (!is.null(row$cohortType) && !is.na(row$cohortType)) {
    old_type <- row$cohortType
    if (old_type %in% c("circe", "custom", "subset", "union", "complement", "composite")) {
      return(old_type)
    }
  }

  # Infer from source_type
  if (source_type == "derived") {
    return("subset")
  }

  if (source_type == "sql") {
    return("custom")
  }

  return("circe")
}

#' @noRd
.assign_category <- function(label, tags_str, categoryMap) {
  # Priority 1: explicit categoryMap

  if (!is.null(categoryMap) && label %in% names(categoryMap)) {
    return(categoryMap[[label]])
  }

  # Priority 2: extract from tags
  if (!is.null(tags_str) && !is.na(tags_str) && nchar(tags_str) > 0) {
    tags_lower <- tolower(tags_str)
    known_categories <- c("target", "comparator", "outcome", "indication",
                          "exclusion", "exposure", "covariate", "strata")

    for (cat in known_categories) {
      if (grepl(paste0("category:\\s*", cat), tags_lower)) {
        return(cat)
      }
    }
  }

  # Priority 3: unclassified
  return("unclassified")
}

#' @noRd
.convert_tags_to_json <- function(tags_str) {
  if (is.null(tags_str) || is.na(tags_str) || nchar(trimws(tags_str)) == 0) {
    return(NA_character_)
  }

  # Parse pipe-delimited "name: value | name: value" format
  pairs <- strsplit(tags_str, "\\|")[[1]]
  tags_list <- list()

  for (pair in pairs) {
    pair <- trimws(pair)
    if (nchar(pair) == 0) next

    parts <- strsplit(pair, ":", fixed = TRUE)[[1]]

    if (length(parts) >= 2) {
      key <- trimws(parts[1])
      value <- trimws(paste(parts[-1], collapse = ":"))
      tags_list[[key]] <- value
    } else {
      # Single value without key — use as boolean flag
      tags_list[[trimws(parts[1])]] <- TRUE
    }
  }

  if (length(tags_list) == 0) {
    return(NA_character_)
  }

  jsonlite::toJSON(tags_list, auto_unbox = TRUE)
}

#' @noRd
.load_dependency_info <- function(file_path, source_type) {
  result <- list(depends_on = NA_character_, dependency_rule = NA_character_)

  if (source_type != "derived") {
    return(result)
  }

  # Look for sidecar .json metadata
  metadata_path <- sub("\\.sql$", ".json", file_path)

  if (!file.exists(metadata_path)) {
    return(result)
  }

  tryCatch({
    metadata <- jsonlite::fromJSON(metadata_path, simplifyVector = FALSE)

    # Extract depends_on from known fields
    parent_ids <- integer(0)

    if (!is.null(metadata$baseCohortId)) {
      parent_ids <- c(parent_ids, as.integer(metadata$baseCohortId))
    }

    if (!is.null(metadata$filterCohortId)) {
      parent_ids <- c(parent_ids, as.integer(metadata$filterCohortId))
    }

    if (!is.null(metadata$cohortIds)) {
      parent_ids <- c(parent_ids, as.integer(metadata$cohortIds))
    }

    if (!is.null(metadata$populationCohortId)) {
      parent_ids <- c(parent_ids, as.integer(metadata$populationCohortId))
    }

    if (!is.null(metadata$excludeCohortIds)) {
      parent_ids <- c(parent_ids, as.integer(metadata$excludeCohortIds))
    }

    parent_ids <- unique(parent_ids)

    if (length(parent_ids) > 0) {
      result$depends_on <- jsonlite::toJSON(parent_ids, auto_unbox = FALSE)
    }

    # Store entire metadata as dependency_rule
    result$dependency_rule <- jsonlite::toJSON(metadata, auto_unbox = TRUE)
  }, error = function(e) {
    cli::cli_alert_warning("Failed to read metadata from {metadata_path}: {e$message}")
  })

  return(result)
}
