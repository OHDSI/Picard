# Loading Inputs: Getting Started

## Overview

Before running your study pipeline you need two types of inputs:

- **Cohorts** — study populations, comparators, and outcomes as CIRCE
  JSON definitions (from ATLAS or Capr) or custom SQL
- **Concept Sets** — phenotype definitions for diseases, exposures,
  covariates, etc.

Picard tracks both through *manifests* — SQLite databases that record
every definition’s file path, MD5 hash, metadata, and provenance. Each
session you load the manifest into memory; the SQLite file is the
durable source of truth.

For a deep-dive into the manifest architecture, derived cohorts,
mid-cycle changes, and reset options, see the [Manifest: Architecture,
Workflows, and
Helpers](https://ohdsi.github.io/Picard/articles/manifest_overview.md)
vignette.

------------------------------------------------------------------------

## Pre-Pipeline Builder Scripts

Every picard study is initialized with a set of **builder scripts** in
dedicated folders under `inputs/`:

- **`inputs/conceptSets/R/`** — Scripts for building concept set
  manifests
- **`inputs/cohorts/R/`** — Scripts for building cohort manifests

These scripts are **pre-populated** at project initialization with
templates for six different builder types. You choose which builders to
use by keeping the scripts you need and deleting the ones you don’t.

**When you run `main.R`**, the pipeline automatically discovers and
sources all remaining builder scripts in a **mandatory dependency
order**. This ensures concept sets load before cohorts:

- ✅ No manual [`source()`](https://rdrr.io/r/base/source.html) calls
  needed in `main.R`
- ✅ No `main.R` edits required when deleting scripts
- ✅ Each builder script is self-contained with embedded guidance
  comments
- ✅ Mandatory source order prevents dependency conflicts
- ⚠️ Builder scripts must go in `inputs/cohorts/R/` and
  `inputs/conceptSets/R/` — **NOT** in `analysis/tasks/`

### Available Builder Script Types

#### Concept Sets

| Script                       | Purpose                                                       |
|------------------------------|---------------------------------------------------------------|
| `import_atlas_concept_set.R` | Bulk import concept sets from ATLAS via CSV + connection      |
| `import_capr_concept_set.R`  | Build concept sets programmatically using Capr cs() functions |

#### Cohorts

| Script                      | Purpose                                                    |
|-----------------------------|------------------------------------------------------------|
| `import_atlas_cohort.R`     | Bulk import cohorts from ATLAS via CSV + connection        |
| `import_capr_cohort.R`      | Build cohorts programmatically using Capr library          |
| `import_sql_cohort.R`       | Load custom SQL-based cohorts                              |
| `build_dependent_cohorts.R` | Create derived cohorts (temporal, union, complement, etc.) |

### Typical Workflow

1.  **Project initializes** with all 6 builder scripts pre-created
2.  **Edit the builders you need** — Each script has clear guidance
    comments
3.  **Delete unused builders** — Remove scripts you don’t need
4.  **Run `main.R`** —
    [`sourceInputBuilderScripts()`](https://ohdsi.github.io/Picard/reference/sourceInputBuilderScripts.md)
    auto-discovers and runs remaining scripts in mandatory order
5.  **Manifests load** — Your cohorts and concept sets are ready for the
    pipeline

Example: If you only use ATLAS for concept sets and Capr for cohorts:

    inputs/conceptSets/R/
      ✓ import_atlas_concept_set.R
      ✗ import_capr_concept_set.R (deleted)

    inputs/cohorts/R/
      ✗ import_atlas_cohort.R (deleted)
      ✓ import_capr_cohort.R
      ✗ import_sql_cohort.R (deleted)
      ✗ build_dependent_cohorts.R (deleted)

When `main.R` runs, only `import_atlas_concept_set.R` and
`import_capr_cohort.R` source (in order: concept sets first, then
cohorts).

------------------------------------------------------------------------

## Builder Pattern 1: ATLAS Import

### Importing Concept Sets from ATLAS

This pattern uses `inputs/conceptSets/R/import_atlas_concept_set.R`.

#### Step 1: Initialize the manifest

``` r
conceptSetManifest <- initConceptSetManifest()
```

This creates `inputs/conceptSets/conceptSetManifest.sqlite` if it does
not already exist and returns a `ConceptSetManifest` R6 object.

#### Step 2: Create and fill the load file

``` r
createBlankConceptSetsLoadFile()
```

Opens `inputs/conceptSets/conceptSetsLoad.csv`. Fill in one row per
concept set:

| Column       | Required | Notes                                         |
|--------------|----------|-----------------------------------------------|
| `atlasId`    | Yes      | ATLAS concept set ID                          |
| `label`      | Yes      | Display name                                  |
| `domain`     | Yes      | OMOP domain (e.g., `drug_exposure`)           |
| `sourceCode` | No       | `TRUE`/`FALSE` — whether it uses source codes |

Any additional columns are stored as tags.

#### Step 3: Set up ATLAS Credentials

Before connecting to ATLAS, store your credentials securely in
`~/.picard/secrets.yml`:

``` r
# Interactive setup for Atlas credentials - guides you through keyring storage
setupAtlasSecretsKeyring()

# Or edit the secrets file directly
editSecrets()
```

This creates/updates `~/.picard/secrets.yml` with your credentials
stored securely:

``` yaml
atlas:
  baseUrl: "https://organization-atlas.com/WebAPI"
  authMethod: "ad"
  user: "atlas.user@company.com"
  password: !expr keyring::key_get(service = "picard", username = "atlasPassword")
```

Recommended: Use **Keyring** to store passwords securely instead of
plaintext.

#### Step 4: Connect to ATLAS and import

``` r
# Credentials are automatically read from ~/.picard/secrets.yml
atlasConnection <- getAtlasConnection()

conceptSetManifest$setAtlasConnection(atlasConnection)

# Read the CSV file
conceptSetsLoad <- readr::read_csv(
  here::here("inputs/conceptSets/conceptSetsLoad.csv"),
  show_col_types = FALSE
)

# Import
conceptSetManifest$importAtlasConceptSets(
  conceptSetsLoad = conceptSetsLoad,
  atlasConnection = atlasConnection
)
```

This downloads JSON definitions to `inputs/conceptSets/json/` and
updates your manifest with metadata.

**Tip:** You can also pass the dataframe directly without reading from a
file, which is useful for programmatic workflows.

#### Step 5: Load and review

``` r
conceptSetManifest <- loadConceptSetManifest()
conceptSetManifest$tabulateManifest()
```

**Auto-discovery:**
[`loadConceptSetManifest()`](https://ohdsi.github.io/Picard/reference/loadConceptSetManifest.md)
scans `inputs/conceptSets/json/` and auto-registers any `.json` files
not yet in the database. Drop new concept set JSON files there and
re-run
[`loadConceptSetManifest()`](https://ohdsi.github.io/Picard/reference/loadConceptSetManifest.md)
to pick them up without any additional import step.

### Importing Cohorts from ATLAS

This pattern uses `inputs/cohorts/R/import_atlas_cohort.R`.

#### Step 1: Initialize the manifest

``` r
cohortManifest <- initCohortManifest()
```

#### Step 2: Create and fill the load file

``` r
createBlankCohortsLoadFile()
```

Opens `inputs/cohorts/cohortsLoad.csv`. Fill in one row per cohort:

| Column        | Required | Notes                                          |
|---------------|----------|------------------------------------------------|
| `atlasId`     | Yes      | ATLAS cohort definition ID                     |
| `label`       | Yes      | Display name                                   |
| `category`    | Yes      | Broad grouping (e.g., `"Disease Populations"`) |
| `subCategory` | No       | Optional sub-grouping                          |

Any additional columns are stored as tags.

#### Step 3: Set up ATLAS Credentials

Follow the same process as concept sets above using
[`setupAtlasSecretsKeyring()`](https://ohdsi.github.io/Picard/reference/setupAtlasSecretsKeyring.md)
or
[`editSecrets()`](https://ohdsi.github.io/Picard/reference/editSecrets.md).

#### Step 4: Connect to ATLAS and import

``` r
# Credentials are automatically read from ~/.picard/secrets.yml
atlasConnection <- getAtlasConnection()

cohortManifest$setAtlasConnection(atlasConnection)

# Read the CSV file
cohortsLoad <- readr::read_csv(
  here::here("inputs/cohorts/cohortsLoad.csv"),
  show_col_types = FALSE
)

# Import
cohortManifest$importAtlasCohorts(
  cohortsLoad = cohortsLoad,
  atlasConnection = atlasConnection
)
```

Downloads CIRCE JSON definitions to `inputs/cohorts/json/` and records
each cohort in SQLite.

**Tip:** You can also pass the dataframe directly without reading from a
file, which is useful for programmatic workflows.

#### Step 5: Load and review

``` r
cohortManifest <- loadCohortManifest()
cohortManifest$tabulateManifest()
```

### Checking for ATLAS Changes (Mid-Cycle)

After the initial import, you can periodically check whether definitions
in ATLAS have changed. The workflow uses two phases:

**Phase 1: Detection** — Compares remote ATLAS hashes to stored local
hashes:

``` r
# For concept sets
conceptSetManifest$checkAtlasConceptSets(atlasConnection)

# For cohorts
cohortManifest$checkAtlasCohorts(atlasConnection)
```

Reports which definitions have changed in ATLAS.

**Phase 2: Update** — Downloads updated definitions and re-writes JSON
files:

``` r
# For concept sets
conceptSetManifest$updateAtlasConceptSets(atlasConnection)

# For cohorts
cohortManifest$updateAtlasCohorts(atlasConnection)
```

Updates the manifest with new hashes and cascades `'stale'` status to
any downstream dependent cohorts (for cohorts only).

------------------------------------------------------------------------

## Builder Pattern 2: Capr-Based Building

### Building Concept Sets with Capr

This pattern uses `inputs/conceptSets/R/import_capr_concept_set.R` and
requires the Capr package.

Capr provides an R interface for building OMOP concept sets
programmatically:

``` r
library(Capr)

conceptSetManifest <- loadConceptSetManifest()

# Example 1: Diabetes mellitus concepts
diabetesConcepts <- cs(
  descendants(201820),  # Type 2 diabetes mellitus
  descendants(443238)   # Insulin-dependent diabetes mellitus
)
conceptSetManifest$addCaprConceptSet(
  conceptSetName = "Diabetes",
  conceptSet = diabetesConcepts
)

# Example 2: Antidiabetic drugs
antidiabeticDrugs <- cs(
  descendants(21600960),  # Metformin
  descendants(21601389),  # Sulfonylureas
  descendants(21602722),  # SGLT2 inhibitors
  sourceCode = TRUE
)
conceptSetManifest$addCaprConceptSet(
  conceptSetName = "AntidiabeticDrugs",
  conceptSet = antidiabeticDrugs
)
```

See the [Capr documentation](https://ohdsi.github.io/Capr/) for detailed
syntax and more complex concept set definitions.

### Building Cohorts with Capr

This pattern uses `inputs/cohorts/R/import_capr_cohort.R` and requires
the Capr package.

Capr provides a fluent interface for building cohort definitions in R:

``` r
library(Capr)

cohortManifest <- loadCohortManifest()

# Example: Type 2 Diabetes cohort with washout period
t2dCohort <- cohort(
  entry = entry(
    condition(
      descendants(201820),  # Type 2 diabetes
      on = "conditionStart"
    ) %>%
      filter(
        relationshipDomain(
          "measurement",
          descendants(3002962)  # HbA1c measurement
        ),
        duringInterval(daysBefore = 365, daysAfter = 1)
      )
  ),
  attrition(
    "No prior T2D",
    !condition(descendants(201820), on = "conditionStart") %>%
      during(daysBefore = 365)
  )
)

cohortManifest$addCaprCohort(
  cohortName = "Type2Diabetes_HbA1c",
  cohort = t2dCohort
)
```

See the [Capr documentation](https://ohdsi.github.io/Capr/) for detailed
examples.

------------------------------------------------------------------------

## Builder Pattern 3: Custom SQL Cohorts

This pattern uses `inputs/cohorts/R/import_sql_cohort.R`.

Custom SQL cohorts let you define cohorts using hand-written SQL
queries. Place your SQL files in `inputs/cohorts/sql/`:

``` r
cohortManifest <- loadCohortManifest()

# Add a custom SQL cohort
cohortManifest$addSqlCohort(
  cohortName = "MyCustomCohort",
  sqlPath = here::here("inputs/cohorts/sql/my_custom_cohort.sql"),
  # SqlRender parameters (will substitute @param in the SQL file)
  targetCohortId = 1001,
  cdmDatabaseSchema = "cdm"
)
```

SQL files must follow SqlRender conventions with parameters prefixed by
`@`:

``` sql
-- Cohort: Patients with Type 2 Diabetes
DELETE FROM @target_database_schema.cohort
WHERE cohort_definition_id = @target_cohort_id;

INSERT INTO @target_database_schema.cohort
  (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
SELECT
  @target_cohort_id as cohort_definition_id,
  person_id as subject_id,
  condition_start_date as cohort_start_date,
  DATEADD(day, 365, condition_start_date) as cohort_end_date
FROM @cdm_database_schema.condition_occurrence
WHERE condition_concept_id IN (201820, 443238)
  AND condition_start_date >= '2015-01-01';
```

Key SqlRender parameters: - `@target_cohort_id` — The numeric ID for
your cohort - `@target_database_schema` — The schema where results will
be written - `@cdm_database_schema` — The CDM database schema location -
`@vocabulary_database_schema` — The vocabulary schema location

> Always use `DELETE` before `INSERT` to make your cohort idempotent
> (can be re-run without duplication).

------------------------------------------------------------------------

## Builder Pattern 4: Derived Cohorts

This pattern uses `inputs/cohorts/R/build_dependent_cohorts.R`.

Derived cohorts are relationships between existing base cohorts. All
base cohorts must be imported first (via ATLAS, Capr, or SQL).

``` r
cohortManifest <- loadCohortManifest()

# Ensure base cohorts exist
# - CohortId 1: Chronic Kidney Disease
# - CohortId 2: Type 2 Diabetes

# Example 1: Temporal - CKD in patients with prior T2D
cohortManifest$buildSubsetCohortTemporal(
  baseCohortId = 1,
  subsetParent = 2,
  temporalType = "prior",
  daysBefore = 365,
  daysAfter = 0,
  newCohortName = "CKD_With_Prior_T2D"
)

# Example 2: Union - CKD or T2D patients
cohortManifest$buildUnionCohort(
  cohortIds = c(1, 2),
  newCohortName = "CKD_or_T2D"
)

# Example 3: Complement - CKD without T2D
cohortManifest$buildComplementCohort(
  baseCohortId = 1,
  excludeCohortId = 2,
  newCohortName = "CKD_Without_T2D"
)

# Example 4: O-Prior-T - Outcome prior to treatment
# (Outcome cohort excludes those with outcome before/during treatment)
cohortManifest$buildOPriorTCohort(
  outcomeCohortId = 3,
  treatmentCohortId = 2,
  daysBefore = 30,
  newCohortName = "Outcome_Prior_to_Treatment"
)
```

Relationship types: - **Temporal** — Base cohort with another cohort
before/after - **Union** — Combine multiple cohorts - **Complement** —
Base cohort excluding another cohort - **O-Prior-T** — Outcome before
treatment starts - **T-Prior-O** — Treatment before outcome - **Censor**
— Cohort with censoring date

See [Manifest: Architecture, Workflows, and
Helpers](https://ohdsi.github.io/Picard/articles/manifest_overview.md)
for comprehensive examples of all derived cohort types.

------------------------------------------------------------------------

## Subsequent Sessions

After the first-time import, subsequent sessions only need the manifest
load calls:

``` r
conceptSetManifest <- loadConceptSetManifest()
cohortManifest     <- loadCohortManifest()
```

Both functions read from SQLite and rebuild the in-memory R6 objects. No
network connection or CSV file is required.

These calls are included in the default builder scripts and will run
automatically when `main.R` executes
[`sourceInputBuilderScripts()`](https://ohdsi.github.io/Picard/reference/sourceInputBuilderScripts.md).

------------------------------------------------------------------------

## What’s Next

| Task                             | Where to go                                                                                                    |
|----------------------------------|----------------------------------------------------------------------------------------------------------------|
| Advanced manifest features       | [Manifest: Architecture, Workflows, and Helpers](https://ohdsi.github.io/Picard/articles/manifest_overview.md) |
| Running the analysis pipeline    | [Running the Pipeline](https://ohdsi.github.io/Picard/articles/running_the_pipeline.md)                        |
| Pipeline development and testing | [Developing the Pipeline](https://ohdsi.github.io/Picard/articles/developing_the_pipeline.md)                  |
| Creating a new study             | [Launching a Picard Study](https://ohdsi.github.io/Picard/articles/launching_a_study.md)                       |
