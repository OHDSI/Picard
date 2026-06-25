# ================================================================================
# File: importAtlas.R
# ================================================================================
#
# Study: {studyName}
# Author: {author}
# Purpose: {description}
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

# First time only: Initialize a new manifest (comment out after first run)
# conceptSetManifest <- initConceptSetManifest()

# Subsequent times: Load from existing SQLite database
conceptSetManifest <- loadConceptSetManifest()


# ================================================================================
# C. SET UP ATLAS CONNECTION
# ================================================================================

# ATLAS credentials must be configured in your .Renviron file before connecting.
# Typical env vars: ATLAS_BASE_URL, ATLAS_API_TOKEN, ATLAS_SOURCE_ID, etc.
# See ?getAtlasConnection for details on required environment variables

atlasConnection <- getAtlasConnection()
conceptSetManifest$setAtlasConnection(atlasConnection)


# ================================================================================
# D. IMPORT CONCEPT SETS FROM ATLAS
# ================================================================================

# Reads conceptSetsLoad.csv and downloads CIRCE JSON definitions from ATLAS
# Place your conceptSetsLoad.csv in inputs/conceptSets/ before running this

conceptSetManifest$importAtlasConceptSets(
  conceptSetsLoadPath = here::here("inputs/conceptSets/conceptSetsLoad.csv")
)


# ================================================================================
# E. REVIEW IMPORTED CONCEPT SETS
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
