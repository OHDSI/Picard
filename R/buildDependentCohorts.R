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

#' Build a Subset Cohort Definition (Temporal)
#'
#' @description
#' Creates a SQL file and metadata for a subset cohort based on temporal filtering
#' between two cohorts. Returns a CohortDef object ready to add to a CohortManifest.
#'
#' @param label Character. User-friendly name for the subset (e.g., "CKD with T2D prior").
#' @param baseCohortId Integer. The cohort ID to subset.
#' @param filterCohortId Integer. The cohort ID to use for temporal filtering.
#' @param startWindow SubsetWindowOperator object. Defines the temporal window for the subset cohort start date
#'   relative to the filter cohort event.
#' @param endWindow SubsetWindowOperator object (optional, NULL allowed). Defines the temporal window for the 
#'   subset cohort end date relative to the filter cohort event. If NULL, the filter cohort end date is not used.
#' @param endDateType Character. Whether to use the base cohort end date ('base') or filter cohort end date ('filter')
#'   as the cohort end date in the output subset cohort. Default: 'base'.
#' @param subsetLimit Character. One of 'First', 'Last', or 'All'. Specifies which qualifying filter cohort event(s)
#'   to retain per subject. 'First' keeps the earliest event, 'Last' keeps the most recent event, 'All' keeps all 
#'   qualifying events. Default: 'First'.
#' @param cohortsFolder Character. Path to inputs/cohorts/. Defaults to `here::here("inputs/cohorts")`.
#' @param manifest CohortManifest object. Required. Validates that base cohorts exist and
#'   automatically registers the new cohort via addDependentCohort().
#'
#' @details
#' Creates three files:
#' - SQL file: `inputs/cohorts/derived/subset/subset_cohort_{baseCohortId}_cohort_{filterCohortId}.sql`
#' - Metadata JSON: Same path with `.json` extension (parameters for execution)
#' - Context file: `.metadata` with rule description
#'
#' @return A CohortDef object with cohortType='subset' and dependencies set.
#'
#' @examples
#' # Create subset: Chronic Kidney Disease patients with a Type 2 Diabetes diagnosis
#' # in the 365 days before or after their CKD start date
#'
#' # Define window for start date: T2D diagnosis must occur within 365 days before to 0 days after CKD start
#' start_window <- createSubsetStartWindow(
#'   subsetCohortWindowAnchor = "cohort_start_date",
#'   startDays = -365,
#'   endDays = 0,
#'   baseCohortWindowAnchor = "cohort_start_date"
#' )
#'
#' # Create the subset cohort: keep first T2D event per patient
#' ckd_with_t2d <- buildSubsetCohortTemporal(
#'   label = "CKD with recent T2D",
#'   baseCohortId = 101,
#'   filterCohortId = 102,
#'   startWindow = start_window,
#'   endWindow = NULL,
#'   endDateType = "base",
#'   subsetLimit = "First"
#' )
#'
#' @export
buildSubsetCohortTemporal <- function(
    label,
    baseCohortId,
    filterCohortId,
    startWindow,
    endWindow,
    endDateType = "base", 
    subsetLimit = "First",
    cohortsFolder = here::here("inputs/cohorts"),
    manifest) {

  # Validation
  checkmate::assert_string(x = label, min.chars = 1)
  checkmate::assert_integerish(x = baseCohortId, len = 1, lower = 1)
  checkmate::assert_integerish(x = filterCohortId, len = 1, lower = 1)
  checkmate::assert_choice(x = endDateType, choices = c("base", "filter"))
  checkmate::assert_choice(x = subsetLimit, choices = c("First", "All", "Last"))
  checkmate::assert_class(x = startWindow, classes = "SubsetWindowOperator")
  checkmate::assert_class(x = endWindow, classes = "SubsetWindowOperator", null.ok = TRUE)
  checkmate::assert_class(x = manifest, classes = "CohortManifest")

  # Validate base cohorts exist in manifest
  manifest_ids <- manifest$tabulateManifest(filter = "active")$id

  if (!baseCohortId %in% manifest_ids) {
    cli::cli_abort("Base cohort ID {baseCohortId} not found in manifest")
  }

  if (!filterCohortId %in% manifest_ids) {
    cli::cli_abort("Filter cohort ID {filterCohortId} not found in manifest")
  }

  # Create derived/subset directory if it doesn't exist
  subset_dir <- file.path(cohortsFolder, "derived", "subset")
  if (!dir.exists(subset_dir)) {
    dir.create(subset_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # Generate file names
  file_name <- sprintf("subset_cohort_%d_cohort_%d", baseCohortId, filterCohortId)
  sql_path <- file.path(subset_dir, paste0(file_name, ".sql"))
  metadata_path <- file.path(subset_dir, paste0(file_name, ".json"))

  # Load SQL template
  template_path <- system.file(
    "sql",
    "createSubsetCohort_Cohort.sql",
    package = "picard"
  )
  
  # get winow SQL from SubsetWindowOperator objects
  start_window <- startWindow$makeSubsetWindowSql()
  if (is.null(endWindow)) {
    end_window <- ""
  } else {
    end_window <- endWindow$makeSubsetWindowSql()
  }

  template_sql <- readr::read_file(template_path) |>
  SqlRender::render(
    base_cohort_id = baseCohortId,
    filter_cohort_id = filterCohortId,
    start_window = start_window,
    end_window = end_window,
    subset_limit = subsetLimit,
    end_date_type = endDateType
  )

  # Prepare metadata
  if (is.null(endWindow)) {
    endWindowMeta <- list(
      subsetCohortWindowAnchor = NA_character_,
      startDays = NA_integer_,
      endDays = NA_integer_,
      baseCohortWindowAnchor = NA_character_
    )
  } else {
    endWindowMeta <- list(
      subsetCohortWindowAnchor = endWindow$subsetCohortWindowAnchor,
      startDays = endWindow$startDays,
      endDays = endWindow$endDays,
      baseCohortWindowAnchor = endWindow$baseCohortWindowAnchor
    )
  }
  metadata <- list(
    type = "subset_temporal",
    label = label,
    baseCohortId = baseCohortId,
    filterCohortId = filterCohortId,
    startWindow = list(
      subsetCohortWindowAnchor = startWindow$subsetCohortWindowAnchor,
      startDays = startWindow$startDays,
      endDays = startWindow$endDays,
      baseCohortWindowAnchor = startWindow$baseCohortWindowAnchor
    ),
    endWindow = endWindowMeta,
    subsetLimit = subsetLimit,
    endDateType = endDateType,
    createdAt = Sys.time(),
    dependsOnCohortIds = c(baseCohortId, filterCohortId)
  )

  # Write SQL template to file
  writeLines(template_sql, con = sql_path)
  cli::cli_alert_success("Created composite cohort SQL: {fs::path_rel(sql_path)}")

  # Write metadata JSON
  jsonlite::write_json(metadata, path = metadata_path, pretty = TRUE, auto_unbox = TRUE)
  cli::cli_alert_success("Created metadata file: {fs::path_rel(metadata_path)}")

  # Create and return CohortDef object
  cohort_def <- CohortDef$new(
    label = label,
    tags = list(
      type = "subset",
      baseCohortId = as.character(baseCohortId),
      filterCohortId = as.character(filterCohortId)
    ),
    filePath = sql_path
  )

  # Set dependent cohort metadata
  cohort_def$setCohortType("subset")
  cohort_def$setDependencies(
    dependsOnCohortIds = c(baseCohortId, filterCohortId),
    dependencyRule = list(
      type = "temporal"
    )
  )

  manifest$addDependentCohort(cohort_def)
  invisible(cohort_def)
}


#' Build a Subset Cohort Definition (Demographic)
#'
#' @description
#' Creates a SQL file and metadata for a subset cohort based on person-level demographics.
#' Returns a CohortDef object ready to add to a CohortManifest.
#'
#' @param label Character. User-friendly name for the subset (e.g., "CKD - Males 40-75")
#' @param baseCohortId Integer. The cohort ID to subset.
#' @param minAge Integer. Minimum age at cohort start. NULL = no minimum. Default: NULL
#' @param maxAge Integer. Maximum age at cohort start. NULL = no maximum. Default: NULL
#' @param genderConceptIds Numeric vector. Gender concept IDs to include. NULL = all. Default: NULL
#' @param raceConceptIds Numeric vector. Race concept IDs to include. NULL = all. Default: NULL
#' @param ethnicityConceptIds Numeric vector. Ethnicity concept IDs to include. NULL = all. Default: NULL
#' @param cohortsFolder Character. Path to inputs/cohorts/. Defaults to `here::here("inputs/cohorts")`.
#' @param manifest CohortManifest object. Required. Validates that the base cohort exists and
#'   automatically registers the new cohort via addDependentCohort().
#'
#' @details
#' Creates three files:
#' - SQL file: `inputs/cohorts/derived/subset_demo/subset_demo_cohort_{baseCohortId}.sql`
#' - Metadata JSON: Same path with `.json` extension
#' - Context file: `.metadata` with filter description
#'
#' @return A CohortDef object with cohortType='subset' and dependencies set.
#'
#' @export
buildSubsetCohortDemographic <- function(
    label,
    baseCohortId,
    minAge = NULL,
    maxAge = NULL,
    genderConceptIds = NULL,
    raceConceptIds = NULL,
    ethnicityConceptIds = NULL,
    cohortsFolder = here::here("inputs/cohorts"),
    manifest) {

  # Validation
  checkmate::assert_string(x = label, min.chars = 1)
  checkmate::assert_integerish(x = baseCohortId, len = 1, lower = 1)
  checkmate::assert_integerish(x = minAge, len = 1, lower = 0, null.ok = TRUE)
  checkmate::assert_integerish(x = maxAge, len = 1, lower = 0, null.ok = TRUE)
  checkmate::assert_vector(x = genderConceptIds, null.ok = TRUE)
  checkmate::assert_vector(x = raceConceptIds, null.ok = TRUE)
  checkmate::assert_vector(x = ethnicityConceptIds, null.ok = TRUE)
  checkmate::assert_class(x = manifest, classes = "CohortManifest")

  # Validate base cohort exists in manifest
  manifest_ids <- manifest$tabulateManifest(filter = "active")$id

  if (!baseCohortId %in% manifest_ids) {
    cli::cli_abort("Base cohort ID {baseCohortId} not found in manifest")
  }

  # Create derived/subset_demo directory if it doesn't exist
  subset_dir <- file.path(cohortsFolder, "derived", "subset_demo")
  if (!dir.exists(subset_dir)) {
    dir.create(subset_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # Generate unique hash from demographic parameters
  params_for_hash <- list(
    minAge = minAge,
    maxAge = maxAge,
    genderConceptIds = genderConceptIds,
    raceConceptIds = raceConceptIds,
    ethnicityConceptIds = ethnicityConceptIds
  )
  params_json <- jsonlite::toJSON(params_for_hash, auto_unbox = TRUE)
  params_hash <- substr(rlang::hash(params_json), 1, 8)

  # Generate file names with hash to ensure uniqueness
  file_name <- sprintf("subset_demo_cohort_%d_%s", baseCohortId, params_hash)
  sql_path <- file.path(subset_dir, paste0(file_name, ".sql"))
  metadata_path <- file.path(subset_dir, paste0(file_name, ".json"))

  # Load SQL template
  template_path <- system.file(
    "sql",
    "createSubsetCohort_Person.sql",
    package = "picard"
  )
  

  # Prepare metadata - convert NULLs to empty strings for SqlRender template conditions
  # SqlRender checks {@param != ''} so empty strings will work correctly
  metadata <- list(
    type = "subset_demographic",
    label = label,
    baseCohortId = baseCohortId,
    minAge = ifelse(is.null(minAge), "", minAge),
    maxAge = ifelse(is.null(maxAge), "", maxAge),
    genderConceptIds = ifelse(is.null(genderConceptIds) || length(genderConceptIds) == 0, "", ifelse(length(genderConceptIds) == 1, as.character(genderConceptIds[1]), paste(genderConceptIds, collapse = ","))),
    raceConceptIds = ifelse(is.null(raceConceptIds) || length(raceConceptIds) == 0, "", ifelse(length(raceConceptIds) == 1, as.character(raceConceptIds[1]), paste(raceConceptIds, collapse = ","))),
    ethnicityConceptIds = ifelse(is.null(ethnicityConceptIds) || length(ethnicityConceptIds) == 0, "", ifelse(length(ethnicityConceptIds) == 1, as.character(ethnicityConceptIds[1]), paste(ethnicityConceptIds, collapse = ","))),
    createdAt = Sys.time(),
    dependsOnCohortIds = c(baseCohortId)
  )

  template_sql <- readr::read_file(template_path) |>
  SqlRender::render(
    base_cohort_id = metadata$baseCohortId,
    min_age = metadata$minAge,
    max_age = metadata$maxAge,
    gender_concept_ids = metadata$genderConceptIds,
    race_concept_ids = metadata$raceConceptIds,
    ethnicity_concept_ids = metadata$ethnicityConceptIds
  )

  # Write SQL template to file
  writeLines(template_sql, con = sql_path)
  cli::cli_alert_success("Created composite cohort SQL: {fs::path_rel(sql_path)}")

  # Write metadata JSON
  jsonlite::write_json(metadata, path = metadata_path, pretty = TRUE, auto_unbox = TRUE)
  cli::cli_alert_success("Created metadata file: {fs::path_rel(metadata_path)}")

  # Create and return CohortDef object
  cohort_def <- CohortDef$new(
    label = label,
    tags = list(
      type = "subset_demographic",
      baseCohortId = as.character(baseCohortId),
      minAge = ifelse(!is.null(minAge), as.character(minAge), "NA"),
      maxAge = ifelse(!is.null(maxAge), as.character(maxAge), "NA")
    ),
    filePath = sql_path
  )

  # Set dependent cohort metadata
  cohort_def$setCohortType("subset")
  cohort_def$setDependencies(
    dependsOnCohortIds = c(baseCohortId),
    dependencyRule = list(
      type = "demographic",
      minAge = minAge,
      maxAge = maxAge,
      genderConceptIds = genderConceptIds,
      raceConceptIds = raceConceptIds,
      ethnicityConceptIds = ethnicityConceptIds
    )
  )

  manifest$addDependentCohort(cohort_def)
  invisible(cohort_def)
}

#' Build a Union Cohort Definition
#'
#' @description
#' Creates a SQL file and metadata for a union cohort that combines multiple input cohorts
#' using a gaps-and-islands collapse algorithm. Overlapping or adjacent eras are merged
#' into continuous periods. Returns a CohortDef object ready to add to a CohortManifest.
#'
#' @param label Character. User-friendly name for the union (e.g., "Chronic Kidney Disease Phenotypes")
#' @param cohortIds Numeric vector (minimum 2). Cohort IDs to union.
#' @param gapDays Integer. Bridge eras separated by up to this many days. Default: 0 (only
#'   overlapping periods collapse).
#' @param eraPadDays Integer. Expand each source period by this many days on each end before
#'   collapsing. Applied to individual periods, not the collapsed result. Default: 0.
#' @param minEraDays Integer. Drop collapsed eras shorter than this many days. Default: 0
#'   (keep all eras).
#' @param minCohorts Integer. Only include subjects appearing in at least this many distinct
#'   source cohorts. Default: 1 (any subject from any cohort).
#' @param washoutDays Integer. Require a clean period of at least this many days before a
#'   new era can open. Subjects must have no source cohort membership for this period.
#'   Default: 0.
#' @param firstEraOnly Logical. Return only the first collapsed era per subject. Default: FALSE.
#' @param cohortsFolder Character. Path to inputs/cohorts/. Defaults to `here::here("inputs/cohorts")`.
#' @param manifest CohortManifest object. Required. Validates that all input cohorts exist.
#'
#' @details
#' Creates two files:
#' - SQL file: `inputs/cohorts/derived/union/union_cohorts_{cohort_id_list}.sql`
#' - Metadata JSON: Same path with `.json` extension
#'
#' @return A CohortDef object with cohortType='union' and dependencies set.
#'
#' @export
buildUnionCohort <- function(
    label,
    cohortIds,
    gapDays = 0L,
    eraPadDays = 0L,
    minEraDays = 0L,
    minCohorts = 1L,
    washoutDays = 0L,
    firstEraOnly = FALSE,
    cohortsFolder = here::here("inputs/cohorts"),
    manifest) {

  # Validation
  checkmate::assert_string(x = label, min.chars = 1)
  checkmate::assert_integerish(x = cohortIds, min.len = 2, unique = TRUE, lower = 1)
  checkmate::assert_integerish(x = gapDays, len = 1, lower = 0)
  checkmate::assert_integerish(x = eraPadDays, len = 1, lower = 0)
  checkmate::assert_integerish(x = minEraDays, len = 1, lower = 0)
  checkmate::assert_integerish(x = minCohorts, len = 1, lower = 1)
  checkmate::assert_integerish(x = washoutDays, len = 1, lower = 0)
  checkmate::assert_logical(x = firstEraOnly, len = 1)
  checkmate::assert_class(x = manifest, classes = "CohortManifest")

  # Validate all input cohorts exist in manifest
  manifest_ids <- manifest$tabulateManifest(filter = "active")$id
  missing_ids <- setdiff(cohortIds, manifest_ids)

  if (length(missing_ids) > 0) {
    cli::cli_abort("Input cohort {if (length(missing_ids) == 1) 'ID' else 'IDs'} {paste(missing_ids, collapse = ', ')} not found in manifest")
  }

  # Create derived/union directory if it doesn't exist
  union_dir <- file.path(cohortsFolder, "derived", "union")
  if (!dir.exists(union_dir)) {
    dir.create(union_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # Generate file names
  cohort_ids_str <- paste(cohortIds, collapse = "_")
  file_name <- sprintf("union_cohorts_%s", cohort_ids_str)
  sql_path <- file.path(union_dir, paste0(file_name, ".sql"))
  metadata_path <- file.path(union_dir, paste0(file_name, ".json"))

  # Load SQL template
  template_path <- system.file(
    "sql",
    "createUnionCohort.sql",
    package = "picard"
  )
  template_sql <- readr::read_file(template_path) |>
    SqlRender::render(
      cohort_ids = paste(cohortIds, collapse = ", "),
      gap_days = gapDays,
      era_pad_days = eraPadDays,
      min_era_days = minEraDays,
      min_cohorts = minCohorts,
      washout_days = washoutDays,
      first_era_only = as.integer(firstEraOnly)
    )

  # Prepare metadata
  metadata <- list(
    type = "union",
    label = label,
    cohortIds = as.list(as.integer(cohortIds)),
    gapDays = as.integer(gapDays),
    eraPadDays = as.integer(eraPadDays),
    minEraDays = as.integer(minEraDays),
    minCohorts = as.integer(minCohorts),
    washoutDays = as.integer(washoutDays),
    firstEraOnly = firstEraOnly,
    createdAt = Sys.time(),
    dependsOnCohortIds = as.integer(cohortIds)
  )

  # Write SQL template to file
  writeLines(template_sql, con = sql_path)
  cli::cli_alert_success("Created composite cohort SQL: {fs::path_rel(sql_path)}")

  # Write metadata JSON
  jsonlite::write_json(metadata, path = metadata_path, pretty = TRUE, auto_unbox = TRUE)
  cli::cli_alert_success("Created metadata file: {fs::path_rel(metadata_path)}")

  # Create and return CohortDef object
  cohort_def <- CohortDef$new(
    label = label,
    tags = list(
      type = "union",
      cohortCount = as.character(length(cohortIds))
    ),
    filePath = sql_path
  )

  # Set dependent cohort metadata
  cohort_def$setCohortType("union")
  cohort_def$setDependencies(
    dependsOnCohortIds = as.integer(cohortIds),
    dependencyRule = list(
      type = "union",
      gapDays = as.integer(gapDays),
      eraPadDays = as.integer(eraPadDays),
      minEraDays = as.integer(minEraDays),
      minCohorts = as.integer(minCohorts),
      washoutDays = as.integer(washoutDays),
      firstEraOnly = firstEraOnly
    )
  )

  manifest$addDependentCohort(cohort_def)
  invisible(cohort_def)
}


#' Build a Complement Cohort Definition
#'
#' @description
#' Creates a SQL file and metadata for a complement cohort that excludes subjects
#' from a population cohort based on other cohorts.
#' Returns a CohortDef object ready to add to a CohortManifest.
#'
#' @param label Character. User-friendly name for the complement (e.g., "Females without Pregnancy")
#' @param populationCohortId Integer. The population/base cohort ID.
#' @param excludeCohortIds Numeric vector (minimum 1). Cohort IDs to exclude.
#' @param complementType Character. One of 'exclude_any', 'exclude_all'. Default: 'exclude_any'
#'   - 'exclude_any': remove subjects in ANY exclude cohort
#'   - 'exclude_all': remove subjects only if in ALL exclude cohorts
#' @param cohortsFolder Character. Path to inputs/cohorts/. Defaults to `here::here("inputs/cohorts")`.
#' @param manifest CohortManifest object. Required. Validates that population and exclude cohorts exist and
#'   automatically registers the new cohort via addDependentCohort().
#'
#' @details
#' Creates three files:
#' - SQL file: `inputs/cohorts/derived/complement/complement_cohort_{popId}_exclude_{excludeIds}.sql`
#' - Metadata JSON: Same path with `.json` extension
#' - Context file: `.metadata` with rule description
#'
#' @return A CohortDef object with cohortType='complement' and dependencies set.
#'
#' @export
buildComplementCohort <- function(
    label,
    populationCohortId,
    excludeCohortIds,
    complementType = "exclude_any",
    cohortsFolder = here::here("inputs/cohorts"),
    manifest) {

  # Validation
  checkmate::assert_string(x = label, min.chars = 1)
  checkmate::assert_integerish(x = populationCohortId, len = 1, lower = 1)
  checkmate::assert_integerish(x = excludeCohortIds, min.len = 1, unique = TRUE, lower = 1)
  checkmate::assert_choice(x = complementType, choices = c("exclude_any", "exclude_all"))
  checkmate::assert_class(x = manifest, classes = "CohortManifest")

  # Ensure populationCohortId not in excludeCohortIds
  if (populationCohortId %in% excludeCohortIds) {
    cli::cli_abort("Population cohort ID {populationCohortId} cannot be in exclude list")
  }

  # Validate population and exclude cohorts exist in manifest
  manifest_ids <- manifest$tabulateManifest(filter = "active")$id

  if (!populationCohortId %in% manifest_ids) {
    cli::cli_abort("Population cohort ID {populationCohortId} not found in manifest")
  }

  missing_ids <- setdiff(excludeCohortIds, manifest_ids)

  if (length(missing_ids) > 0) {
    cli::cli_abort("Exclude cohort {if (length(missing_ids) == 1) 'ID' else 'IDs'} {paste(missing_ids, collapse = ', ')} not found in manifest")
  }

  # Create derived/complement directory if it doesn't exist
  complement_dir <- file.path(cohortsFolder, "derived", "complement")
  if (!dir.exists(complement_dir)) {
    dir.create(complement_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # Generate file names
  exclude_ids_str <- paste(excludeCohortIds, collapse = "_")
  file_name <- sprintf("complement_cohort_%d_exclude_%s_%s", populationCohortId, exclude_ids_str, complementType)
  sql_path <- file.path(complement_dir, paste0(file_name, ".sql"))
  metadata_path <- file.path(complement_dir, paste0(file_name, ".json"))

  # Load SQL template
  template_path <- system.file(
    "sql",
    "createComplementCohort.sql",
    package = "picard"
  )
  template_sql <- readr::read_file(template_path) |>
  SqlRender::render(
    population_cohort_id = populationCohortId,
    exclude_cohort_ids = paste(excludeCohortIds, collapse = ", "),
    exclude_cohort_ids_count = length(excludeCohortIds),
    complement_type = complementType
  )

  # Prepare metadata
  metadata <- list(
    type = "complement",
    label = label,
    populationCohortId = populationCohortId,
    excludeCohortIds = as.list(as.integer(excludeCohortIds)),
    complementType = complementType,
    createdAt = Sys.time(),
    dependsOnCohortIds = c(populationCohortId, as.integer(excludeCohortIds))
  )

  # Write SQL template to file
  writeLines(template_sql, con = sql_path)
  cli::cli_alert_success("Created composite cohort SQL: {fs::path_rel(sql_path)}")

  # Write metadata JSON
  jsonlite::write_json(metadata, path = metadata_path, pretty = TRUE, auto_unbox = TRUE)
  cli::cli_alert_success("Created metadata file: {fs::path_rel(metadata_path)}")

  # Create and return CohortDef object
  all_deps <- c(populationCohortId, as.integer(excludeCohortIds))
  
  cohort_def <- CohortDef$new(
    label = label,
    tags = list(
      type = "complement",
      populationCohortId = as.character(populationCohortId),
      excludeCount = as.character(length(excludeCohortIds)),
      complementType = complementType
    ),
    filePath = sql_path
  )

  # Set dependent cohort metadata
  cohort_def$setCohortType("complement")
  cohort_def$setDependencies(
    dependsOnCohortIds = all_deps,
    dependencyRule = list(
      type = "complement",
      populationCohortId = populationCohortId,
      excludeCohortIds = as.integer(excludeCohortIds),
      rule = complementType
    )
  )

  manifest$addDependentCohort(cohort_def)
  invisible(cohort_def)
}

#' Build a Composite Cohort Definition
#'
#' @description
#' Creates a SQL file and metadata for a composite cohort that combines multiple cohort definitions.
#' A composite cohort groups subjects who have at least N qualifying events from a set of cohort definitions.
#' Returns a CohortDef object ready to add to a CohortManifest.
#'
#' @param label Character. User-friendly name for the composite (e.g., "Diabetes mellitus").
#' @param criteriaCohortIds Integer vector. The cohort IDs to include in the composite
#'   (e.g., c(1, 2, 3) for Type 1 diabetes, Type 2 diabetes, and secondary diabetes).
#' @param minimumEventCount Integer. Minimum number of distinct cohort events required for a subject
#'   to qualify for the composite. Default: 1 (any subject with at least 1 event qualifies).
#' @param eventSelection Character. One of 'First', 'Last', or 'All'. Specifies which event(s) to
#'   retain as the cohort_start_date and cohort_end_date in the output:
#'   - 'First': Keep the earliest event (earliest index date)
#'   - 'Last': Keep the most recent event
#'   - 'All': Keep all qualifying events per subject (may result in multiple rows per subject)
#'   Default: 'First'.
#' @param cohortsFolder Character. Path to inputs/cohorts/. Defaults to `here::here("inputs/cohorts")`.
#' @param manifest CohortManifest object. Required. Validates that all criteria cohorts exist and
#'   automatically registers the new cohort via addDependentCohort().
#'
#' @details
#' Creates three files:
#' - SQL file: `inputs/cohorts/derived/composite/composite_cohort_{hash}.sql`
#' - Metadata JSON: Same path with `.json` extension (parameters for execution)
#' - Hash ensures uniqueness when same criteria are used with different labels
#'
#' @return A CohortDef object with cohortType='composite' and dependencies set.
#'
#' @examples
#' # Create a composite cohort for diabetes (any type): Type 1, Type 2, or secondary diabetes
#' # Keep only subjects with at least 1 event (any diagnosis), using first event as index date
#'
#' diabetes_cohort <- buildCompositeCohort(
#'   label = "Diabetes mellitus (any type)",
#'   criteriaCohortIds = c(101, 102, 103),
#'   minimumEventCount = 1,
#'   eventSelection = "First"
#' )
#'
#' @export
buildCompositeCohort <- function(
    label,
    criteriaCohortIds,
    minimumEventCount = 1,
    eventSelection = "First",
    cohortsFolder = here::here("inputs/cohorts"),
    manifest) {

  # Validation
  checkmate::assert_string(x = label, min.chars = 1)
  checkmate::assert_integerish(x = criteriaCohortIds, lower = 1, min.len = 1)
  checkmate::assert_integerish(x = minimumEventCount, len = 1, lower = 1)
  checkmate::assert_choice(x = eventSelection, choices = c("First", "Last", "All"))
  checkmate::assert_class(x = manifest, classes = "CohortManifest")

  # Validate criteria cohorts exist in manifest
  manifest_ids <- manifest$tabulateManifest(filter = "active")$id
  missing_ids <- setdiff(criteriaCohortIds, manifest_ids)

  if (length(missing_ids) > 0) {
    cli::cli_abort("Criteria cohort IDs not found in manifest: {paste(missing_ids, collapse = ', ')}")
  }

  # Create derived/composite directory if it doesn't exist
  composite_dir <- file.path(cohortsFolder, "derived", "composite")
  if (!dir.exists(composite_dir)) {
    dir.create(composite_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # Generate unique hash from parameters to ensure uniqueness
  params_for_hash <- list(
    criteriaCohortIds = sort(criteriaCohortIds),
    minimumEventCount = minimumEventCount,
    eventSelection = eventSelection
  )
  params_json <- jsonlite::toJSON(params_for_hash, auto_unbox = TRUE)
  params_hash <- substr(rlang::hash(params_json), 1, 8)

  # Generate file names
  file_name <- sprintf("composite_cohort_%s", params_hash)
  sql_path <- file.path(composite_dir, paste0(file_name, ".sql"))
  metadata_path <- file.path(composite_dir, paste0(file_name, ".json"))

  # Load SQL template
  template_path <- system.file(
    "sql",
    "createCompositeCohort.sql",
    package = "picard"
  )

  # Format cohort IDs for SQL IN clause
  cohort_ids_str <- paste(criteriaCohortIds, collapse = ",")

  template_sql <- readr::read_file(template_path) |>
  SqlRender::render(
    criteria_cohort_ids = cohort_ids_str,
    minimum_event_count = minimumEventCount,
    event_selection = eventSelection
  )

  # Prepare metadata
  metadata <- list(
    type = "composite",
    label = label,
    criteriaCohortIds = as.integer(criteriaCohortIds),
    minimumEventCount = minimumEventCount,
    eventSelection = eventSelection,
    createdAt = Sys.time(),
    dependsOnCohortIds = as.integer(criteriaCohortIds)
  )

  # Write SQL template to file
  writeLines(template_sql, con = sql_path)
  cli::cli_alert_success("Created composite cohort SQL: {fs::path_rel(sql_path)}")

  # Write metadata JSON
  jsonlite::write_json(metadata, path = metadata_path, pretty = TRUE, auto_unbox = TRUE)
  cli::cli_alert_success("Created metadata file: {fs::path_rel(metadata_path)}")

  # Create and return CohortDef object
  cohort_def <- CohortDef$new(
    label = label,
    tags = list(
      type = "composite",
      criteriaCohortIds = paste(criteriaCohortIds, collapse = ",")
    ),
    filePath = sql_path
  )

  # Set dependent cohort metadata
  cohort_def$setCohortType("composite")
  cohort_def$setDependencies(
    dependsOnCohortIds = as.integer(criteriaCohortIds),
    dependencyRule = list(
      type = "composite",
      minimumEventCount = minimumEventCount,
      eventSelection = eventSelection
    )
  )

  manifest$addDependentCohort(cohort_def)
  invisible(cohort_def)
}
