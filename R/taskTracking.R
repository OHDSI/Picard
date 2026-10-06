#' @importFrom digest digest
#' @title Check if Task Needs to be Rerun
#' @description Determines whether a task needs to be rerun by checking:
#'   1. Task file modifications (file hash comparison)
#'   2. Dependency file modifications (extracted from source() calls)
#'   3. Cohort manifest changes — compares
#'      [CohortManifest$getManifestHash()][CohortManifest] (definitions plus
#'      label, category, and tags) against the hash recorded on the previous
#'      run. A rerun is forced when the hash differs,
#'      when no hash was recorded (first run, or a legacy history row), or when
#'      the current hash cannot be computed at all.
#'   4. Concept set manifest changes — compares
#'      [ConceptSetManifest$getManifestHash()][ConceptSetManifest]
#'      (definitions plus label, category, and tags) against the hash recorded
#'      on the previous run, with the same fail-safe rules as the cohort
#'      manifest check.
#'   5. renv lockfile changes — any change to the R version or to a package
#'      recorded in `renv.lock` forces a rerun (see [.getRenvLockHash()]).
#'   6. Previous run errors (checked in logs and history)
#'   7. Version changes. History is scoped by task, config block, and
#'      `pipeline_version`, so separate test namespaces do not reuse one
#'      another's run state.
#'
#' @param taskFile Character. Name or path of the task file (e.g., "task1.R")
#' @param configBlock Character. The config block name (e.g., "optum_dod")
#' @param executionSettings ExecutionSettings object
#' @param pipelineVersion Character. Current pipeline version (e.g., "1.0.0")
#' @param tasksFolderPath Character. Path to tasks folder (default: here::here("analysis/tasks"))
#' @param cohortManifestHash Character or NULL. A pre-computed cohort manifest
#'   hash (see [.getCohortManifestHash()]). When NULL (default) it is computed
#'   here; callers that check many tasks in one run pass it in to avoid
#'   re-loading the manifest per task.
#' @param conceptSetManifestHash Character or NULL. A pre-computed concept set
#'   manifest hash (see [.getConceptSetManifestHash()]). Computed here when NULL.
#' @param renvLockHash Character or NULL. A pre-computed renv lockfile hash
#'   (see [.getRenvLockHash()]). Computed here when NULL.
#'
#' @return List with elements:
#'   - should_rerun: Logical. TRUE if task should be rerun
#'   - reasons: Character vector. Why task should be rerun
#'   - last_run_info: List with previous run details (time, version, status)
#'   - task_file_hash: Current hash of task file
#'   - cohort_manifest_hash: Current hash of cohort manifest definitions
#'   - concept_set_manifest_hash: Current hash of concept set manifest
#'   - renv_lock_hash: Current hash of renv.lock
#'
#' @details
#' Creates/updates exec/logs/task_run_history.csv tracking:
#' - task_name, config_block, last_run_time, pipeline_version
#' - task_file_hash, cohort_manifest_hash, concept_set_manifest_hash,
#'   renv_lock_hash, status, error_message
#'
#' @export
shouldRerunTask <- function(
    taskFile,
    configBlock,
    executionSettings,
    pipelineVersion,
    tasksFolderPath = here::here("analysis/tasks"),
    cohortManifestHash = NULL,
    conceptSetManifestHash = NULL,
    renvLockHash = NULL) {

  # Initialize result structure
  reasons <- character()
  rerunNeeded <- FALSE

  # Ensure task file path
  if (!file.exists(taskFile)) {
    taskFile <- fs::path(tasksFolderPath, taskFile)
  }

  if (!file.exists(taskFile)) {
    cli::cli_alert_warning("Task file not found: {taskFile}")
    return(list(
      should_rerun = TRUE,
      reasons = "Task file does not exist",
      last_run_info = NULL,
      task_file_hash = NA_character_,
      cohort_hash_status = NULL
    ))
  }

  # Get current task file hash
  currentTaskHash <- digest::digest(file = taskFile, algo = "sha256")

  # Initialize task run history
  historyFile <- fs::path(here::here("exec/logs"), "task_run_history.csv")
  if (!dir.exists(fs::path_dir(historyFile))) {
    dir.create(fs::path_dir(historyFile), recursive = TRUE, showWarnings = FALSE)
  }

  historyDf <- .initializeTaskHistory(historyFile)

  # Find previous runs for this task, config block, and pipeline namespace.
  # Legacy rows without a pipeline_version are retained by the history reader
  # but intentionally do not match a named run, forcing a safe rerun.
  previousRuns <- historyDf[
    historyDf$task_name == basename(taskFile) &
      historyDf$config_block == configBlock &
      historyDf$pipeline_version == pipelineVersion,
    ]

  lastRunInfo <- NULL
  if (nrow(previousRuns) > 0) {
    # Get most recent run
    lastRunInfo <- previousRuns[nrow(previousRuns), ]
  }

  # Check 1: Task file has changed
  if (!is.null(lastRunInfo) && !is.na(lastRunInfo$task_file_hash)) {
    if (lastRunInfo$task_file_hash != currentTaskHash) {
      reasons <- c(reasons, "Task file content has changed")
      rerunNeeded <- TRUE
    }
  } else {
    reasons <- c(reasons, "No previous run record found")
    rerunNeeded <- TRUE
  }

  # Check 2: Dependency files have changed
  dependencyChanges <- .checkDependencyChanges(taskFile, lastRunInfo)
  if (length(dependencyChanges) > 0) {
    reasons <- c(reasons, paste("Dependency changed:", dependencyChanges))
    rerunNeeded <- TRUE
  }

  # Checks 3-5: study inputs and environment have changed
  currentCohortManifestHash <- cohortManifestHash %||% .getCohortManifestHash(configBlock = configBlock)
  currentConceptSetManifestHash <- conceptSetManifestHash %||% .getConceptSetManifestHash()
  currentRenvLockHash <- renvLockHash %||% .getRenvLockHash()

  hashReasons <- c(
    .compareRecordedHash(currentCohortManifestHash, lastRunInfo$cohort_manifest_hash, "cohort manifest"),
    .compareRecordedHash(currentConceptSetManifestHash, lastRunInfo$concept_set_manifest_hash, "concept set manifest"),
    .compareRecordedHash(currentRenvLockHash, lastRunInfo$renv_lock_hash, "renv lockfile")
  )
  if (length(hashReasons) > 0) {
    reasons <- c(reasons, hashReasons)
    rerunNeeded <- TRUE
  }

  # Check 6: Previous run had errors
  if (!is.null(lastRunInfo) && lastRunInfo$status == "failed") {
    reasons <- c(reasons, "Previous run failed - needs rerun")
    rerunNeeded <- TRUE
  }

  # If no reasons found, task is up to date. Version is part of the lookup
  # key above, so a different namespace cannot be selected as lastRunInfo.
  if (length(reasons) == 0) {
    reasons <- "No changes detected - task is up to date"
    message <- cli::format_inline("Task {.file {basename(taskFile)}} is up to date and can be skipped")
  } else {
    message <- cli::format_inline(
      "Task {.file {basename(taskFile)}} should be rerun:\n",
      "{paste('  •', reasons, collapse = '\n')}"
    )
  }

  if (rerunNeeded) {
    cli::cli_alert_warning(message)
  } else {
    cli::cli_alert_success(message)
  }
   ll <- list(
    should_rerun = rerunNeeded,
    reasons = reasons,
    last_run_info = if (nrow(previousRuns) > 0) previousRuns else NULL,
    task_file_hash = currentTaskHash,
    cohort_manifest_hash = currentCohortManifestHash,
    concept_set_manifest_hash = currentConceptSetManifestHash,
    renv_lock_hash = currentRenvLockHash
  )
  return(ll)
}


#' @title Record Task Execution Status
#' @description Updates the task_run_history.csv file with execution results.
#'
#' @param taskFile Character. Name of the task file
#' @param configBlock Character. Config block name
#' @param pipelineVersion Character. Pipeline version
#' @param status Character. Execution status ("success", "failed", "skipped")
#' @param cohortManifestHash Character. Hash of cohort manifest at time of execution (optional)
#' @param errorMessage Character. Error message if status is "failed" (optional)
#' @param tasksFolderPath Character. Path to tasks folder (optional)
#' @param commitSha Character. HEAD commit SHA at execution time, from the
#'   pre-flight code-state check (optional).
#' @param codeState Character. Provenance of the working tree at execution time:
#'   \code{"clean"}, \code{"dirty-ignored"} (uncommitted changes were tolerated
#'   under configured ignore paths), \code{"unverified-skipped"} (the code-state
#'   check was skipped), \code{"unverified-test-mode"}, or \code{"unrecorded"}
#'   for calls outside a pipeline run. Recorded so the audit trail never implies
#'   a clean tree when the tree was not clean.
#' @param conceptSetManifestHash Character. Hash of concept set manifest at time
#'   of execution (optional)
#' @param renvLockHash Character. Hash of renv.lock at time of execution (optional)
#'
#' @return Invisibly TRUE if successful
#' @export
recordTaskExecution <- function(
    taskFile,
    configBlock,
    pipelineVersion,
    status,
    cohortManifestHash = NA_character_,
    errorMessage = NA_character_,
    tasksFolderPath = here::here("analysis/tasks"),
    commitSha = NA_character_,
    codeState = "unrecorded",
    conceptSetManifestHash = NA_character_,
    renvLockHash = NA_character_) {

  # Tolerate NULL as "no hash" so the data.frame row below always has length 1.
  cohortManifestHash <- cohortManifestHash %||% NA_character_
  conceptSetManifestHash <- conceptSetManifestHash %||% NA_character_
  renvLockHash <- renvLockHash %||% NA_character_

  if (!file.exists(taskFile)) {
    taskFile <- fs::path(tasksFolderPath, taskFile)
  }

  taskFileName <- basename(taskFile)

  # Validate status
  validStatus <- c("success", "failed", "skipped")
  if (!status %in% validStatus) {
    cli::cli_alert_danger("Invalid status: {status}")
    stop("Status must be one of: success, failed, skipped")
  }

  # Get task file hash
  taskHash <- digest::digest(file = taskFile, algo = "sha256")

  # Initialize or load history
  historyFile <- fs::path(here::here("exec/logs"), "task_run_history.csv")
  if (!dir.exists(fs::path_dir(historyFile))) {
    dir.create(fs::path_dir(historyFile), recursive = TRUE, showWarnings = FALSE)
  }

  historyDf <- .initializeTaskHistory(historyFile)

  # Create new record
  newRecord <- data.frame(
    task_name = taskFileName,
    config_block = configBlock,
    last_run_time = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    pipeline_version = pipelineVersion,
    task_file_hash = taskHash,
    cohort_manifest_hash = ifelse(is.na(cohortManifestHash), "", cohortManifestHash),
    concept_set_manifest_hash = ifelse(is.na(conceptSetManifestHash), "", conceptSetManifestHash),
    renv_lock_hash = ifelse(is.na(renvLockHash), "", renvLockHash),
    status = status,
    error_message = ifelse(is.na(errorMessage), "", errorMessage),
    commit_sha = ifelse(is.na(commitSha), "", as.character(commitSha)),
    code_state = ifelse(is.na(codeState), "unrecorded", as.character(codeState)),
    stringsAsFactors = FALSE
  )

  # Append to history
  historyDf <- rbind(historyDf, newRecord)

  # Write updated history
  tryCatch({
    readr::write_csv(historyDf, historyFile, append = FALSE)
    cli::cli_alert_success(
      "Task execution recorded: {taskFileName} [{status}] on {configBlock}"
    )
  }, error = function(e) {
    cli::cli_alert_danger("Failed to write task history: {e$message}")
    warning("Could not update task_run_history.csv")
  })

  invisible(TRUE)
}


#' @title Initialize Task Run History
#' @description Creates or loads the task_run_history.csv file.
#' @param historyFile Character. Path to history file
#' @return Data frame with history records
#' @keywords internal
.initializeTaskHistory <- function(historyFile) {
  if (!file.exists(historyFile)) {
    return(.createEmptyHistory())
  }

  historyDf <- tryCatch(
    .readTaskHistory(historyFile),
    error = function(e) {
      cli::cli_alert_warning("Could not read task history file, creating new one")
      .createEmptyHistory()
    }
  )

  .ensureHistoryColumns(historyDf)
}


#' @title Read Task Run History
#' @description Reads task_run_history.csv as all-character columns. Every column
#'   is read permissively so that history files written by older picard versions
#'   — which lack the \code{commit_sha} and \code{code_state} provenance columns
#'   — still load; missing columns are back-filled by [.ensureHistoryColumns()].
#' @param historyFile Character. Path to history file
#' @return Data frame with history records
#' @keywords internal
.readTaskHistory <- function(historyFile) {
  readr::read_csv(
    historyFile,
    show_col_types = FALSE,
    col_types = readr::cols(.default = readr::col_character())
  )
}


#' @title Back-fill Task History Columns
#' @description Adds any columns missing from a history data frame and orders
#'   them to match [.createEmptyHistory()]. Rows written before the provenance
#'   columns existed are marked \code{"unrecorded"} rather than \code{"clean"},
#'   so an old row is never mistaken for a verified-clean run.
#' @param historyDf Data frame of history records
#' @return Data frame with the full column set
#' @keywords internal
.ensureHistoryColumns <- function(historyDf) {
  template <- .createEmptyHistory()

  if (is.null(historyDf) || !is.data.frame(historyDf)) {
    return(template)
  }

  historyDf <- as.data.frame(historyDf, stringsAsFactors = FALSE)

  for (column in names(template)) {
    if (!column %in% names(historyDf)) {
      historyDf[[column]] <- if (identical(column, "code_state")) {
        "unrecorded"
      } else {
        ""
      }
    } else {
      historyDf[[column]] <- as.character(historyDf[[column]])
      historyDf[[column]][is.na(historyDf[[column]])] <- ""
    }
  }

  historyDf[, names(template), drop = FALSE]
}


#' @title Create Empty History Data Frame
#' @return Empty data frame with proper columns
#' @keywords internal
.createEmptyHistory <- function() {
  data.frame(
    task_name = character(),
    config_block = character(),
    last_run_time = character(),
    pipeline_version = character(),
    task_file_hash = character(),
    cohort_manifest_hash = character(),
    concept_set_manifest_hash = character(),
    renv_lock_hash = character(),
    status = character(),
    error_message = character(),
    commit_sha = character(),
    code_state = character(),
    stringsAsFactors = FALSE
  )
}


#' @title Check for Dependency File Changes
#' @description Extracts source() calls from task file and checks if dependencies changed.
#' @param taskFile Character. Path to task file
#' @param lastRunInfo Data frame row. Previous run record
#' @return Character vector of changed dependency files
#' @keywords internal
.checkDependencyChanges <- function(taskFile, lastRunInfo) {
  changedDeps <- character()

  tryCatch({
    taskContent <- readr::read_file(taskFile)

    # Extract source() calls
    sourcePattern <- 'source\\s*\\(\\s*["\']([^"\']+)["\']'
    sourceMatches <- gregexpr(sourcePattern, taskContent, perl = TRUE)
    matches <- regmatches(taskContent, sourceMatches)

    if (length(matches[[1]]) > 0) {
      for (match in matches[[1]]) {
        # Extract file path from source() call
        depFile <- gsub(sourcePattern, "\\1", match, perl = TRUE)

        # Make path absolute if relative
        if (!fs::is_absolute_path(depFile)) {
          depFile <- fs::path(fs::path_dir(taskFile), depFile)
        }

        if (file.exists(depFile)) {
          depHash <- digest::digest(file = depFile, algo = "sha256")

          # For now, since we don't store dep hashes, flag as changed if deps exist
          # In future this could track dependency hashes separately
          changedDeps <- c(changedDeps, basename(depFile))
        }
      }
    }
  }, error = function(e) {
    cli::cli_alert_warning("Could not check dependencies: {e$message}")
  })

  # Remove duplicates
  unique(changedDeps)
}


#' @title Get Cohort Manifest Hash
#' @description Loads a config block's cohort manifest and returns
#'   [CohortManifest$getManifestHash()][CohortManifest], a SHA256 digest over
#'   every registered (`active`/`stale`) cohort's definition and metadata
#'   (label, category, tags). Used by [shouldRerunTask()] to detect cohort
#'   changes that require a task rerun.
#' @details A thin wrapper around the manifest method, which is the single
#'   source of truth for what "the cohorts changed" means. The load
#'   is read-only (`autoSync = FALSE`), so this has no side effects. Any failure
#'   to load or hash the manifest returns `NA_character_`; [shouldRerunTask()]
#'   treats that as "cannot prove unchanged" and forces the rerun.
#' @param projectPath Character. A path inside the study repository. Defaults to
#'   the current project (`here::here()`).
#' @param configBlock Character or NULL. Config block whose
#'   `cohortManifestPath` names the manifest (see [getCohortManifestPath()]).
#'   NULL (default) uses the default manifest.
#' @return Character. SHA256 hex digest, or `NA_character_` if the manifest
#'   cannot be read.
#' @keywords internal
.getCohortManifestHash <- function(projectPath = here::here(), configBlock = NULL) {
  tryCatch({
    cm <- loadCohortManifest(
      cohortsFolderPath = projectPath,
      configBlock = configBlock,
      autoSync = FALSE,
      verbose = FALSE
    )
    cm$getManifestHash()
  }, error = function(e) {
    cli::cli_alert_warning("Could not compute cohort manifest hash: {e$message}")
    return(NA_character_)
  })
}


#' @title Get Concept Set Manifest Hash
#' @description Returns
#'   [ConceptSetManifest$getManifestHash()][ConceptSetManifest] for the study's
#'   concept set manifest. Used by [shouldRerunTask()] to detect concept set
#'   changes (including label/category/tag changes) that require a task rerun.
#' @details Concept sets are optional, so a study without a concept set
#'   manifest hashes to a stable sentinel rather than `NA` (which would force a
#'   rerun on every pipeline run). Any failure to read an existing manifest
#'   returns `NA_character_`, which [shouldRerunTask()] treats as "cannot prove
#'   unchanged" and forces the rerun.
#' @param projectPath Character. A path inside the study repository. Defaults to
#'   the current project (`here::here()`).
#' @return Character. SHA256 hex digest, `"<no-concept-set-manifest>"`, or
#'   `NA_character_` if the manifest cannot be read.
#' @keywords internal
.getConceptSetManifestHash <- function(projectPath = here::here()) {
  tryCatch({
    projectRoot <- findStudyProjectRoot(projectPath)
    dbPath <- fs::path(projectRoot, "inputs", "conceptSets", "conceptSetManifest.sqlite")
    if (!file.exists(dbPath)) {
      return("<no-concept-set-manifest>")
    }
    csm <- suppressMessages(
      ConceptSetManifest$new(dbPath = dbPath, projectRoot = projectRoot)
    )
    csm$getManifestHash()
  }, error = function(e) {
    cli::cli_alert_warning("Could not compute concept set manifest hash: {e$message}")
    return(NA_character_)
  })
}


#' @title Get renv Lockfile Hash
#' @description Returns a SHA256 digest over the R version and every package
#'   record (name, version, source, remote SHA) in the study's `renv.lock`.
#'   Used by [shouldRerunTask()] so that any package or R version change forces
#'   tasks to rerun.
#' @details Only the recorded versions are hashed, not the raw file, so
#'   reformatting the lockfile or reordering its entries does not force a
#'   rerun. The pipeline validates that the installed library matches
#'   `renv.lock` before running tasks, so the lockfile stands in for the
#'   installed package versions. A study without `renv.lock` hashes to a stable
#'   sentinel; a lockfile that cannot be parsed returns `NA_character_`, which
#'   forces a rerun.
#' @param projectPath Character. A path inside the study repository. Defaults to
#'   the current project (`here::here()`).
#' @return Character. SHA256 hex digest, `"<no-renv-lock>"`, or `NA_character_`
#'   if the lockfile cannot be read.
#' @keywords internal
.getRenvLockHash <- function(projectPath = here::here()) {
  tryCatch({
    lockPath <- fs::path(findStudyProjectRoot(projectPath), "renv.lock")
    if (!file.exists(lockPath)) {
      return("<no-renv-lock>")
    }

    lock <- jsonlite::read_json(lockPath)
    field <- function(x, name) as.character(x[[name]] %||% "")

    packages <- lock$Packages %||% list()
    packages <- packages[order(names(packages))]
    packageEntries <- vapply(
      packages,
      function(pkg) {
        paste(
          field(pkg, "Package"), field(pkg, "Version"),
          field(pkg, "Source"), field(pkg, "RemoteSha"),
          sep = "|"
        )
      },
      character(1),
      USE.NAMES = FALSE
    )

    entries <- c(paste0("R|", field(lock$R, "Version")), packageEntries)
    digest::digest(paste(entries, collapse = "\n"), algo = "sha256")
  }, error = function(e) {
    cli::cli_alert_warning("Could not compute renv lockfile hash: {e$message}")
    return(NA_character_)
  })
}


#' @title Compare a Current Hash Against the Recorded One
#' @description Fail-safe comparison shared by the input/environment checks in
#'   [shouldRerunTask()]. A rerun is required when the current hash cannot be
#'   computed, when no hash was recorded on the previous run (first run, or a
#'   history row written before the column existed), or when the hashes differ.
#' @param current Character or NULL. The hash computed for this run.
#' @param previous Character or NULL. The hash recorded on the previous run.
#' @param name Character. Human-readable name used in the rerun reason.
#' @return Character. A rerun reason, or `character(0)` when unchanged.
#' @keywords internal
.compareRecordedHash <- function(current, previous, name) {
  if (is.null(current) || is.na(current)) {
    return(paste0("Hash unavailable for ", name, " - forcing rerun"))
  }
  if (is.null(previous) || is.na(previous) || !nzchar(previous)) {
    return(paste0("No previous ", name, " hash recorded"))
  }
  if (!identical(as.character(previous), as.character(current))) {
    return(paste0("Change detected in ", name))
  }
  character(0)
}


#' @title Get Task Run Summary
#' @description Generates a summary of task execution history for display.
#' @param configBlock Character. Optional filter by config block
#' @param taskName Character. Optional filter by task name
#'
#' @return Data frame with task history summary
#' @export
getTaskRunSummary <- function(configBlock = NULL, taskName = NULL) {
  historyFile <- fs::path(here::here("exec/logs"), "task_run_history.csv")

  if (!file.exists(historyFile)) {
    cli::cli_alert_info("No task history found yet")
    return(data.frame())
  }

  historyDf <- tryCatch({
    .ensureHistoryColumns(.readTaskHistory(historyFile))
  }, error = function(e) {
    cli::cli_alert_danger("Failed to read task history: {e$message}")
    return(data.frame())
  })

  # Filter if specified
  if (!is.null(configBlock)) {
    historyDf <- historyDf[historyDf$config_block == configBlock, ]
  }

  if (!is.null(taskName)) {
    historyDf <- historyDf[historyDf$task_name == taskName, ]
  }

  return(historyDf)
}


#' @title Display Task Status Report
#' @description Displays a formatted report of recent task execution status.
#' @param limit Integer. Number of recent entries to show (default: 20)
#'
#' @return Invisibly NULL (prints to console)
#' @export
displayTaskStatusReport <- function(limit = 20) {
  historyFile <- fs::path(here::here("exec/logs"), "task_run_history.csv")

  if (!file.exists(historyFile)) {
    cli::cli_alert_info("No task execution history available yet")
    return(invisible(NULL))
  }

  historyDf <- tryCatch({
    .ensureHistoryColumns(.readTaskHistory(historyFile))
  }, error = function(e) {
    cli::cli_alert_danger("Failed to read task history: {e$message}")
    return(NULL)
  })

  if (is.null(historyDf) || nrow(historyDf) == 0) {
    cli::cli_alert_info("No task history records found")
    return(invisible(NULL))
  }

  # Get last N records
  historyDf <- tail(historyDf, limit)

  # Display summary
  cli::cli_rule("Task Execution History")

  successCount <- sum(historyDf$status == "success")
  failureCount <- sum(historyDf$status == "failed")
  skippedCount <- sum(historyDf$status == "skipped")

  cli::cli_bullets(c(
    "v" = "{successCount} successful",
    "x" = "{failureCount} failed",
    "i" = "{skippedCount} skipped"
  ))

  cli::cli_text("")

  # Group by config block and show latest
  configBlocks <- unique(historyDf$config_block)

  for (block in configBlocks) {
    blockData <- historyDf[historyDf$config_block == block, ]

    cli::cli_alert_info("Config Block: {block}")

    for (i in seq_len(nrow(blockData))) {
      row <- blockData[i, ]
      statusIcon <- switch(row$status,
        "success" = "✓",
        "failed" = "✗",
        "skipped" = "⊘",
        "?"
      )

      errMsg <- if (!is.na(row$error_message) && row$error_message != "") {
        paste0(" - ", row$error_message)
      } else {
        ""
      }

      codeMsg <- if (!is.na(row$code_state) && !row$code_state %in% c("", "clean")) {
        paste0(" [code state: ", row$code_state, "]")
      } else {
        ""
      }

      cat(sprintf(
        "  [%s] %s (%s v%s) at %s%s%s\n",
        statusIcon, row$task_name, row$config_block,
        row$pipeline_version, row$last_run_time, codeMsg, errMsg
      ))
    }
  }

  invisible(NULL)
}
