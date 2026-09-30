# ================================================================================
# File: importAtlas.R
# ================================================================================
#
# Study: <<studyName>>
# Author: <<author>>
# Purpose: <<description>>
#
# This script imports cohort definitions from ATLAS using the manifest API.
# It is designed to be sourced as part of the pre-pipeline setup workflow.
#
# Workflow:
#   1. Update cohortsLoad.csv with ATLAS cohort IDs and labels
#   2. Set up ATLAS connection (if not already done)
#   3. Run this script to import definitions from ATLAS
#   4. Review the imported cohorts in the manifest

library(picard)

# ================================================================================
# A. CREATE BLANK LOAD FILE (First Time Only)
# ================================================================================

# Uncomment to create a blank template CSV file:
# createBlankCohortsLoadFile()

# Now open inputs/cohorts/cohortsLoad.csv in Excel and fill in your entries:
#   - atlasId: ATLAS cohort definition IDs (required)
#   - label: Display name for your cohort (required)
#   - category: Broad category like "Disease Populations", "Treatment Groups" (required)
#   - subCategory: Optional sub-grouping within category
#   - file_name: Will be auto-populated as json/{{label}}.json
#   Any additional columns are treated as tags


# ================================================================================
# B. LOAD MANIFEST (First Time Setup) or Reload (Subsequent Times)
# ================================================================================

# The manifest is created on the first run and loaded on every run after that
if (!fs::file_exists(here::here("inputs/cohorts/cohortManifest.sqlite"))) {
  initCohortManifest(here::here("inputs/cohorts"))
}
cohortManifest <- loadCohortManifest()


# ================================================================================
# C. SET UP ATLAS CONNECTION
# ================================================================================

# ATLAS credentials are read from your user-level secrets.yml.
# See ?getAtlasConnection for details.
#
# The connection is only opened when there is ATLAS work to do: registered
# ATLAS cohorts to sync, or a cohortsLoad.csv to import.
cohortsLoadPath <- here::here("inputs/cohorts/cohortsLoad.csv")
hasAtlasCohorts <- nrow(cohortManifest$queryCohortsByTagName("atlasId", tags_format = "json")) > 0

if (hasAtlasCohorts || fs::file_exists(cohortsLoadPath)) {
  atlasConnection <- getAtlasConnection()
  cohortManifest$setAtlasConnection(atlasConnection)
} else {
  cli::cli_alert_info("No ATLAS cohorts registered and no cohortsLoad.csv found - skipping ATLAS")
}


# ================================================================================
# D. SYNC REGISTERED ATLAS COHORTS
# ================================================================================

# Runs first, before any import: re-checks every registered ATLAS cohort
# against ATLAS and updates changed definitions in place (same ID; derived
# cohorts marked stale so the pipeline regenerates them). This is the step
# that propagates ATLAS edits, and running it before the import means even a
# stale load csv cannot prevent the manifest from syncing.
if (hasAtlasCohorts) {
  cohortManifest$updateAtlasCohorts()
}

# To update a single cohort on demand instead, use:
# cohortManifest$addAtlasCohort(atlasId = ..., label = "...", category = "...",
#                               stopIfExists = FALSE)


# ================================================================================
# E. IMPORT NEW COHORTS FROM ATLAS
# ================================================================================

# Reads cohortsLoad.csv and downloads CIRCE JSON definitions from ATLAS
# Place your cohortsLoad.csv in inputs/cohorts/ before running this

# The load csv is for one-time imports only: rows already registered in the
# manifest cause an error (delete the csv after a successful import). The
# import is skipped when the csv is absent, so re-running main.R stays safe.
if (fs::file_exists(cohortsLoadPath)) {
  cohortManifest$importAtlasCohorts(
      cohortsLoad = readr::read_csv(cohortsLoadPath, show_col_types = FALSE)
    )
} else{
  cli::cli_alert_info("No cohortsLoad.csv found - skipping one-time import")
}
  

# ================================================================================
# F. REVIEW IMPORTED COHORTS
# ================================================================================

# Display a table of all cohorts in the manifest
cohortManifest$tabulateManifest()

# Optionally, export and inspect specific cohorts:
# cohortDef <- cohortManifest$getCohortDefinition(cohortId = 1L)
# print(cohortDef)

cli::cli_alert_success("Cohorts imported successfully from ATLAS!")
