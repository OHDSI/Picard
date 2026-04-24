# ================================================================================
# File: loadingInputs.R
# ================================================================================
#
# A. Overview ────────────────────────────────────────────────────────────────────
#
# Study: {studyName}
#
# Purpose:
# Load cohort and concept set definitions for this study. Run this script once
# (and re-run as needed) to populate inputs/ before executing the study pipeline.
#
# Workflow:
#   1. Configure load files (cohortsLoad.csv, conceptSetsLoad.csv)
#   2. Connect to ATLAS and import definitions
#   3. Build any derived cohorts not available in ATLAS
#   4. Load manifests into memory and review

library(picard)

# B. Concept Sets  ─────────────────────────────────────────────────────────
## Make Concept Sets Load File
# The conceptSetsLoad.csv file defines which concept sets to import from ATLAS.

# Option A: Create a blank template (first-time setup) and edit the resulting CSV file to add entries
createBlankConceptSetsLoadFile()

# Option B: Launch the interactive editor to add or update entries
# launchConceptSetsLoadEditor()


## Import Concept Sets from ATLAS 
# Reads conceptSetsLoad.csv and downloads CIRCE JSON definitions from ATLAS into
# inputs/conceptSets/json/.
# ATLAS credentials must be set in your .Renviron file before connecting.
# Open .Renviron with: usethis::edit_r_environ(). 
# Review the vignette on how to set up ATLAS credentials

atlasConnection <- setAtlasConnection()

importAtlasConceptSets(atlasConnection = atlasConnection)


## Load Concept Set Manifest and review
conceptSetManifest <- loadConceptSetManifest()
conceptSetManifest$tabulateManifest()


# C. Cohorts  ───────────────────────────────────────────────────────────

## 1. Import from Atlas

### Make cohortsLoad
# The cohortsLoad.csv file defines which cohorts to import from ATLAS, along with
# metadata (label, category, subCategory). Run one option below.

# Option A: Create a blank template (first-time setup) and edit the resulting CSV file to add entries
createBlankCohortsLoadFile()

# Option B: Launch the interactive editor to add or update entries
# launchCohortsLoadEditor()


# Import Cohorts from ATLAS 
# Reads cohortsLoad.csv and downloads CIRCE JSON definitions from ATLAS into
# inputs/cohorts/json/. Re-run to refresh definitions after changes in ATLAS.

importAtlasCohorts(atlasConnection = atlasConnection)

## 2. Load Cohort Manifest and review
# Loads all cohort files from inputs/cohorts/ into a CohortManifest object.
# Call this after all independent cohort files are in place.

cohortManifest <- loadCohortManifest()
cohortManifest$tabulateManifest()

## 3. (Optional) Build Capr Cohorts
# Sometimes we want to use cohrots that not in ATLAS. We can define circe logic cohorts in R and build them locally. 
# This is an optional step that depends on the needs of your study.

## 4. (Optional) Build Dependent Cohorts
# Some cohorts depend on other cohorts. For example, we may want to define a cohort of persons with CKD given they had Diabetes
# This can be done using dependent cohorts. Options include: temporal subsets, demographics, unions, complements and composites.


## 5. (Optional) Define Custom SQL Cohorts
# Use custom SQL when a cohort cannot be expressed in ATLAS CIRCE or as a derived cohort.
# 
# Workflow:
#   a. Place your .sql file in inputs/cohorts/sql/
#   b. Call loadCohortManifest() — the file is auto-discovered with a temporary label
#   c. Call defineCustomCohort() to assign a proper label, tags, and cohortType = "custom"
#
# Your SQL must use SqlRender parameters (@target_cohort_id, @target_database_schema,
# @target_cohort_table, @cdm_database_schema) and include a DELETE step for idempotency.
# See the loading_inputs vignette for a full SQL template.

# cohortManifest <- loadCohortManifest()
#
# defineCustomCohort(
#   manifest = cohortManifest,
#   sqlFilePath = "inputs/cohorts/sql/my_cohort.sql",
#   label = "My Custom Cohort",
#   tags = list(category = "Exposure")
# )


## 6. (Optional) Update Cohort Metadata
# Rename or re-tag any cohort already in the manifest (any cohort type).
# Only the fields you supply are changed — omitted arguments are left untouched.

# updateCohortMetadata(
#   manifest = cohortManifest,
#   cohortId = 1L,
#   label = "Revised cohort name"
# )

