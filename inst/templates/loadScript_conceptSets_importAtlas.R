# ================================================================================
# File: importAtlas.R
# ================================================================================
#
# Study: <<studyName>>
# Author: <<author>>
# Purpose: <<description>>
#
# This script imports concept set definitions from ATLAS using the manifest API.
# It is designed to be sourced as part of the pre-pipeline setup workflow.
#
# Workflow:
#   1. Update conceptSetsLoad.csv with ATLAS concept set IDs and labels
#   2. Set up ATLAS connection (if not already done)
#   3. Run this script to import definitions from ATLAS
#   4. Review the imported concept sets in the manifest
#
# Note: After import, concept sets auto-register any new JSON files discovered
# in inputs/conceptSets/json/ on subsequent loadConceptSetManifest() calls.

library(picard)

# ================================================================================
# A. CREATE BLANK LOAD FILE (First Time Only)
# ================================================================================

# Uncomment to create a blank template CSV file:
# createBlankConceptSetsLoadFile()

# Now open inputs/conceptSets/conceptSetsLoad.csv in Excel and fill in your entries:
#   - atlasId: ATLAS concept set definition IDs (required)
#   - label: Display name for your concept set (required)
#   - domain: OMOP domain like drug_exposure, condition_occurrence (required)
#   - sourceCode: TRUE/FALSE whether it represents source codes (optional)
#   Any additional columns are treated as tags


# ================================================================================
# B. LOAD MANIFEST (First Time Setup) or Reload (Subsequent Times)
# ================================================================================

# The manifest is created on the first run and loaded on every run after that
if (!fs::file_exists(here::here("inputs/conceptSets/conceptSetManifest.sqlite"))) {
  initConceptSetManifest(here::here("inputs/conceptSets"))
}
conceptSetManifest <- loadConceptSetManifest()


# ================================================================================
# C. SET UP ATLAS CONNECTION
# ================================================================================

# ATLAS credentials are read from your user-level secrets.yml.
# See ?getAtlasConnection for details.
#
# The connection is only opened when there is ATLAS work to do: registered
# ATLAS concept sets to sync, or a conceptSetsLoad.csv to import.
conceptSetsLoadPath <- here::here("inputs/conceptSets/conceptSetsLoad.csv")
hasAtlasConceptSets <- nrow(conceptSetManifest$queryConceptSetsByTagName("atlasId", tags_format = "json")) > 0

if (hasAtlasConceptSets || fs::file_exists(conceptSetsLoadPath)) {
  atlasConnection <- getAtlasConnection()
  conceptSetManifest$setAtlasConnection(atlasConnection)
} else {
  cli::cli_alert_info("No ATLAS concept sets registered and no conceptSetsLoad.csv found - skipping ATLAS")
}


# ================================================================================
# D. SYNC REGISTERED ATLAS CONCEPT SETS
# ================================================================================

# Runs first, before any import: re-checks every registered ATLAS concept set
# against ATLAS and updates changed definitions in place (same ID). This is
# the step that propagates ATLAS edits, and running it before the import means
# even a stale load csv cannot prevent the manifest from syncing.
if (hasAtlasConceptSets) {
  conceptSetManifest$updateAtlasConceptSets()
}

# To update a single concept set on demand instead, use:
# conceptSetManifest$addAtlasConceptSet(atlasId = ..., label = "...",
#                                       stopIfExists = FALSE)


# ================================================================================
# E. IMPORT NEW CONCEPT SETS FROM ATLAS
# ================================================================================

# Reads conceptSetsLoad.csv and downloads CIRCE JSON definitions from ATLAS
# Place your conceptSetsLoad.csv in inputs/conceptSets/ before running this

# The load csv is for one-time imports only: rows already registered in the
# manifest cause an error (delete the csv after a successful import). The
# import is skipped when the csv is absent, so re-running main.R stays safe.
if (fs::file_exists(conceptSetsLoadPath)) {
  conceptSetManifest$importAtlasConceptSets(
    conceptSetsLoad = readr::read_csv(conceptSetsLoadPath, show_col_types = FALSE)
  )
} else {
  cli::cli_alert_info("No conceptSetsLoad.csv found - skipping one-time import")
}


# ================================================================================
# F. REVIEW IMPORTED CONCEPT SETS
# ================================================================================

# Display a table of all concept sets in the manifest
conceptSetManifest$tabulateManifest()

# Optionally, export and inspect specific concept sets:
# conceptSetDef <- conceptSetManifest$getConceptSetDefinition(conceptSetId = 1L)
# print(conceptSetDef)

cli::cli_alert_success("Concept sets imported successfully from ATLAS!")


# ================================================================================
# F. AUTO-DISCOVERY NOTE
# ================================================================================
#
# When you call loadConceptSetManifest() in subsequent sessions:
#   - It automatically discovers new .json files in inputs/conceptSets/json/
#   - Files not yet in the SQLite database are auto-registered with a temporary label
#   - This is helpful if you manually download concept set definitions
#
# If you download JSON files from elsewhere, just place them in
# inputs/conceptSets/json/ and re-run loadConceptSetManifest()
