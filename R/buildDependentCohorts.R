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
#' @param manifest CohortManifest object. Required. Validates that base cohorts exist and
#'   automatically registers the new cohort.
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
    endWindow = NULL,
    endDateType = "base",
    subsetLimit = "First",
    category = "derived",
    manifest) {

  checkmate::assert_string(x = label, min.chars = 1)
  checkmate::assert_integerish(x = baseCohortId, len = 1, lower = 1)
  checkmate::assert_integerish(x = filterCohortId, len = 1, lower = 1)
  checkmate::assert_class(x = startWindow, classes = "SubsetWindowOperator")
  checkmate::assert_class(x = endWindow, classes = "SubsetWindowOperator", null.ok = TRUE)
  checkmate::assert_string(x = category, min.chars = 1)
  checkmate::assert_class(x = manifest, classes = "CohortManifest")

  manifest$buildSubsetCohortTemporal(
    label          = label,
    baseCohortId   = as.integer(baseCohortId),
    filterCohortId = as.integer(filterCohortId),
    category       = category,
    startWindow    = startWindow,
    endWindow      = endWindow,
    endDateType    = endDateType,
    subsetLimit    = subsetLimit
  )
}


#' Build a Demographic Subset Cohort
#'
#' @description
#' `r lifecycle::badge("deprecated")` Use `manifest$buildDemographicCohort()` instead.
#'
#' @param label Character. User-friendly name for the subset (e.g., "CKD - Males 40-75")
#' @param baseCohortId Integer. The cohort ID to subset.
#' @param minAge Integer. Minimum age at cohort start. NULL = no minimum. Default: NULL
#' @param maxAge Integer. Maximum age at cohort start. NULL = no maximum. Default: NULL
#' @param genderConceptIds Numeric vector. Gender concept IDs to include. NULL = all. Default: NULL
#' @param raceConceptIds Numeric vector. Race concept IDs to include. NULL = all. Default: NULL
#' @param ethnicityConceptIds Numeric vector. Ethnicity concept IDs to include. NULL = all. Default: NULL
#' @param manifest CohortManifest object. Required.
#'
#' @return Invisible integer. The assigned cohort ID.
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
    manifest) {

  lifecycle::deprecate_warn(
    "0.0.3", "buildSubsetCohortDemographic()",
    what2 = "CohortManifest$buildDemographicCohort()"
  )

  checkmate::assert_class(x = manifest, classes = "CohortManifest")

  manifest$buildDemographicCohort(
    label               = label,
    baseCohortId        = as.integer(baseCohortId),
    category            = "derived",
    minAge              = minAge,
    maxAge              = maxAge,
    genderConceptIds    = genderConceptIds,
    raceConceptIds      = raceConceptIds,
    ethnicityConceptIds = ethnicityConceptIds
  )
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
    manifest) {

  lifecycle::deprecate_warn(
    "0.0.3", "buildUnionCohort()",
    what2 = "CohortManifest$buildUnionCohort()",
    details = "Use the R6 method: `manifest$buildUnionCohort(label, cohortIds, category, ...)`"
  )

  checkmate::assert_class(x = manifest, classes = "CohortManifest")

  manifest$buildUnionCohort(
    label     = label,
    cohortIds = as.integer(cohortIds),
    category  = "derived",
    gapDays   = as.integer(gapDays)
  )
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
#' @param manifest CohortManifest object. Required. Validates that population and exclude cohorts exist.
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
    manifest) {

  lifecycle::deprecate_warn(
    "0.0.3", "buildComplementCohort()",
    what2 = "CohortManifest$buildComplementCohort()"
  )

  checkmate::assert_class(x = manifest, classes = "CohortManifest")

  manifest$buildComplementCohort(
    label             = label,
    populationCohortId = as.integer(populationCohortId),
    excludeCohortIds  = as.integer(excludeCohortIds),
    category          = "derived",
    complementType    = complementType
  )
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
#' @param manifest CohortManifest object. Required. Validates that all criteria cohorts exist.
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
    manifest) {

  lifecycle::deprecate_warn(
    "0.0.3", "buildCompositeCohort()",
    what2 = "CohortManifest$buildCompositeCohort()",
    details = "Use the R6 method: `manifest$buildCompositeCohort(label, cohortIds, category, ...)`"
  )

  checkmate::assert_class(x = manifest, classes = "CohortManifest")

  manifest$buildCompositeCohort(
    label      = label,
    cohortIds  = as.integer(criteriaCohortIds),
    category   = "derived",
    minCohorts = as.integer(minimumEventCount)
  )
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


#' Split a Base Cohort into Multiple Stratified Sub-Cohorts
#'
#' @description
#' Splits a single base cohort into N named stratum cohorts plus an automatic
#' **Unclassified** cohort containing subjects that match none of the named
#' strata. Each stratum is registered as a separate entry in the manifest with
#' an auto-assigned ID and `cohortType = "subset"`. A single SQL file is written
#' per stratum so `generateCohorts()` processes them independently.
#'
#' @details
#' Strata can be defined in two ways and may be mixed in the same call:
#'
#' **Demographic (named list):**
#' ```r
#' list(
#'   "Male"   = list(genderConceptIds = 8507),
#'   "Female" = list(genderConceptIds = 8532),
#'   "65+"    = list(minAge = 65)
#' )
#' ```
#' Supported keys: `genderConceptIds`, `raceConceptIds`, `ethnicityConceptIds`,
#' `minAge`, `maxAge`. Multiple keys within one stratum are `AND`-ed.
#'
#' **Custom SQL WHERE clause (character string):**
#' ```r
#' list(
#'   "West"  = "p.location_id IN (1, 4, 5, 6, 12)",
#'   "South" = "p.location_id IN (2, 3, 8, 9, 10)"
#' )
#' ```
#' The expression may reference `bc` (cohort table alias) and `p` (person
#' table alias).
#'
#' An **Unclassified** stratum is always appended automatically. Its WHERE
#' condition is the logical negation of every named stratum combined with
#' `AND NOT (...)`, ensuring every subject in the base cohort appears in exactly
#' one output cohort.
#'
#' @param baseCohortId Integer. The cohort definition ID to split.
#' @param strata Named list. Each element is either a named list of demographic
#'   filters or a character string SQL WHERE condition. Names become cohort
#'   labels (optionally prefixed by `labelPrefix`).
#' @param labelPrefix Character or `NULL`. If provided, prepended to each
#'   stratum name with a ` - ` separator (e.g. `"CKD"` + `"Male"` →
#'   `"CKD - Male"`).
#' @param manifest A `CohortManifest` object. Required. Cohort IDs are
#'   auto-assigned from the next available manifest ID — never supply them
#'   manually.
#'
#' @return Invisibly returns a named list of cohort IDs, keyed by the full cohort label.
#'
#' @export
buildStratifiedCohorts <- function(
    baseCohortId,
    strata,
    labelPrefix = NULL,
    manifest) {

  lifecycle::deprecate_warn(
    "0.0.3", "buildStratifiedCohorts()",
    what2 = "CohortManifest$buildStratifiedCohorts()"
  )

  checkmate::assert_class(x = manifest, classes = "CohortManifest")

  manifest$buildStratifiedCohorts(
    baseCohortId = as.integer(baseCohortId),
    strata       = strata,
    labelPrefix  = labelPrefix,
    category     = "derived"
  )
}
