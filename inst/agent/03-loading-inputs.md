# Loading Inputs: Pre-Pipeline Builder Scripts

## Introduction

Before running your study pipeline, you need to define the populations and phenotypes your analysis will use. Picard organizes these through two key input types:

- **Cohorts:** Define study populations, comparators, and outcomes as CIRCE-based JSON definitions, programmatic Capr definitions, or custom SQL
- **Concept Sets:** Define phenotypes for diseases, exposures, covariates, etc. as CIRCE-based JSON definitions or programmatic Capr definitions

Picard uses *manifests* to catalog, version, and track these definitions throughout your study. This document walks through the complete workflow for loading and managing cohorts and concept sets using **pre-pipeline builder scripts**.

## Pre-Pipeline Builder Scripts Overview

Every Picard study is initialized with a set of **builder scripts** in dedicated folders:

- **`inputs/conceptSets/R/`** — Scripts for building concept set manifests
- **`inputs/cohorts/R/`** — Scripts for building cohort manifests

These scripts are **pre-populated** with templates for six different builder types:

### Concept Set Builders

| Script | Purpose |
|---|---|
| `importAtlas.R` | Bulk import concept sets from ATLAS via CSV + WebAPI connection |
| `importCapr.R` | Build concept sets programmatically using Capr cs() functions |

### Cohort Builders

| Script | Purpose |
|---|---|
| `importAtlas.R` | Bulk import cohorts from ATLAS via CSV + WebAPI connection |
| `importCapr.R` | Build cohorts programmatically using Capr library |
| `importSql.R` | Load custom SQL-based cohorts |
| `buildDependentCohorts.R` | Create derived cohorts (temporal, union, complement, etc.) |

## How Builder Scripts Work

1. **Project initializes** with all 6 builder scripts pre-created in their respective folders
2. **You choose which builders to use** by editing or deleting scripts:
   - **Keep scripts** you need (e.g., if using ATLAS only, keep `importAtlas.R`)
   - **Delete scripts** you don't need (e.g., if not using Capr, delete `importCapr.R`)
3. **Run `main.R`** which calls `sourceBuilderScripts()`
4. **Auto-discovery:** Remaining scripts are automatically discovered and sourced in order:
   - Concept set builders run first (importAtlas, then importCapr)
   - Cohort builders run second (importAtlas, importCapr, importSql, buildDependentCohorts)
5. **Manifests load** — Your cohorts and concept sets are ready for the pipeline

Each builder script is self-contained with embedded guidance comments for its workflow.

> **⚠️ Important:** Builder scripts belong in `inputs/cohorts/R/` and `inputs/conceptSets/R/` — **NOT** in `analysis/tasks/`

## Manifest Overview

A manifest is a SQLite database that catalogs and tracks definitions. For each cohort or concept set, the manifest stores:

- **Metadata:** ID, label, category, source (ATLAS or manual)
- **File information:** Path and MD5 hash for change detection
- **Provenance:** When added, last modified, execution status
- **Tags:** Categorization for querying and grouping

Manifests enable reproducibility and change tracking as your study evolves.

---

## Builder Pattern 1: ATLAS Import

### Importing Concept Sets from ATLAS

Edit `inputs/conceptSets/R/importAtlas.R`:

**Step 1:** Initialize the manifest

```r
conceptSetManifest <- initConceptSetManifest()
```

This creates `inputs/conceptSets/conceptSetManifest.sqlite` if needed.

**Step 2:** Create and fill the load file

```r
createBlankConceptSetsLoadFile()
```

Opens `inputs/conceptSets/conceptSetsLoad.csv`. Fill in one row per concept set:

| Column | Required | Notes |
|---|---|---|
| `atlasId` | Yes | ATLAS concept set ID |
| `label` | Yes | Display name |
| `domain` | Yes | OMOP domain (e.g., `drug_exposure`, `condition_occurrence`) |
| `sourceCode` | No | `TRUE`/`FALSE` — whether it includes source codes |

**Step 3:** Set up ATLAS Credentials

Before connecting to ATLAS, store your credentials securely using the secrets management system:

```r
# Interactive setup for Atlas credentials - guides you through keyring storage
setupAtlasSecretsKeyring()

# Or edit the secrets file directly
editSecrets()
```

This creates/updates `~/.picard/secrets.yml`:

```yaml
atlas:
  baseUrl: "https://organization-atlas.com/WebAPI"
  authMethod: "ad"
  user: "atlas.user@company.com"
  password: !expr keyring::key_get(service = "picard", username = "atlasPassword")
```

Recommended: Use **Keyring** to store passwords securely instead of plaintext.

**Step 4:** Connect to ATLAS and import

```r
atlasConnection <- getAtlasConnection()

conceptSetManifest$setAtlasConnection(atlasConnection)

conceptSetManifest$importAtlasConceptSets(
  conceptSetsLoadPath = here::here("inputs/conceptSets/conceptSetsLoad.csv")
)
```

This downloads JSON definitions to `inputs/conceptSets/json/` and updates your manifest.

**Step 5:** Load and review

```r
conceptSetManifest <- loadConceptSetManifest()
conceptSetManifest$tabulateManifest()
```

### Importing Cohorts from ATLAS

Edit `inputs/cohorts/R/importAtlas.R`:

**Step 1:** Initialize the manifest

```r
cohortManifest <- initCohortManifest()
```

**Step 2:** Create and fill the load file

```r
createBlankCohortsLoadFile()
```

Opens `inputs/cohorts/cohortsLoad.csv`. Fill in one row per cohort:

| Column | Required | Notes |
|---|---|---|
| `atlasId` | Yes | ATLAS cohort definition ID |
| `label` | Yes | Display name |
| `category` | Yes | Broad grouping (e.g., `"Disease Populations"`) |
| `subCategory` | No | Optional sub-grouping |

**Step 3:** Set up ATLAS Credentials

Use the same `setupAtlasSecretsKeyring()` or `editSecrets()` as for concept sets.

**Step 4:** Connect to ATLAS and import

```r
atlasConnection <- getAtlasConnection()

cohortManifest$setAtlasConnection(atlasConnection)

cohortManifest$importAtlasCohorts(
  cohortsLoadPath = here::here("inputs/cohorts/cohortsLoad.csv")
)
```

**Step 5:** Load and review

```r
cohortManifest <- loadCohortManifest()
cohortManifest$tabulateManifest()
```

---

## Builder Pattern 2: Capr-Based Building

### Building Concept Sets with Capr

Edit `inputs/conceptSets/R/importCapr.R` (requires `Capr` package installed):

Capr provides an R interface for building OMOP concept sets programmatically:

```r
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

# Example 2: Antidiabetic drugs with source codes
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

# Example 3: Statins (cardiovascular medications)
statins <- cs(
  descendants(21602484),  # Statins
  excludeDescendants(21602721)  # Exclude specific combination
)
conceptSetManifest$addCaprConceptSet(
  conceptSetName = "Statins",
  conceptSet = statins
)
```

See the [Capr documentation](https://ohdsi.github.io/Capr/) for detailed syntax, including `ancestors()`, `descendants()`, `maps()`, `excludeDescendants()`, and more complex concept set definitions.

### Building Cohorts with Capr

Edit `inputs/cohorts/R/importCapr.R` (requires `Capr` package installed):

Capr provides a fluent interface for building cohort definitions in R:

```r
library(Capr)

cohortManifest <- loadCohortManifest()

# Example: Type 2 Diabetes cohort with HbA1c measurement
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

# Example: CKD cohort with specific lab values
ckdCohort <- cohort(
  entry = entry(
    condition(
      descendants(193782)  # CKD
    )
  ),
  attrition(
    "At least one eGFR measurement",
    measurement(
      descendants(3048943)  # eGFR
    )
  )
)

cohortManifest$addCaprCohort(
  cohortName = "ChronicKidneyDisease",
  cohort = ckdCohort
)
```

See the [Capr documentation](https://ohdsi.github.io/Capr/) for detailed examples of entry, attrition, filter, and temporal operators.

---

## Builder Pattern 3: Custom SQL Cohorts

Edit `inputs/cohorts/R/importSql.R`:

Custom SQL cohorts let you define cohorts using hand-written SQL queries. Place your SQL files in `inputs/cohorts/sql/`:

```r
cohortManifest <- loadCohortManifest()

# Add a custom SQL cohort
cohortManifest$addSqlCohort(
  cohortName = "MyCustomCohort",
  sqlPath = here::here("inputs/cohorts/sql/my_custom_cohort.sql"),
  # SqlRender parameters (will substitute @param in the SQL file)
  targetCohortId = 1001,
  cdmDatabaseSchema = "cdm"
)

# Add another custom cohort
cohortManifest$addSqlCohort(
  cohortName = "AnotherCohort",
  sqlPath = here::here("inputs/cohorts/sql/another_cohort.sql"),
  targetCohortId = 1002,
  cdmDatabaseSchema = "cdm"
)
```

SQL files must follow SqlRender conventions with parameters prefixed by `@`:

```sql
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
WHERE condition_concept_id IN (201820, 443238)  -- T2D concept IDs
  AND condition_start_date >= '2015-01-01';
```

Key SqlRender parameters:
- `@target_cohort_id` — The numeric ID for your cohort
- `@target_database_schema` — The schema where results will be written
- `@cdm_database_schema` — The CDM database schema location
- `@vocabulary_database_schema` — The vocabulary schema location

> Always use `DELETE` before `INSERT` to make your cohort idempotent (can be re-run without duplication).

---

## Builder Pattern 4: Dependent Cohorts

Edit `inputs/cohorts/R/buildDependentCohorts.R`:

Derived cohorts are relationships between existing base cohorts. All base cohorts must be imported first (via ATLAS, Capr, or SQL).

```r
cohortManifest <- loadCohortManifest()

# Ensure base cohorts exist:
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

# Example 5: T-Prior-O - Treatment prior to outcome
cohortManifest$buildTPriorOCohort(
  targetCohortId = 2,
  outcomeCohortId = 3,
  daysBefore = -365,  # outcome must start 1+ years after target
  newCohortName = "Treatment_With_Subsequent_Outcome"
)

# Example 6: Censor - Truncate cohort at censoring event
cohortManifest$buildCensorCohort(
  baseCohortId = 2,
  censorCohortId = 4,  # death cohort
  newCohortName = "Treatment_Censored_at_Death"
)
```

Relationship types:
- **Temporal:** Base cohort with another cohort before/after
- **Union:** Combine multiple cohorts
- **Complement:** Base cohort excluding another cohort
- **O-Prior-T:** Outcome before treatment starts
- **T-Prior-O:** Treatment before outcome
- **Censor:** Cohort with censoring date

---

## Managing Manifests: Mid-Cycle Changes

Study development is rarely linear. Cohorts get revised in ATLAS, new definitions get added mid-analysis, or old definitions are retired. Use these methods to keep the manifest in sync.

### Checking Manifest Health

```r
cm <- loadCohortManifest()

# Full status table: id, label, status, deleted_at, file_exists
cm$validateManifest()

# Summary counts
cm$getManifestStatus()
# Returns: active_count, missing_count, deleted_count, next_available_id
```

### Syncing Manifest

Reconciles the SQLite manifest against `json/` and `sql/` on disk:

```r
synced <- cm$syncManifest()
# Returns data frame: id, label, action
# action: "added" | "hash_updated" | "missing_flagged" | "unchanged"
```

Use after: re-running `importAtlasCohorts()`, editing a SQL file directly, or deleting a cohort file.

### Deleting Definitions

```r
cm <- loadCohortManifest()

# Soft-delete: marks status = 'deleted', keeps record for audit trail
cm$deleteCohort(id = 5, reason = "Replaced by updated phenotype")

# Hard delete: permanently removes SQLite record
cm$removeCohort(id = 5, confirm = TRUE)

# Also delete the file on disk
cm$removeCohort(id = 5, deleteFile = TRUE, confirm = TRUE)

# Also drop rows from DBMS cohort table
cm$removeCohort(id = 5, deleteFile = TRUE, dropFromCohortTable = TRUE, confirm = TRUE)
```

### Querying and Reviewing Manifests

```r
cm <- loadCohortManifest()

# View manifest
manifest_df <- cm$tabulateManifest()

# Query specific cohorts by ID
cohort_1 <- cm$queryCohortsByIds(ids = 1L)

# Query by tag or category
cohorts_by_tag <- cm$queryCohortsByTag(tagStrings = "category: Primary")

# Query by status
missing_cohorts <- cm$queryCohortsByStatus(status = "missing")
```

### Visualizing Dependencies

Once you've defined dependent cohorts, visualize the relationship graph:

```r
cm <- loadCohortManifest()

# Generate a dependency report (Mermaid diagram + table)
report <- cm$visualizeCohortDependencies()

# Optionally save to file
cm$visualizeCohortDependencies(outputPath = here::here("inputs/cohorts"))
```

---

## Key Files and Folders

```
inputs/
├── cohorts/
│   ├── R/                        # Builder scripts (auto-sourced)
│   │   ├── importAtlas.R
│   │   ├── importCapr.R
│   │   ├── importSql.R
│   │   └── buildDependentCohorts.R
│   ├── json/                     # ATLAS JSON exports
│   │   ├── cohort_1.json
│   │   └── cohort_2.json
│   ├── sql/                      # Custom SQL cohorts
│   │   ├── my_custom_cohort.sql
│   │   └── another_cohort.sql
│   ├── cohortsLoad.csv           # Metadata for ATLAS import
│   └── cohortManifest.sqlite     # Manifest database
│
└── conceptSets/
    ├── R/                        # Builder scripts (auto-sourced)
    │   ├── importAtlas.R
    │   └── importCapr.R
    ├── json/                     # ATLAS JSON exports
    │   ├── concept_set_1.json
    │   └── concept_set_2.json
    ├── conceptSetsLoad.csv       # Metadata for ATLAS import
    └── conceptSetManifest.sqlite # Manifest database
```

---

## Workflow Summary

1. **Review builder scripts** in `inputs/cohorts/R/` and `inputs/conceptSets/R/`
   - Each script has embedded guidance comments
   - Edit scripts for your specific workflow

2. **Delete unused builders**
   - Remove scripts you don't need
   - Keep only importAtlas.R if only using ATLAS
   - Keep only importCapr.R if only using Capr

3. **Run `main.R`**
   - Calls `sourceBuilderScripts()` which auto-discovers remaining scripts
   - Concept set builders run first, cohort builders run second
   - Manifests are populated and ready for analysis

4. **Manage mid-cycle changes**
   - Re-edit and re-run builder scripts as needed
   - Use `syncManifest()` to keep manifests in sync with files
   - Delete or soft-delete outdated definitions

---

## Next Steps

1. **Edit pre-pipeline builders** — Customize scripts in `inputs/*/R/`
2. **Run main.R** — Execute production pipeline
3. **Review results** — Inspect generated cohorts and concept sets in manifests
4. **Develop analysis tasks** — Write scripts in `analysis/tasks/`
5. **Post-process** — Merge results across databases if needed

See "Developing the Pipeline" for how to use cohorts in your analysis tasks.
