# ================================================================================
# File: import_atlas_cohort.R
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

# Everything below is commented out so this script does nothing until you use
# ATLAS. Uncomment each step as you need it.

# ================================================================================
# A. CREATE BLANK LOAD FILE (First Time Only)
# ================================================================================

# Run once at the console (not from this script) to create a blank template CSV:
# createBlankCohortsLoadFile()

# Now open inputs/cohorts/cohortsLoad.csv in Excel and fill in your entries:
#   - atlasId: ATLAS cohort definition IDs (required)
#   - label: Display name for your cohort (required)
#   - category: Broad category like "Disease Populations", "Treatment Groups" (required)
#   - subCategory: Optional sub-grouping within category
#   Any additional columns are treated as tags
#
# Imported definitions are saved as json/<atlasId>_<ATLAS cohort name>.json in
# snake_case (e.g. json/1234_type_2_diabetes.json).


# ================================================================================
# B. LOAD MANIFEST
# ================================================================================

# Uncomment when you start using ATLAS. If the manifest does not exist yet,
# run initCohortManifest(configBlock = "my_database") once at the console first.
# inputBuilderEnv$configBlock is the config block the pipeline is building
# inputs for; its cohortManifestPath in config.yml names the manifest.
# cohortManifest <- loadCohortManifest(configBlock = inputBuilderEnv$configBlock)


# ================================================================================
# C. SET UP ATLAS CONNECTION
# ================================================================================

# Uncomment when you start using ATLAS. Credentials are read from your
# user-level secrets.yml; see ?getAtlasConnection for details.
# atlasConnection <- getAtlasConnection()
# cohortManifest$setAtlasConnection(atlasConnection)


# ================================================================================
# D. IMPORT NEW COHORTS FROM ATLAS
# ================================================================================

# Reads inputs/cohorts/cohortsLoad.csv and downloads CIRCE JSON definitions from
# ATLAS. Keep the load csv in the repo as the record of which ATLAS cohorts the
# study uses, and add rows to it as the study grows.
#
# By default, rows already registered in the manifest cause an error, so the
# import only adds new cohorts: uncomment it when you add rows, and comment it
# out again once the import succeeds. Alternatively, pass stopIfExists = FALSE
# to leave it uncommented and update registered rows in place (definition,
# category, tags) on every run. Rows are matched to registered cohorts by
# label: to rename one, call $updateCohortLabel() and then edit the label in
# the csv to match.
# cohortManifest$importAtlasCohorts(
#   cohortsLoad = readr::read_csv(
#     here::here("inputs/cohorts/cohortsLoad.csv"),
#     show_col_types = FALSE
#   )
# )


# ================================================================================
# E. SYNC REGISTERED ATLAS COHORTS
# ================================================================================

# Uncomment once the manifest has ATLAS cohorts, and leave it uncommented: it
# re-checks every registered ATLAS cohort against ATLAS and updates changed
# definitions in place (same ID; derived cohorts marked stale so the pipeline
# regenerates them). This is the step that propagates ATLAS edits. If a cohort
# cannot be fetched the sync stops; pass stopOnError = FALSE to skip it with a
# warning instead.
# cohortManifest$updateAtlasCohorts()

# To update a single cohort on demand instead, use:
# cohortManifest$addAtlasCohort(atlasId = ..., label = "...", category = "...",
#                               stopIfExists = FALSE)


# ================================================================================
# F. REVIEW IMPORTED COHORTS
# ================================================================================

# Display a table of all cohorts in the manifest
# cohortManifest$tabulateManifest()

# Optionally, export and inspect specific cohorts:
# cohortDef <- cohortManifest$getCohortDefinition(cohortId = 1L)
# print(cohortDef)


# ================================================================================
# G. REGISTERING COHORTS
# ================================================================================
#
# Register cohorts through the manifest (load csv, $addAtlasCohort(),
# $addCirceCohort(), ...). JSON files placed directly in inputs/cohorts/json/
# without registration are removed as orphans the next time
# loadCohortManifest() is called.
