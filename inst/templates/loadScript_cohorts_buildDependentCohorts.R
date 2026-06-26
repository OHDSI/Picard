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
#   - O-Prior-T: "Outcome after prior target exposure"
#   - T-Prior-O: "Target exposure after prior outcome"
#   - Censor: "Target exposure censored at death"

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
# Build "CKD given prior diabetes" by finding CKD events in patients with prior diabetes

# cohortManifest$buildSubsetCohortTemporal(
#   label = "CKD given prior T2D",
#   baseCohortId = 1L,                  # CKD cohort ID
#   filterCohortId = 2L,                # T2D cohort ID
#   temporalOperator = "before",
#   temporalStartOffset = 365,          # 1 year before CKD
#   temporalEndOffset = 0               # Up to CKD start
# )


# ---- Example: Union ----
# Combine two cohorts (Diabetes OR Hypertension)

# cohortManifest$buildUnionCohort(
#   label = "Diabetes or Hypertension",
#   cohortIds = c(1L, 3L),
#   category = "Disease Populations"
# )


# ---- Example: Complement ----
# All patients NOT in the target cohort (within the database time span)

# cohortManifest$buildComplementCohort(
#   label = "No CKD",
#   cohortId = 1L,
#   category = "Control Populations"
# )


# ---- Example: Outcome Prior Target (O-Prior-T) ----
# Events where outcome occurs before target exposure
# e.g., "GI Bleed in patients with prior NSAID use"

# cohortManifest$buildOPriorT(
#   label = "GI Bleed - Prior NSAID",
#   outcomeCohortId = 1L,
#   targetCohortId = 2L,
#   category = "Outcomes",
#   mode = "prior",
#   priorTimeWindowDays = 365,
#   subsetLimit = "First"
# )


# ---- Example: Target Prior Outcome (T-Prior-O) ----
# Events where target exposure occurs before outcome
# e.g., "NSAID use in patients with prior GI Bleed"

# cohortManifest$buildTPriorO(
#   label = "NSAID - Prior GI Bleed",
#   targetCohortId = 2L,
#   outcomeCohortId = 1L,
#   category = "Exposures",
#   mode = "prior",
#   priorTimeWindowDays = NULL,
#   subsetLimit = "First"
# )


# ---- Example: Censor at Event ----
# Censor target cohort when a censoring event occurs
# e.g., "NSAID use censored at death"

# cohortManifest$buildCensorCohort(
#   label = "NSAID - Censored at Death",
#   targetCohortId = 2L,
#   censorCohortId = 3L,
#   category = "Exposures",
#   tags = list(censored = TRUE)
# )


# ---- Example: Demographic Subset ----
# Subset a base cohort by age, gender, or other demographics
# (Use manifest methods specific to your version for demographic filtering)

# cohortManifest$buildDemographicSubset(
#   label = "CKD in Males Aged 65+",
#   baseCohortId = 1L,
#   ageMin = 65,
#   genderConceptIds = 8507L,  # Male
#   category = "Disease Populations"
# )


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
