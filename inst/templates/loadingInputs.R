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
# Key Workflow:
#   1. FIRST TIME: Use init*() to create empty manifests
#   2. FIRST TIME: Create blank load CSV files, fill in Excel with ATLAS IDs + labels
#   3. FIRST TIME: Import from ATLAS using manifest$import*() methods
#   4. SUBSEQUENT TIMES: Use load*Manifest() to reload from SQLite
#   5. OPTIONAL: Build derived cohorts (Capr, custom SQL, dependent cohorts)

library(picard)

# ================================================================================
# B. CONCEPT SETS - FIRST TIME SETUP
# ================================================================================

## Step 1: Initialize the concept set manifest (first time only)
conceptSetManifest <- initConceptSetManifest()

## Step 2: Create and populate the load file
# Create a blank template CSV file:
createBlankConceptSetsLoadFile()

# Now open inputs/conceptSets/conceptSetsLoad.csv in Excel and fill in your entries:
# - atlasId: ATLAS concept set definition IDs (required)
# - label: Display name for your concept set (required)
# - domain: OMOP domain like drug_exposure, condition_occurrence (required)
# - sourceCode: TRUE/FALSE whether it represents source codes (optional)
# Any additional columns are treated as tags

## Step 3: Set up ATLAS connection
# ATLAS credentials must be configured in your .Renviron file before connecting
atlasConnection <- getAtlasConnection()
conceptSetManifest$setAtlasConnection(atlasConnection)

## Step 4: Import concept sets from ATLAS
# Reads conceptSetsLoad.csv and downloads CIRCE JSON definitions from ATLAS
conceptSetManifest$importAtlasConceptSets(
  conceptSetsLoadPath = here::here("inputs/conceptSets/conceptSetsLoad.csv")
)

## Step 5: Load and review
conceptSetManifest <- loadConceptSetManifest()
conceptSetManifest$tabulateManifest()


# ================================================================================
# IMPORTANT: CONCEPT SET AUTO-DISCOVERY
# ================================================================================
# When you call loadConceptSetManifest() in subsequent sessions:
# - It automatically discovers new .json files in inputs/conceptSets/json/
# - Files not yet in the SQLite database are auto-registered
# - This is different from cohorts (see cohort section below)
#
# If you download new concept set JSON files from elsewhere, just place them in
# inputs/conceptSets/json/ and re-run loadConceptSetManifest()


# ================================================================================
# C. COHORTS - FIRST TIME SETUP
# ================================================================================

## Step 1: Initialize the cohort manifest (first time only)
cohortManifest <- initCohortManifest()

## Step 2: Create and populate the load file  
# Create a blank template CSV file:
createBlankCohortsLoadFile()

# Now open inputs/cohorts/cohortsLoad.csv in Excel and fill in your entries:
# - atlasId: ATLAS cohort definition IDs (required)
# - label: Display name for your cohort (required)
# - category: Broad category like "Disease Populations", "Treatment Groups" (required)
# - subCategory: Optional sub-grouping within category
# - file_name: Will be auto-populated as json/{{label}}.json
# Any additional columns are treated as tags

## Step 3: Set up ATLAS connection (if not already done in concept sets section)
# ATLAS credentials must be configured in your .Renviron file before connecting
# atlasConnection <- getAtlasConnection()
cohortManifest$setAtlasConnection(atlasConnection)

## Step 4: Import cohorts from ATLAS
# Reads cohortsLoad.csv and downloads CIRCE JSON definitions from ATLAS
cohortManifest$importAtlasCohorts(
  cohortsLoadPath = here::here("inputs/cohorts/cohortsLoad.csv")
)

## Step 5: Load and review
cohortManifest <- loadCohortManifest()
cohortManifest$tabulateManifest()


# ================================================================================
# SUBSEQUENT SESSIONS: Simply load the manifests
# ================================================================================
# After the first-time setup above, in subsequent sessions just run:
# 
# conceptSetManifest <- loadConceptSetManifest()
# cohortManifest <- loadCohortManifest()
#
# The manifests will be restored from SQLite with all your definitions and metadata.
# Note: loadConceptSetManifest() auto-discovers new .json files not yet in the database
#       loadCohortManifest() does NOT auto-discover files (category is required)


# ================================================================================
# D. ADDING INDIVIDUAL COHORTS (without using cohortsLoad.csv)
# ================================================================================

## Option 1: Add a single ATLAS cohort
# cohortManifest$addAtlasCohort(
#   atlasId = 123,
#   label = "Type 2 Diabetes",
#   category = "Disease Populations"
# )

## Option 2: Add Capr-defined cohorts
# Details on using Capr cohorts will be provided in a separate vignette.
# Basic pattern:
# 
# caprCohort <- list(  # Your Capr cohort object here )
# cohortManifest$addCaprCohort(
#   caprConceptSet = caprCohort,
#   label = "My Capr Cohort",
#   category = "Custom",
#   tags = list(source = "capr")
# )

## Option 3: Add SQL cohorts from disk
# cohortManifest$addSqlCohort(
#   filePath = "inputs/cohorts/sql/my_cohort.sql",
#   label = "Custom SQL Cohort",
#   category = "Custom",
#   tags = list(category = "Exposure")
# )

## Option 4: Add Circe JSON cohorts from disk
# cohortManifest$addCirceCohort(
#   filePath = "inputs/cohorts/json/my_cohort.json",
#   label = "Circe JSON Cohort",
#   category = "Disease Populations"
# )


# ================================================================================
# E. OPTIONAL: BUILD DERIVED COHORTS
# ================================================================================

## Build dependent cohorts (Temporal, Demographic, Union, Complement, Composite)
# Some cohorts are defined by their relationship to other cohorts:
#   - Temporal: "CKD in patients with prior Diabetes"
#   - Demographic: "CKD in males aged 65+"
#   - Union: "Diabetes OR Hypertension"
#   - Complement: "All patients NOT with CKD"
#
# See the loading_inputs vignette for detailed examples.

# cohortManifest <- buildSubsetCohortTemporal(
#   label = "CKD given prior T2D",
#   baseCohortId = 1,
#   filterCohortId = 2,
#   temporalOperator = "before",
#   temporalStartOffset = 365,
#   manifest = cohortManifest
# )


# ================================================================================
# F. OPTIONAL: DEFINE CUSTOM SQL COHORTS
# ================================================================================
# Use custom SQL when a cohort cannot be expressed in ATLAS CIRCE or as a 
# derived cohort.
#
# Workflow:
#   a. Place your .sql file in inputs/cohorts/sql/
#   b. Call loadCohortManifest() — the file is auto-discovered with a temporary label
#   c. Call defineCustomCohort() to assign a proper label, tags, and cohortType = "custom"
#
# Your SQL must use SqlRender parameters:
#   - @target_cohort_id: The cohort definition ID assigned by manifest
#   - @target_database_schema: The schema where the cohort table resides
#   - @target_cohort_table: The cohort table name
#   - @cdm_database_schema: The CDM schema
#
# A DELETE step before INSERT is strongly recommended for idempotency.

# cohortManifest <- loadCohortManifest()
#
# defineCustomCohort(
#   manifest = cohortManifest,
#   sqlFilePath = "inputs/cohorts/sql/my_cohort.sql",
#   label = "My Custom Cohort",
#   tags = list(category = "Exposure")
# )


# ================================================================================
# G. OPTIONAL: UPDATE COHORT OR CONCEPT SET METADATA
# ================================================================================
# Rename or re-tag any cohort/concept set already in the manifest.
# Only the fields you supply are changed — omitted arguments are left untouched.

# updateCohortMetadata(
#   manifest = cohortManifest,
#   cohortId = 1L,
#   label = "Revised cohort name",
#   tags = list(category = "Outcome", status = "primary")
# )

