# ================================================================================
# File: buildDependentCohorts.R
# ================================================================================
#
# Study: {studyName}
# Author: {author}
# Purpose: {description}
#
# This script builds dependent/derived cohorts that are defined by their
# relationship to other cohorts already in the manifest.
# It is designed to be sourced as part of the pre-pipeline setup workflow.
#
# Examples of dependent cohorts:
#   - Temporal: "CKD in patients with prior Diabetes"
#   - Union: "Diabetes OR Hypertension"
#   - Complement: "All patients NOT with CKD"
#   - Composite: "Patients in multiple cohorts"
#   - Demographic: "Subset by age/sex/race/ethnicity"
#   - Stratified: "Split base cohort into strata"
#   - O-Prior-T: "Outcome after prior target exposure"
#   - T-Prior-O: "Target exposure after prior outcome"
#   - Censor: "Target exposure censored at death"
#   - Custom dependent SQL: "Dependency-aware SQL cohort"

library(picard)

# ================================================================================
# A. LOAD MANIFEST
# ================================================================================

# Load the manifest (assumes base cohorts are already loaded)
cohortManifest <- loadCohortManifest()

# Review existing cohorts to reference in dependent cohort definitions
cohortManifest$tabulateManifest()


# ================================================================================
# B. BUILD DEPENDENT COHORTS
# ================================================================================

# Note: Replace cohort IDs with actual IDs from your manifest
# Base cohorts must already exist in the manifest before building dependents


# ---- Example: Temporal Relationship ----
# Build "CKD given prior diabetes" using a start-window definition.

# startWindow <- createSubsetStartWindow(
#   subsetCohortWindowAnchor = "cohort_start_date",
#   startDays = -365,
#   endDays = 0,
#   baseCohortWindowAnchor = "cohort_start_date"
# )
#
# cohortManifest$buildSubsetCohortTemporal(
#   label = "CKD given prior T2D",
#   category = "Derived Cohorts",
#   baseCohortId = 1L,                  # CKD cohort ID
#   filterCohortId = 2L,                # T2D cohort ID
#   startWindow = startWindow
# )


# ---- Example: Union ----
# Combine two cohorts (Diabetes OR Hypertension)

# cohortManifest$buildUnionCohort(
#   label = "Diabetes or Hypertension",
#   category = "Disease Populations",
#   cohortIds = c(1L, 3L),
#   gapDays = 0L
# )


# ---- Example: Complement ----
# All patients in a population cohort excluding one or more comparator cohorts.

# cohortManifest$buildComplementCohort(
#   label = "No CKD",
#   category = "Control Populations",
#   populationCohortId = 1L,
#   excludeCohortIds = c(2L),
#   complementType = "exclude_any"
# )


# ---- Example: Composite ----
# Build a cohort requiring membership across multiple source cohorts.

# cohortManifest$buildCompositeCohort(
#   label = "CKD and T2D Composite",
#   category = "Derived Cohorts",
#   criteriaCohortIds = c(1L, 2L),
#   minEventCount = 2L,
#   eventSelection = "First"
# )


# ---- Example: Demographic Subset ----
# Subset a base cohort by age, gender, race, or ethnicity.

# cohortManifest$buildDemographicCohort(
#   label = "CKD in Males Aged 65+",
#   baseCohortId = 1L,
#   category = "Disease Populations",
#   minAge = 65L,
#   genderConceptIds = c(8507L)  # Male
# )


# ---- Example: Stratified Cohorts ----
# Split one base cohort into multiple named strata.

# strata <- list(
#   "Female" = list(genderConceptIds = c(8532L)),
#   "Male" = list(genderConceptIds = c(8507L)),
#   "Age_65_plus" = list(minAge = 65L)
# )
#
# cohortManifest$buildStratifiedCohorts(
#   baseCohortId = 1L,
#   strata = strata,
#   labelPrefix = "CKD",
#   category = "Derived Cohorts"
# )


# ---- Example: Outcome Prior Target (O-Prior-T) ----
# Events where outcome occurs before target exposure
# e.g., "GI Bleed in patients with prior NSAID use"

# cohortManifest$buildOPriorT(
#   label = "GI Bleed - Prior NSAID",
#   category = "Outcomes",
#   outcomeCohortId = 1L,
#   targetCohortId = 2L,
#   mode = "prior",
#   priorTimeWindowDays = 365,
#   subsetLimit = "First"
# )


# ---- Example: Target Prior Outcome (T-Prior-O) ----
# Events where target exposure occurs before outcome
# e.g., "NSAID use in patients with prior GI Bleed"

# cohortManifest$buildTPriorO(
#   label = "NSAID - Prior GI Bleed",
#   category = "Exposures",
#   targetCohortId = 2L,
#   outcomeCohortId = 1L,
#   mode = "prior",
#   priorTimeWindowDays = NULL,
#   subsetLimit = "First"
# )


# ---- Example: Censor at Event ----
# Censor target cohort when a censoring event occurs
# e.g., "NSAID use censored at death"

# cohortManifest$buildCensorCohort(
#   label = "NSAID - Censored at Death",
#   category = "Exposures",
#   targetCohortId = 2L,
#   censorCohortId = 3L,
#   tags = list(censored = TRUE)
# )


# ---- Example: Custom Dependent SQL Cohort ----
# Register a dependency-aware custom SQL cohort that references existing cohorts
# via SqlRender parameters in the SQL file.

# cohortManifest$addDependentCustomCohort(
#   filePath = here::here("inputs/cohorts/sql/my_custom_dependent.sql"),
#   label = "Eligible_With_Exclusions",
#   category = "Derived Cohorts",
#   dependentCohortIdList = list(
#     inc_cohort_id = 1001L,
#     exc_cohort_id = 1002L
#   ),
#   tags = list(owner = "epi_team", source = "custom_sql")
# )

# SQL contract reminder for my_custom_dependent.sql:
#   - Use @inc_cohort_id and @exc_cohort_id placeholders (or your own named keys)
#   - DELETE from @target_database_schema.@target_cohort_table by @target_cohort_id
#   - INSERT into @target_database_schema.@target_cohort_table
#       (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)

# Note that users can build dependent sql cohorts with templates via R functions. Any
# code should be saved in inputs/cohorts/R/src. add another folder called /sql in here
# for the templates! 


# ================================================================================
# C. REVIEW DEPENDENT COHORTS
# ================================================================================

# Display a table of all cohorts including newly built dependents
cohortManifest$tabulateManifest()

# Optionally, export and inspect specific cohorts:
# cohortDef <- cohortManifest$getCohortDefinition(cohortId = 10L)
# print(cohortDef)

cli::cli_alert_success("Dependent cohorts built successfully!")


# ================================================================================
# D. USAGE NOTES
# ================================================================================
#
# Important reminders:
#   1. Base cohorts (referenced by ID) must exist in the manifest first
#   2. Cohort IDs can be found by running: cohortManifest$tabulateManifest()
#   3. Tag dependent cohorts appropriately for filtering/analysis
#   4. Document the logic behind each dependent cohort (comments)
#   5. Test dependent cohort logic in smaller database first
#
# See picard documentation for:
#   - Advanced temporal relationships
#   - Window definitions (days, months, years)
#   - Index event definitions
#   - Attrition rules for dependent cohorts
