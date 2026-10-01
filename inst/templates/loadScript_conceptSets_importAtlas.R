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

# Everything below is commented out so this script does nothing until you use
# ATLAS. Uncomment each step as you need it.

# ================================================================================
# A. CREATE BLANK LOAD FILE (First Time Only)
# ================================================================================

# Run once at the console (not from this script) to create a blank template CSV:
# createBlankConceptSetsLoadFile()

# Now open inputs/conceptSets/conceptSetsLoad.csv in Excel and fill in your entries:
#   - atlasId: ATLAS concept set definition IDs (required)
#   - label: Display name for your concept set (required)
#   - domain: OMOP domain like drug_exposure, condition_occurrence (required)
#   - sourceCode: TRUE/FALSE whether it represents source codes (optional)
#   Any additional columns are treated as tags
#
# Imported definitions are saved as json/<atlasId>_<ATLAS concept set name>.json
# in snake_case (e.g. json/5678_metformin.json).


# ================================================================================
# B. LOAD MANIFEST
# ================================================================================

# Uncomment when you start using ATLAS. If the manifest does not exist yet,
# run initConceptSetManifest() once at the console first.
# conceptSetManifest <- loadConceptSetManifest()


# ================================================================================
# C. SET UP ATLAS CONNECTION
# ================================================================================

# Uncomment when you start using ATLAS. Credentials are read from your
# user-level secrets.yml; see ?getAtlasConnection for details.
# atlasConnection <- getAtlasConnection()
# conceptSetManifest$setAtlasConnection(atlasConnection)


# ================================================================================
# D. SYNC REGISTERED ATLAS CONCEPT SETS
# ================================================================================

# Uncomment once the manifest has ATLAS concept sets, and leave it uncommented:
# it re-checks every registered ATLAS concept set against ATLAS and updates
# changed definitions in place (same ID). This is the step that propagates
# ATLAS edits.
# conceptSetManifest$updateAtlasConceptSets()

# To update a single concept set on demand instead, use:
# conceptSetManifest$addAtlasConceptSet(atlasId = ..., label = "...",
#                                       stopIfExists = FALSE)


# ================================================================================
# E. IMPORT NEW CONCEPT SETS FROM ATLAS
# ================================================================================

# Reads inputs/conceptSets/conceptSetsLoad.csv and downloads CIRCE JSON
# definitions from ATLAS. Keep the load csv in the repo as the record of which
# ATLAS concept sets the study uses, and add rows to it as the study grows.
#
# By default, rows already registered in the manifest cause an error, so the
# import only adds new concept sets: uncomment it when you add rows, and comment
# it out again once the import succeeds. Alternatively, pass
# stopIfExists = FALSE to leave it uncommented and update registered rows in
# place (definition, label, category, tags) on every run.
# conceptSetManifest$importAtlasConceptSets(
#   conceptSetsLoad = readr::read_csv(
#     here::here("inputs/conceptSets/conceptSetsLoad.csv"),
#     show_col_types = FALSE
#   )
# )


# ================================================================================
# F. REVIEW IMPORTED CONCEPT SETS
# ================================================================================

# Display a table of all concept sets in the manifest
# conceptSetManifest$tabulateManifest()

# Optionally, export and inspect specific concept sets:
# conceptSetDef <- conceptSetManifest$getConceptSetDefinition(conceptSetId = 1L)
# print(conceptSetDef)


# ================================================================================
# G. AUTO-DISCOVERY NOTE
# ================================================================================
#
# When you call loadConceptSetManifest() in subsequent sessions:
#   - It automatically discovers new .json files in inputs/conceptSets/json/
#   - Files not yet in the SQLite database are auto-registered with a temporary label
#   - This is helpful if you manually download concept set definitions
#
# If you download JSON files from elsewhere, just place them in
# inputs/conceptSets/json/ and re-run loadConceptSetManifest()
