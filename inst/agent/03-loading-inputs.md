# Loading Inputs: Cohorts and Concept Sets

## Introduction

Before running your study pipeline, you need to define the populations and phenotypes your analysis will use. Picard organizes these through two key input types:

- **Cohorts:** Define study populations, comparators, and outcomes as CIRCE-based JSON definitions or custom SQL
- **Concept Sets:** Define phenotypes for diseases, exposures, covariates, etc. as CIRCE-based JSON definitions

Picard uses *manifests* to catalog, version, and track these definitions throughout your study. This document walks through the complete workflow for loading and managing cohorts and concept sets.

## Manifest Overview

A manifest is a SQLite database that catalogs and tracks definitions. For each cohort or concept set, the manifest stores:

- **Metadata:** ID, label, category, source (ATLAS or manual)
- **File information:** Path and MD5 hash for change detection
- **Provenance:** When added, last modified, execution status
- **Tags:** Categorization for querying and grouping

Manifests enable reproducibility and change tracking as your study evolves.

## Working with Cohorts

The cohort workflow has several key steps:

### Step 1: Create or Update Cohorts Load File (Optional)

The `cohortsLoad.csv` file provides metadata for organizing and enriching your cohorts. You can create a blank template or edit it interactively:

**Option A: Create a blank template**

```r
createBlankCohortsLoadFile(cohortsFolderPath = here::here("inputs/cohorts"))
```

This creates `inputs/cohorts/cohortsLoad.csv` with columns: `atlasId`, `label`, `category`, `subCategory`, `file_name`

Edit this file in Excel to add your cohort entries.

### Step 2: Import Cohort Definitions from ATLAS

#### Setting up Atlas Credentials

Before connecting to ATLAS, you must configure your credentials in your `.Renviron` file. These credentials authenticate your connection to the ATLAS WebAPI.

**A: View the credential template**

First, see the required credentials format:

```r
templateAtlasCredentials()
```

This displays a template with the following credentials you'll need to set:

- **`atlasBaseUrl`**: The base URL to your ATLAS WebAPI (e.g., `https://organization-atlas.com/WebAPI`)
- **`atlasAuthMethod`**: The authentication method (e.g., `ad` for Active Directory, `oauth`, etc.)
- **`atlasUser`**: Your ATLAS username or email
- **`atlasPassword`**: Your ATLAS password

**B: Set Credenitals** 

Route A: .Renviron

```r
usethis::edit_r_environ()
```

This opens your `.Renviron` file. Add these lines (substitute your actual credentials):

```
atlasBaseUrl='https://organization-atlas.com/WebAPI'
atlasAuthMethod='ad'
atlasUser='atlas.user@company.com'
atlasPassword='YourPassword'
```

⚠️ **Important Security Note:** Never commit `.Renviron` to version control. It should already be done but place it in `.gitignore` to prevent accidentally exposing credentials.

Route B: keyring

For **enhanced security**, store credentials in the keyring package which keeps them encrypted:

```r
# First, install keyring if needed
install.packages("keyring")

# Store each credential securely in keyring under service "picard"
# a prompt will show where you will be asked to place the credential you wish to stor
keyring::key_set(service = "picard", username = "atlasBaseUrl")
keyring::key_set(service = "picard", username = "atlasAuthMethod")
keyring::key_set(service = "picard", username = "atlasUser")
keyring::key_set(service = "picard", username = "atlasPassword")

# Verify credentials are stored
keyring::key_list(service = "picard")
```

Once stored in keyring, simply connect:

```r
# All credentials are retrieved automatically from keyring service "picard"
atlasConn <- setAtlasConnection(useKeyring = TRUE)
```

**Alternative: Add credentials directly to .Renviron (Less secure)**

If you prefer not to use keyring, you can add credentials directly:


**C: Connect and import**

Once credentials are configured, connect to ATLAS and download cohort definitions:

```r
atlasConn <- setAtlasConnection()

importAtlasCohorts(
  cohortsFolderPath = here::here("inputs/cohorts"),
  atlasConnection = atlasConn
)
```

This downloads JSON definitions to `inputs/cohorts/json/` and updates your manifest with metadata.

### Step 3: Load the Cohort Manifest

Load the manifest to access all cohort definitions in your study:

```r
cm <- loadCohortManifest()
```

### Step 4: Review and Validate Manifests

Examine the cohorts that were loaded:

```r
# View manifest list (metadata for all cohorts)
manifest_df <- cm$getManifest()

# Or get a formatted summary
summary_df <- cm$tabulateManifest()

# Query specific cohorts
cohort_1 <- cm$queryCohortsByIds(ids = 1L)
cohorts_by_tag <- cm$queryCohortsByTag(tagStrings = "category: Primary")
```

### Step 5: Apply Functions for Cohort Operations

Once manifests are loaded, you need `ExecutionSettings` to interact with the database:

```r
# Create execution settings for a specific database
settings <- createExecutionSettingsFromConfig(configBlock = "my_cdm")

# Set execution settings on the manifest
cm$setExecutionSettings(settings)

# Create cohort tables in the database
cm$createCohortTables()

# Generate cohort populations
cm$generateCohorts()

# Get cohort counts
counts <- cm$retrieveCohortCounts()
print(counts)
```

## Building Dependent Cohorts

Beyond base cohorts (imported from ATLAS or written as SQL), you can define dependent cohorts that derive from other cohorts using demographic or temporal constraints. This is useful for subpopulation analyses.

### Temporal Subset Cohorts

Build cohorts based on temporal relationships between events. Example: "Chronic Kidney Disease (CKD) in patients with prior Type 2 Diabetes":

```r
ckd_given_t2d <- buildSubsetCohortTemporal(
  label = "CKD given prior T2D",
  baseCohortId = 1,          # CKD is the outcome
  filterCohortId = 2,        # Must have T2D
  temporalOperator = "before",
  temporalStartOffset = 365, # Within 1 year before CKD
  manifest = cm
)
```

### Demographic Subset Cohorts

Build cohorts based on demographic characteristics. Example: "CKD in males only":

```r
ckd_males <- buildSubsetCohortDemographic(
  label = "CKD Males",
  baseCohortId = 1,                  # CKD population
  genderConceptIds = c(8507),        # 8507 = Male
  manifest = cm
)
```

Example: "CKD in adults (18+) only":

```r
ckd_adults <- buildSubsetCohortDemographic(
  label = "CKD Adults",
  baseCohortId = 1,
  minAge = 18,
  manifest = cm
)
```

### Union and Complement Cohorts

Combine multiple cohorts or create exclusions:

**Union:** Patients in either CKD OR Diabetes:

```r
ckd_or_t2d <- buildUnionCohort(
  label = "CKD or Type 2 Diabetes",
  cohortIds = c(1, 2),
  manifest = cm
)
```

**Complement:** All patients NOT in a cohort:

```r
no_ckd <- buildComplementCohort(
  label = "No Chronic Kidney Disease",
  cohortId = 1,
  manifest = cm
)
```

> **Note:** All `build*` functions require a `manifest` argument and automatically register the new cohort via `addDependentCohort()` — no separate call is needed.

### Visualizing Dependencies

Once you've defined dependent cohorts, visualize the relationship graph:

```r
# Generate a dependency report (Mermaid diagram + table)
report <- visualizeCohortDependencies(cm)

# Optionally save to file
visualizeCohortDependencies(cm, outputPath = here::here("inputs/cohorts"))
```

---

## Managing the Manifest Mid-Cycle

Study development is rarely linear. Cohorts get revised in ATLAS, new definitions get added mid-analysis, or old definitions are retired. Use these methods to keep the manifest in sync without reloading from scratch.

### Checking Manifest Health

```r
# Full status table: id, label, status, deleted_at, file_exists
cm$validateManifest()

# Summary counts
cm$getManifestStatus()
# Returns: active_count, missing_count, deleted_count, next_available_id
```

### syncManifest()

Reconciles the SQLite manifest against `json/` and `sql/` on disk in a single call:

- **New files** found on disk → added as new manifest entries
- **Active records** whose file has disappeared → soft-deleted (`status = 'deleted'`)
- **Existing files** whose SQL hash has changed → hash updated in manifest
- **Derived cohorts** (`derived/`) are not touched

```r
synced <- cm$syncManifest()
# Returns data frame: id, label, action
# action: "added" | "hash_updated" | "missing_flagged" | "unchanged"
```

Use after: re-running `importAtlasCohorts()`, editing a SQL file directly, or deleting a cohort file.

### deleteCohort() and permanentlyDeleteCohort()

```r
# Soft-delete: marks status = 'deleted', keeps the record for audit trail
cm$deleteCohort(id = 5, reason = "Replaced by updated phenotype")

# Hard delete: permanently removes the record (requires explicit confirmation)
cm$permanentlyDeleteCohort(id = 5, confirm = TRUE)
```

### cleanCohortTable()

Purges DBMS rows for all `status = 'deleted'` cohorts, then marks them `'purged'` in SQLite. Requires `executionSettings`.

```r
cm$setExecutionSettings(settings)
purge_results <- cm$cleanCohortTable()
# Returns data frame: id, label for each purged cohort
# Safe to call repeatedly — 'purged' records are skipped on subsequent calls
```

### Typical Mid-Cycle Workflow

```r
# 1. Re-import updated cohorts from ATLAS
importAtlasCohorts(cohortsFolderPath = here::here("inputs/cohorts"), atlasConnection = atlasConn)

# 2. Sync the manifest
synced <- cm$syncManifest()
synced[synced$action != "unchanged", ]  # review what changed

# 3. Retire a cohort no longer needed
cm$deleteCohort(id = 7, reason = "Out of scope for v2")

# 4. Purge the retired cohort from DBMS
cm$setExecutionSettings(settings)
cm$cleanCohortTable()

# 5. Re-generate to pick up revisions
cm$generateCohorts()
```

---

## Working with Concept Sets

The concept set workflow is similar to cohorts with slightly different organization.

### Step 1: Create or Update Concept Sets Load File

Create metadata for organizing your concept sets:

```r
createBlankConceptSetsLoadFile(conceptSetsFolderPath = here::here("inputs/conceptSets"))
```

### Step 2: Import Concept Sets from ATLAS

```r
atlasConn <- setAtlasConnection()

importAtlasConceptSets(
  conceptSetsFolderPath = here::here("inputs/conceptSets"),
  atlasConnection = atlasConn
)
```

### Step 3: Load and Review

```r
csm <- loadConceptSetManifest()

# View manifest
manifest_df <- csm$tabulateManifest()

# Query by concept
malaria_concepts <- csm$queryConceptSetsByIds(1L)
```

---

## Key Files and Folders

```
inputs/
├── cohorts/
│   ├── cohortsLoad.csv           # Metadata file
│   └── json/                     # ATLAS JSON exports
│       ├── cohort_1.json
│       └── cohort_2.json
└── conceptSets/
    ├── conceptSetsLoad.csv        # Metadata file
    └── json/                      # ATLAS JSON exports
        ├── concept_set_1.json
        └── concept_set_2.json

extras/
├── cohort_helpers.R              # Custom helper functions for cohort operations
├── concept_set_utilities.R       # Custom utilities for concept set work
└── ...                           # Any other scripts or explorations

analysis/src/
├── functions.R                   # Functions that correspond to analysis tasks only
└── sql/                          # SQL templates for analysis tasks
```

## Where to Put Helper Functions

- **Helper functions for cohort/concept set work:** `extras/` folder
  - Custom functions for validating definitions
  - Scripts for exploring or processing manifests
  - One-off analyses or data exploration scripts
  - Development and testing scripts

- **Functions in `analysis/src/`:** Reserved for functions that directly support **analysis tasks**
  - Functions called by task scripts in `analysis/tasks/`
  - SQL query builders or result processors
  - Pipeline-specific utilities

Keep development and exploration code in `extras/` to maintain a clean separation between exploratory work and production analysis pipeline code.

---

## Manifest Database Structure

Manifests are SQLite databases storing:

- **ID:** Unique identifier for each definition
- **Name/Label:** Human-readable name
- **File path:** Where the definition JSON/SQL is stored
- **Hash:** MD5 hash for detecting changes
- **Status:** Current state (new, modified, deleted, executed)
- **Metadata:** Custom tags and categories

The manifest enables:
- **Change tracking:** Detects when definitions are modified
- **Version history:** Traces which version produced which results
- **Dependency management:** Tracks dependent cohorts and their relationships
- **Validation:** Ensures all referenced definitions exist

---

## Next Steps

1. **Define cohorts** - Import from ATLAS or create manually
2. **Load manifest** - `cm <- loadCohortManifest()`
3. **Create dependent cohorts** - Build subsets for analyses
4. **Configure execution** - Set up database connection settings
5. **Generate cohorts** - Run pipeline to generate populations in database

See "Developing the Pipeline" for how to use these cohorts in your analysis tasks.
