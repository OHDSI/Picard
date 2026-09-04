# ================================================================================
# File: buildDependentCohorts.R
# ================================================================================
#
# Study: <<studyName>>
# Author: <<author>>
# Purpose: <<description>>
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

# Preferred approach: look up cohorts by label to get entry rows, then pass those
# to the builder functions. This avoids hardcoding IDs that may change.
# Base cohorts must already exist in the manifest before building dependents.

# ---- Look up base cohort entries ----
# Replace labels with the actual cohort labels in your manifest.

# ckdEntry    <- cohortManifest$queryCohortsByLabel("Chronic Kidney Disease", matchType = "exact")
# t2dEntry    <- cohortManifest$queryCohortsByLabel("Type 2 Diabetes", matchType = "exact")
# bleedEntry  <- cohortManifest$queryCohortsByLabel("Major Bleeding Outcome", matchType = "exact")
# deathEntry  <- cohortManifest$queryCohortsByLabel("All-Cause Death", matchType = "exact")


# ---- Example: Temporal Relationship ----
# Build "CKD given prior T2D" using a start-window definition.

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
#   baseCohortEntry = ckdEntry,
#   filterCohortEntry = t2dEntry,
#   startWindow = startWindow
# )


# ---- Example: Union ----
# Combine two cohorts (CKD OR T2D)

# cohortManifest$buildUnionCohort(
#   label = "CKD or T2D",
#   category = "Disease Populations",
#   cohortEntries = dplyr::bind_rows(ckdEntry, t2dEntry),
#   gapDays = 0L
# )


# ---- Example: Complement ----
# All patients in a population cohort excluding one or more comparator cohorts.

# cohortManifest$buildComplementCohort(
#   label = "CKD Without T2D",
#   category = "Control Populations",
#   populationCohortEntry = ckdEntry,
#   excludeCohortEntries = t2dEntry,
#   complementType = "exclude_any"
# )


# ---- Example: Composite ----
# Build a cohort requiring membership across multiple source cohorts.

# cohortManifest$buildCompositeCohort(
#   label = "CKD and T2D Composite",
#   category = "Derived Cohorts",
#   criteriaCohortEntries = dplyr::bind_rows(ckdEntry, t2dEntry),
#   minEventCount = 2L,
#   eventSelection = "First"
# )


# ---- Example: Demographic Subset ----
# Subset a base cohort by age, gender, race, or ethnicity.

# cohortManifest$buildDemographicCohort(
#   label = "CKD in Males Aged 65+",
#   baseCohortEntry = ckdEntry,
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
#   baseCohortEntry = ckdEntry,
#   strata = strata,
#   labelPrefix = "CKD",
#   category = "Derived Cohorts"
# )


# ---- Example: Outcome Prior Target (O-Prior-T) ----
# Events where outcome occurs before target exposure
# e.g., "Bleeding in patients with prior T2D"

# cohortManifest$buildOPriorT(
#   label = "Bleed - Prior T2D",
#   category = "Outcomes",
#   outcomeCohortEntry = bleedEntry,
#   targetCohortEntry = t2dEntry,
#   mode = "prior",
#   priorTimeWindowDays = 365L,
#   subsetLimit = "First"
# )


# ---- Example: Target Prior Outcome (T-Prior-O) ----
# Events where target exposure occurs before outcome
# e.g., "T2D in patients with prior bleeding event"

# cohortManifest$buildTPriorO(
#   label = "T2D - Prior Bleed",
#   category = "Exposures",
#   targetCohortEntry = t2dEntry,
#   outcomeCohortEntry = bleedEntry,
#   mode = "prior",
#   priorTimeWindowDays = 365L,
#   subsetLimit = "First"
# )


# ---- Example: Censor at Event ----
# Censor target cohort when a censoring event occurs
# e.g., "T2D censored at All-Cause Death"

# cohortManifest$buildCensorCohort(
#   label = "T2D - Censored at Death",
#   category = "Exposures",
#   targetCohortEntry = t2dEntry,
#   censorCohortEntry = deathEntry
# )


# ---- Example: Custom Dependent SQL Cohort ----
# Register a dependency-aware custom SQL cohort that references existing cohorts
# via SqlRender parameters in the SQL file.

# incEntry <- cohortManifest$queryCohortsByLabel("Inclusion cohort")
# excEntry <- cohortManifest$queryCohortsByLabel("Exclusion cohort")
#
# cohortManifest$addDependentCustomCohort(
#   filePath = here::here("inputs/cohorts/sql/my_custom_dependent.sql"),
#   label = "Eligible_With_Exclusions",
#   category = "Derived Cohorts",
#   dependentCohortIdList = list(
#     # Preferred: manifest entries (data.frame/tibble with an id column) -
#     # same pattern as baseCohortEntry/cohortEntries on the builders above.
#     # Backward compatible: raw integer IDs also still work.
#     inc_cohort_id = incEntry,
#     exc_cohort_id = excEntry
#   ),
#   # sqlParameters: optional extra values (not cohort IDs) to render into the SQL
#   sqlParameters = list(
#     min_days = 30L
#   ),
#   tags = list(owner = "epi_team", source = "custom_sql")
# )

# SQL contract reminder for my_custom_dependent.sql:
#   - Use @inc_cohort_id, @exc_cohort_id, @min_days, etc. placeholders (or your own named keys)
#   - DELETE from @target_database_schema.@target_cohort_table by @target_cohort_id
#   - INSERT into @target_database_schema.@target_cohort_table
#       (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
#
# dependentCohortIdList/sqlParameters values are rendered into the SQL immediately,
# and the rendered file is written to inputs/cohorts/derived/<label>.sql (the file
# actually registered in the manifest) - just like the built-in derived cohort
# builders above. Only @target_cohort_id and the other connection/schema
# placeholders are left for generateCohorts() to fill in at execution time.
# When dependentCohortIdList entries carry a label (i.e. manifest entries, not
# raw IDs), that label is written into a "Dependent cohorts" comment header at
# the top of the generated file, for QC.

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
#   1. Base cohorts must exist in the manifest before building dependents
#   2. Use queryCohortsByLabel() to retrieve entry rows by name — avoid hardcoding IDs
#   3. Pass entry rows via baseCohortEntry/cohortEntries/etc. instead of Id arguments
#   4. Tag dependent cohorts appropriately for filtering/analysis
#   5. Document the logic behind each dependent cohort (comments)
#   6. Test dependent cohort logic in a smaller database first
#
# See picard documentation for:
#   - Advanced temporal relationships
#   - Window definitions (days, months, years)
#   - Index event definitions
#   - Attrition rules for dependent cohorts
