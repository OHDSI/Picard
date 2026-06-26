# ================================================================================
# File: importAtlas.R
# ================================================================================
#
# Study: {studyName}
# Author: {author}
# Purpose: {description}
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

# First time only: Initialize a new manifest (comment out after first run)
# cohortManifest <- initCohortManifest()

# Subsequent times: Load from existing SQLite database
cohortManifest <- loadCohortManifest()


# ================================================================================
# C. SET UP ATLAS CONNECTION
# ================================================================================

# ATLAS credentials must be configured in your .Renviron file before connecting.
# Typical env vars: ATLAS_BASE_URL, ATLAS_API_TOKEN, ATLAS_SOURCE_ID, etc.
# See ?getAtlasConnection for details on required environment variables

atlasConnection <- getAtlasConnection()
cohortManifest$setAtlasConnection(atlasConnection)


# ================================================================================
# D. IMPORT COHORTS FROM ATLAS
# ================================================================================

# Reads cohortsLoad.csv and downloads CIRCE JSON definitions from ATLAS
# Place your cohortsLoad.csv in inputs/cohorts/ before running this

cohortsLoad <- readr::read_csv(
    here::here("inputs/cohorts/cohortsLoad.csv"), 
    show_col_types = FALSE
)

cohortManifest$importAtlasCohorts(cohortsLoad = cohortsLoad)


# ================================================================================
# E. REVIEW IMPORTED COHORTS
# ================================================================================

# Display a table of all cohorts in the manifest
cohortManifest$tabulateManifest()

# Optionally, export and inspect specific cohorts:
# cohortDef <- cohortManifest$getCohortDefinition(cohortId = 1L)
# print(cohortDef)

cli::cli_alert_success("Cohorts imported successfully from ATLAS!")
