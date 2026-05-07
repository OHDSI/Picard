write_derived_template <- function(derived_dir, label, template_name, ...) {
    safe_label <- gsub("[^a-zA-Z0-9_-]", "_", label)
    sql_path <- fs::path(derived_dir, paste0(safe_label, ".sql"))
    template_path <- system.file("sql", template_name, package = "picard")
    rendered_sql <- readr::read_file(template_path) |>
        SqlRender::render(...)
    writeLines(rendered_sql, sql_path)
    return(sql_path)
}

make_derived_folder <- function(cohorts_dir) {
    derived_dir <- fs::path(cohorts_dir, "derived")
    if (!dir.exists(derived_dir)) {
        dir.create(derived_dir, recursive = TRUE)
    }
    return(derived_dir)
}


# ========== PRIVATE HELPER METHODS FOR DEPENDENCY MANAGEMENT ==========

# Build a dependency graph from all cohorts in the manifest
#
# Creates an adjacency list representation of dependencies.
# Returns a list where each cohort ID maps to a vector of cohorts it depends on.
build_dependency_graph = function(dbPath) {
    conn <- DBI::dbConnect(RSQLite::SQLite(), dbPath)
    on.exit(DBI::dbDisconnect(conn))

    rows <- DBI::dbGetQuery(
    conn,
    "SELECT id, depends_on FROM cohort_manifest WHERE status = 'active'"
    )

    graph <- list()
    for (i in seq_len(nrow(rows))) {
    cohort_id <- rows$id[i]
    depends_on_raw <- rows$depends_on[i]

    parent_ids <- if (!is.na(depends_on_raw) && nchar(depends_on_raw) > 0) {
        as.integer(jsonlite::fromJSON(depends_on_raw))
    } else {
        integer(0)
    }

    graph[[as.character(cohort_id)]] <- parent_ids
    }

    return(graph)
}

# Validate that the dependency graph has no cycles (is a DAG)
#
# Uses depth-first search to detect cycles. Throws an error if a cycle is found.
validate_no_cycles = function(graph) {
    # DFS-based cycle detection using color marking (white/gray/black)
    state <- new.env()
    state$colors <- rep("white", length(graph))
    names(state$colors) <- names(graph)
    state$cycle_found <- FALSE
    state$cycle_msg <- ""

    visit_node <- function(node_id) {
    state$colors[[node_id]] <- "gray"

    deps <- graph[[node_id]]
    if (length(deps) > 0) {
        for (dep_id in deps) {
        if (state$cycle_found) return()

        dep_str <- as.character(dep_id)
        if (!dep_str %in% names(graph)) {
            cli::cli_abort("Cohort {node_id} depends on non-existent cohort {dep_id}")
        }

        color <- state$colors[[dep_str]]
        if (color == "gray") {
            state$cycle_found <- TRUE
            state$cycle_msg <- paste0("Circular dependency detected: Cohort ", node_id, " -> ", dep_id)
            return()
        } else if (color == "white") {
            visit_node(dep_str)
        }
        }
    }

    state$colors[[node_id]] <- "black"
    }

    # Visit all nodes
    for (node in names(graph)) {
    if (state$cycle_found) break
    if (state$colors[[node]] == "white") {
        visit_node(node)
    }
    }

    if (state$cycle_found) {
    cli::cli_abort(state$cycle_msg)
    }

    cli::cli_alert_success("No circular dependencies detected")
}

# Topologically sort cohorts by dependencies
#
# Returns a vector of cohort IDs in execution order (dependencies before dependents).
topological_sort = function(graph) {
    # Kahn's algorithm: in-degree based topological sort
    in_degree <- rep(0L, length(graph))
    names(in_degree) <- names(graph)

    # Build reverse graph: node -> nodes that depend on it
    reverse_graph <- setNames(
    lapply(names(graph), function(x) integer()),
    names(graph)
    )

    # Calculate in-degrees and build reverse edges
    for (node_id in names(graph)) {
    deps <- graph[[node_id]]
    if (length(deps) > 0) {
        # node_id depends on these nodes, so node_id has incoming edges
        in_degree[[node_id]] <- in_degree[[node_id]] + length(deps)

        # Build reverse edges: each dependency has an outgoing edge to node_id
        for (dep_id in deps) {
        dep_str <- as.character(dep_id)
        if (dep_str %in% names(reverse_graph)) {
            reverse_graph[[dep_str]] <- c(reverse_graph[[dep_str]], as.integer(node_id))
        }
        }
    }
    }

    # Initialize queue with nodes having in_degree = 0 (no dependencies)
    queue <- as.integer(names(in_degree[in_degree == 0]))
    sorted_order <- integer()

    # Process nodes in topological order
    while (length(queue) > 0) {
    node_id <- queue[1]
    queue <- queue[-1]
    sorted_order <- c(sorted_order, node_id)

    # For each node that depends on this node, decrement its in-degree
    dependents <- reverse_graph[[as.character(node_id)]]
    if (length(dependents) > 0) {
        for (dependent_id in dependents) {
        dependent_str <- as.character(dependent_id)
        in_degree[[dependent_str]] <- in_degree[[dependent_str]] - 1L

        if (in_degree[[dependent_str]] == 0) {
            queue <- c(queue, as.integer(dependent_id))
        }
        }
    }
    }

    # Verify all nodes were processed
    if (length(sorted_order) != length(graph)) {
    cli::cli_abort("Topological sort failed - possible circular dependency")
    }

    return(sorted_order)
}


# Compute dependency hash for a dependent cohort
# Combines parent cohort hashes with the dependency rule parameters.
compute_dependency_hash = function(dbPath, cohort, parent_hashes) {
    conn <- DBI::dbConnect(RSQLite::SQLite(), dbPath)
    on.exit(DBI::dbDisconnect(conn))

    cohort_id <- cohort$getId()
    row <- DBI::dbGetQuery(
    conn,
    "SELECT depends_on, dependency_rule FROM cohort_manifest WHERE id = ? AND status = 'active'",
    list(cohort_id)
    )

    parent_ids <- if (nrow(row) > 0 && !is.na(row$depends_on[1]) && nchar(row$depends_on[1]) > 0) {
    as.integer(jsonlite::fromJSON(row$depends_on[1]))
    } else {
    integer(0)
    }

    rule <- if (nrow(row) > 0 && !is.na(row$dependency_rule[1]) && nchar(row$dependency_rule[1]) > 0) {
    jsonlite::fromJSON(row$dependency_rule[1], simplifyVector = FALSE)
    } else {
    list()
    }

    # Combine parent hashes in dependency order
    parent_hash_strs <- character()
    for (pid in parent_ids) {
    pid_str <- as.character(pid)
    if (pid_str %in% names(parent_hashes)) {
        parent_hash_strs <- c(parent_hash_strs, parent_hashes[[pid_str]])
    }
    }

    # Serialize the rule (dependency parameters)
    rule_json <- jsonlite::toJSON(rule, auto_unbox = TRUE)

    # Combine: parent hashes + rule parameters
    combined <- paste0(
    paste(parent_hash_strs, collapse = "|"),
    "|",
    rule_json
    )
    md5Hash <- rlang::hash(combined)
    return(md5Hash)
}

# Function to see if checksum table is empty
is_the_checksum_empty <- function(
    db_conn,
    cohort_schema,
    checksum_table
) {
  checksum_query <- paste0("SELECT COUNT(*) as count FROM ", cohort_schema, ".", checksum_table)
  checksum_count_result <- try(DatabaseConnector::querySql(db_conn, checksum_query), silent = TRUE)

  if (inherits(checksum_count_result, "try-error") || nrow(checksum_count_result) == 0) {
    is_checksum_empty <- TRUE
  } else {
    count_value <- checksum_count_result$COUNT[1]
    is_checksum_empty <- is.na(count_value) || count_value == 0
  }
  return(is_checksum_empty)
}


evaluate_cohort_skip_status <- function(
    cohort, 
    sqlite_conn, 
    cohort_schema,
    checksum_table, 
    conn,
    is_checksum_empty, 
    cohort_hashes,
    dbPath) {

  cohort_id <- cohort$getId()
  cohort_type <- cohort$getCohortType()

  dep_row <- DBI::dbGetQuery(
    sqlite_conn,
    "SELECT depends_on, status FROM cohort_manifest WHERE id = ? AND status IN ('active', 'stale')",
    list(cohort_id)
  )

  is_stale <- nrow(dep_row) > 0 && dep_row$status[1] == "stale"
  if (nrow(dep_row) > 0 && !is.na(dep_row$depends_on[1]) && nchar(dep_row$depends_on[1]) > 0) {
    parent_ids <- as.integer(jsonlite::fromJSON(dep_row$depends_on[1]))
  } else { 
    parent_ids <- integer(0) 
  }
  depends_on_str <- ifelse(length(parent_ids) > 0, paste(parent_ids, collapse = ", "), "")

  should_skip <- FALSE
  stored_hash <- NULL
  dependency_status <- "Not applicable"

  if (!is_checksum_empty) {
    hash_query <- paste0("SELECT checksum FROM ", cohort_schema, ".", checksum_table,
      " WHERE cohort_definition_id = ", cohort_id)
    hash_result <- try(DatabaseConnector::querySql(conn, hash_query), silent = TRUE)
    if (!inherits(hash_result, "try-error") && nrow(hash_result) > 0) {
      stored_hash <- hash_result$CHECKSUM[1]
    }
  }

  if (cohort_type %in% c("subset", "union", "complement", "composite", "oprior", "tprior", "censor")) {
    current_dependency_hash <- compute_dependency_hash(dbPath, cohort, cohort_hashes)

    if (is_stale) {
      dependency_status <- "Stale - parent changed"
      should_skip <- FALSE
    } else if (!is_checksum_empty && !is.null(stored_hash)) {
      if (!is.na(stored_hash) && stored_hash == current_dependency_hash) {
        dependency_status <- "Unchanged"
        should_skip <- TRUE
      } else { 
        dependency_status <- "Parent changed" 
      }
    } else { 
        dependency_status <- "New" 
    }
  } else {
    current_hash <- cohort$getHash()
    if (!is.null(stored_hash) && !is.na(stored_hash) && stored_hash == current_hash) {
      should_skip <- TRUE
    }
  }

  skip_status <- list(
    should_skip = should_skip, 
    dependency_status = dependency_status,
    stored_hash = stored_hash, 
    is_stale = is_stale,
    parent_ids = parent_ids, 
    depends_on_str = depends_on_str
  )
  return(skip_status)
}

generate_single_cohort <- function(
    cohort, 
    cohort_id, 
    db_conn,
    settings,
    table_names,
    sqlite_conn,
    is_stale, 
    stored_hash, 
    cohort_hashes,
    dbPath
) {
  cohort_label <- cohort$label
  cohort_type <- cohort$getCohortType()
  cohort_sql <- cohort$getSql()

  if (is.null(cohort_sql) || !is.character(cohort_sql) || nchar(cohort_sql) == 0) {
    return(error_result_row(cohort_id, cohort_label, cohort_type, "SQL is null or empty", cohort_hashes))
  }

  if (cohort_type == "custom") {
    .validateCustomSql(cohort_sql, cohort_label)
  } 
  # prep generation params
  cohort_schema <- settings$workDatabaseSchema
  sql_params <- list(
    cdm_database_schema = settings$cdmDatabaseSchema,
    vocabulary_database_schema = settings$cdmDatabaseSchema,
    target_database_schema = cohort_schema,
    target_cohort_table = settings$cohortTable,
    target_cohort_id = cohort_id,
    results_database_schema.cohort_inclusion = paste(cohort_schema, table_names$cohortInclusionTable, sep = "."),
    results_database_schema.cohort_inclusion_result = paste(cohort_schema, table_names$cohortInclusionResultTable, sep = "."),
    results_database_schema.cohort_inclusion_stats = paste(cohort_schema, table_names$cohortInclusionStatsTable, sep = "."),
    results_database_schema.cohort_summary_stats = paste(cohort_schema, table_names$cohortSummaryStatsTable, sep = "."),
    results_database_schema.cohort_censor_stats = paste(cohort_schema, table_names$cohortCensorStatsTable, sep = "."),
    warnOnMissingParameters = FALSE
  )

  if (cohort_type %in% c("subset", "union", "complement", "composite", "oprior", "tprior", "censor")) {
    output_table_name <- paste(cohort_schema, settings$cohortTable, sep = ".")
    sql_params$output_cohort_id <- cohort_id
    sql_params$output_table <- output_table_name
    sql_params$base_cohort_table <- output_table_name
  }

  render_result <- try(do.call(SqlRender::render, c(list(sql = cohort_sql), sql_params)), silent = TRUE)
  if (inherits(render_result, "try-error")) {
    ee <- error_result_row(cohort_id, cohort_label, cohort_type, as.character(render_result), cohort_hashes)
    return(ee)
  }
    

  translate_result <- try(
    SqlRender::translate(
        sql = render_result, 
        targetDialect = settings$getDbms(),
        tempEmulationSchema = settings$tempEmulationSchema
        ), 
    silent = TRUE
    )
  translate_result <- stringr::str_replace_all(translate_result, "\r", "\n")
  if (inherits(translate_result, "try-error")) {
    ee <- error_result_row(cohort_id, cohort_label, cohort_type, as.character(translate_result), cohort_hashes)
    return(ee)
  }
    

  start_time <- Sys.time()
  result <- try(
    DatabaseConnector::executeSql(
        db_conn, 
        translate_result,
        progressBar = FALSE, 
        reportOverallTime = FALSE
        ), 
    silent = TRUE)

  end_time <- Sys.time()
  execution_time_min <- as.numeric(difftime(end_time, start_time, units = "mins"))

  if (inherits(result, "try-error")) {
    ee <- error_result_row(cohort_id, cohort_label, cohort_type, as.character(result), cohort_hashes, execution_time_min)
    return(ee)
  }

  hash_to_store <- if (cohort_type %in% c("circe", "custom")) {
    cohort$getHash()
  } else {
    compute_dependency_hash(dbPath, cohort, cohort_hashes)
  }

  if (is.null(stored_hash)) {

    checksum_data <- data.frame(
      cohort_definition_id = cohort_id, 
      checksum = hash_to_store,
      start_time = NA_real_, 
      end_time = as.numeric(difftime(end_time, start_time, units = "secs")),
      stringsAsFactors = FALSE
    )

    try(
        DatabaseConnector::insertTable(
            connection = db_conn,
            tableName = paste(cohort_schema, table_names$cohortChecksumTable, sep = "."),
            data = checksum_data, 
            dropTableIfExists = FALSE, 
            createTable = FALSE, 
            tempTable = FALSE
            ), 
        silent = FALSE
    )

  } else {

    update_sql <- paste0("UPDATE ", cohort_schema, ".", table_names$cohortChecksumTable,
      " SET checksum = '", hash_to_store, "', end_time = ",
      as.numeric(difftime(end_time, start_time, units = "secs")),
      " WHERE cohort_definition_id = ", cohort_id)
    try(
        DatabaseConnector::executeSql(
            db_conn, update_sql,
            progressBar = FALSE, reportOverallTime = FALSE
            ), 
        silent = FALSE
    )
  }

  if (isTRUE(is_stale)) {
    DBI::dbExecute(sqlite_conn,
      "UPDATE cohort_manifest SET status = 'active', updated_at = CURRENT_TIMESTAMP WHERE id = ?",
      list(cohort_id))
  }

  cohort_hashes[[as.character(cohort_id)]] <- hash_to_store

  sng_cohort <- list(
    result_row = data.frame(
      cohort_id = cohort_id, 
      label = cohort_label, 
      cohort_type = cohort_type,
      depends_on = "", 
      execution_time_min = execution_time_min,
      status = "Success", 
      dependency_status = "", 
      stringsAsFactors = FALSE
    ),
    cohort_hashes = cohort_hashes
  )
  return(sng_cohort)
}


error_result_row <- function(
    cohort_id, 
    cohort_label, 
    cohort_type, 
    error_msg,
    cohort_hashes, 
    execution_time_min = NA_real_) {
  rr <- list(
    result_row = data.frame(
      cohort_id = cohort_id, label = cohort_label, cohort_type = cohort_type,
      depends_on = "", execution_time_min = execution_time_min,
      status = paste("Error:", error_msg), dependency_status = "",
      stringsAsFactors = FALSE),
    cohort_hashes = cohort_hashes
  )
  return(rr)
}

report_cohort_results <- function(results_df) {
  cli::cli_rule()
  total_time_min <- sum(results_df$execution_time_min[results_df$status == "Success"], na.rm = TRUE)
  successful <- sum(results_df$status == "Success")
  skipped <- sum(results_df$status == "Skipped - already generated")
  failed <- sum(grepl("Error:", results_df$status))

  if ("cohort_type" %in% names(results_df)) {
    circe_count <- sum(results_df$cohort_type == "circe", na.rm = TRUE)
    custom_count <- sum(results_df$cohort_type == "custom", na.rm = TRUE)
    dependent_count <- sum(results_df$cohort_type %in% c("subset", "union", "complement", "composite", "oprior", "tprior", "censor"), na.rm = TRUE)
    cli::cli_alert_info("Cohort types: {circe_count} circe + {custom_count} custom + {dependent_count} dependent")
  }

  cli::cli_alert_success("Cohort generation complete")
  cli::cli_alert_info("Total cohorts: {nrow(results_df)} | Successful: {successful} | Skipped: {skipped} | Failed: {failed}")
  cli::cli_alert_info("Total execution time: {total_time_min |> round(2)} min")

  return(results_df)
}


# ---- Stratified Cohorts ----

#' Convert a stratum definition to a SQL WHERE condition
#'
#' @param stratum_def Either a named list of demographic filters or a raw SQL
#'   character string. List keys: `genderConceptIds`, `raceConceptIds`,
#'   `ethnicityConceptIds`, `minAge`, `maxAge`.
#'
#' @return Character. A single SQL boolean expression referencing `bc` (cohort
#'   table alias) and `p` (person table alias).
#'
#' @noRd
.stratum_to_sql_condition <- function(stratum_def) {

  if (is.character(stratum_def)) {
    return(stratum_def)
  }

  checkmate::assert_list(stratum_def, names = "named")

  parts <- character(0)

  if (!is.null(stratum_def$genderConceptIds)) {
    ids <- paste(as.integer(stratum_def$genderConceptIds), collapse = ", ")
    parts <- c(parts, paste0("p.gender_concept_id IN (", ids, ")"))
  }

  if (!is.null(stratum_def$raceConceptIds)) {
    ids <- paste(as.integer(stratum_def$raceConceptIds), collapse = ", ")
    parts <- c(parts, paste0("p.race_concept_id IN (", ids, ")"))
  }

  if (!is.null(stratum_def$ethnicityConceptIds)) {
    ids <- paste(as.integer(stratum_def$ethnicityConceptIds), collapse = ", ")
    parts <- c(parts, paste0("p.ethnicity_concept_id IN (", ids, ")"))
  }

  if (!is.null(stratum_def$minAge)) {
    parts <- c(parts, paste0("YEAR(bc.cohort_start_date) - p.year_of_birth >= ", as.integer(stratum_def$minAge)))
  }

  if (!is.null(stratum_def$maxAge)) {
    parts <- c(parts, paste0("YEAR(bc.cohort_start_date) - p.year_of_birth <= ", as.integer(stratum_def$maxAge)))
  }

  if (length(parts) == 0) {
    cli::cli_abort("Stratum definition is empty — provide at least one filter condition.")
  }

  partsFinal <- paste(parts, collapse = " AND ")
  return(partsFinal)
}

# Window Functions --------------

SubsetWindowOperator <- R6::R6Class(
  classname = "SubsetWindowOperator",
  private = list(
    .windowType = NULL,
    .subsetCohortWindowAnchor = NULL,
    .startDays = NULL,
    .endDays = NULL,
    .baseCohortWindowAnchor = NULL
  ),
  public = list(
    initialize = function(
      windowType,
      subsetCohortWindowAnchor,
      startDays,
      endDays,
      baseCohortWindowAnchor
    ) {
      # check inputs are valid
      checkmate::assert_choice(x = windowType, choices = c("startWindow", "endWindow"))
      checkmate::assert_choice(x = subsetCohortWindowAnchor, choices = c("cohort_start_date", "cohort_end_date"))
      checkmate::assert_integerish(x = startDays, len = 1)
      checkmate::assert_integerish(x = endDays, len = 1)
      checkmate::assert_choice(x = baseCohortWindowAnchor, choices = c("cohort_start_date", "cohort_end_date"))

      # assign to private fields
      private$.windowType <- windowType
      private$.subsetCohortWindowAnchor <- subsetCohortWindowAnchor
      private$.startDays <- startDays
      private$.endDays <- endDays
      private$.baseCohortWindowAnchor <- baseCohortWindowAnchor

    },

    makeSubsetWindowSql = function() {
      start_anchor <- private$.subsetCohortWindowAnchor
      start_day <- private$.startDays
      end_day <- private$.endDays
      window_anchor <- private$.baseCohortWindowAnchor
      sql <- glue::glue(
        "AND (fc.{start_anchor} >= DATEADD(day,{start_day}, bc.{window_anchor}) AND fc.{start_anchor} <= DATEADD(d, {end_day}, bc.{window_anchor}))"
      )
      return(sql)
    }

  ),
  active = list(
    windowType = function(value) {
      if (missing(value)) {
        private$.windowType
      } else {
        checkmate::assert_choice(x = value, choices = c("startWindow", "endWindow"))
        private$.windowType <- value
      }
    },
    subsetCohortWindowAnchor = function(value) {
      if (missing(value)) {
        private$.subsetCohortWindowAnchor
      } else {
        checkmate::assert_choice(x = value, choices = c("cohort_start_date", "cohort_end_date"))
        private$.subsetCohortWindowAnchor <- value
      }
    },
    startDays = function(value) {
      if (missing(value)) {
        private$.startDays
      } else {
        checkmate::assert_integerish(x = value, len = 1)
        private$.startDays <- value
      }
    },
    endDays = function(value) {
      if (missing(value)) {
        private$.endDays
      } else {
        checkmate::assert_integerish(x = value, len = 1)
        private$.endDays <- value
      }
    },
    baseCohortWindowAnchor = function(value) {
      if (missing(value)) {
        private$.baseCohortWindowAnchor
      } else {
        checkmate::assert_choice(x = value, choices = c("cohort_start_date", "cohort_end_date"))
        private$.baseCohortWindowAnchor <- value
      }
    }
  )
)

#' Create a Subset Start Window Operator
#'
#' @description
#' Convenience wrapper to create a SubsetWindowOperator for defining the temporal window
#' for a subset cohort's start date relative to the filter cohort event.
#'
#' @param subsetCohortWindowAnchor Character. Whether to anchor to the filter cohort's
#'   'cohort_start_date' or 'cohort_end_date'. Determines which date from the filter
#'   cohort event is used as the reference point.
#' @param startDays Integer. The number of days from the base cohort anchor to the start
#'   of the window. Negative values indicate days before the base cohort date.
#' @param endDays Integer. The number of days from the base cohort anchor to the end
#'   of the window. Negative values indicate days before the base cohort date.
#' @param baseCohortWindowAnchor Character. Whether to anchor the window to the base cohort's
#'   'cohort_start_date' or 'cohort_end_date'. Default: 'cohort_start_date'.
#'
#' @return A SubsetWindowOperator object configured for start window filtering.
#'
#' @examples
#' # Create a start window: filter cohort must start within 365 days before to 0 days
#' # after the base cohort start date
#' start_w <- createSubsetStartWindow(
#'   subsetCohortWindowAnchor = "cohort_start_date",
#'   startDays = -365,
#'   endDays = 0,
#'   baseCohortWindowAnchor = "cohort_start_date"
#' )
#'
#' @export
createSubsetStartWindow <- function(
    subsetCohortWindowAnchor,
    startDays,
    endDays,
    baseCohortWindowAnchor = "cohort_start_date") {

  SubsetWindowOperator$new(
    windowType = "startWindow",
    subsetCohortWindowAnchor = subsetCohortWindowAnchor,
    startDays = startDays,
    endDays = endDays,
    baseCohortWindowAnchor = baseCohortWindowAnchor
  )
}

#' Create a Subset End Window Operator
#'
#' @description
#' Convenience wrapper to create a SubsetWindowOperator for defining the temporal window
#' for a subset cohort's end date relative to the filter cohort event.
#'
#' @param subsetCohortWindowAnchor Character. Whether to anchor to the filter cohort's
#'   'cohort_start_date' or 'cohort_end_date'. Determines which date from the filter
#'   cohort event is used as the reference point.
#' @param startDays Integer. The number of days from the base cohort anchor to the start
#'   of the window. Negative values indicate days before the base cohort date.
#' @param endDays Integer. The number of days from the base cohort anchor to the end
#'   of the window. Negative values indicate days before the base cohort date.
#' @param baseCohortWindowAnchor Character. Whether to anchor the window to the base cohort's
#'   'cohort_start_date' or 'cohort_end_date'. Default: 'cohort_end_date'.
#'
#' @return A SubsetWindowOperator object configured for end window filtering.
#'
#' @examples
#' # Create an end window: filter cohort must end within 0 to 90 days
#' # after the base cohort end date
#' end_w <- createSubsetEndWindow(
#'   subsetCohortWindowAnchor = "cohort_end_date",
#'   startDays = 0,
#'   endDays = 90,
#'   baseCohortWindowAnchor = "cohort_end_date"
#' )
#'
#' @export
createSubsetEndWindow <- function(
    subsetCohortWindowAnchor,
    startDays,
    endDays,
    baseCohortWindowAnchor = "cohort_end_date") {

  SubsetWindowOperator$new(
    windowType = "endWindow",
    subsetCohortWindowAnchor = subsetCohortWindowAnchor,
    startDays = startDays,
    endDays = endDays,
    baseCohortWindowAnchor = baseCohortWindowAnchor
  )
}