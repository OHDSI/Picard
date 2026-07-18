<!-- AUTO-GENERATED FILE. DO NOT EDIT DIRECTLY. -->
<!-- Source: vignettes/loading_inputs.Rmd -->


```{r setup, include = FALSE}
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  eval = FALSE
)
```

## Overview

Before running your study pipeline you need two types of inputs:

- **Cohorts** — study populations, comparators, and outcomes as CIRCE JSON
  definitions (from ATLAS or Capr) or custom SQL
- **Concept Sets** — phenotype definitions for diseases, exposures, covariates,
  etc.

Picard tracks both through *manifests* — SQLite databases that record every
definition's file path, MD5 hash, metadata, and provenance. Each session you
load the manifest into memory; the SQLite file is the durable source of truth.

This guide focuses on **loading and registering inputs** for day-to-day pipeline
use. For mid-cycle operations such as check, update, delete, and reset, use the
[Manifest Management](manifest_management.html) vignette.

---

## Pre-Pipeline Builder Scripts

Every picard study is initialized with a set of **builder scripts** in dedicated
folders under `inputs/`:

- **`inputs/conceptSets/R/`** — Scripts for building concept set manifests
- **`inputs/cohorts/R/`** — Scripts for building cohort manifests

These scripts are **pre-populated** at project initialization with templates for
six different builder types. You choose which builders to use by keeping the
scripts you need and deleting the ones you do not.

**When you run `main.R`**, the pipeline automatically discovers and sources all
remaining builder scripts in a **mandatory dependency order**. This ensures concept sets load before cohorts:

- ✅ No manual `source()` calls needed in `main.R`
- ✅ No `main.R` edits required when deleting scripts
- ✅ Each builder script is self-contained with embedded guidance comments
- ✅ Mandatory source order prevents dependency conflicts
- ⚠️ Builder scripts must go in `inputs/cohorts/R/` and `inputs/conceptSets/R/` — **NOT** in `analysis/tasks/`

### Available Builder Script Types

#### Concept Sets

| Script | Purpose |
|---|---|
| `import_atlas_concept_set.R` | Bulk import concept sets from ATLAS via CSV + connection |
| `import_capr_concept_set.R` | Build concept sets programmatically using Capr cs() functions |

#### Cohorts

| Script | Purpose |
|---|---|
| `import_atlas_cohort.R` | Bulk import cohorts from ATLAS via CSV + connection |
| `import_capr_cohort.R` | Build cohorts programmatically using Capr library |
| `import_sql_cohort.R` | Load custom SQL-based cohorts |
| `build_dependent_cohorts.R` | Create derived cohorts (temporal, union, complement, etc.) |

### Typical Workflow

1. **Project initializes** with all 6 builder scripts pre-created
2. **Edit the builders you need** - Each script has clear guidance comments
3. **Delete unused builders** - Remove scripts you do not need
4. **Run `main.R`** - `sourceInputBuilderScripts()` auto-discovers and runs remaining scripts in mandatory order
5. **Manifests load** - Your cohorts and concept sets are ready for the pipeline

Example: If you only use ATLAS for concept sets and Capr for cohorts:

```
inputs/conceptSets/R/
  ✓ import_atlas_concept_set.R
  ✗ import_capr_concept_set.R (deleted)

inputs/cohorts/R/
  ✗ import_atlas_cohort.R (deleted)
  ✓ import_capr_cohort.R
  ✗ import_sql_cohort.R (deleted)
  ✗ build_dependent_cohorts.R (deleted)
```

When `main.R` runs, only `import_atlas_concept_set.R` and `import_capr_cohort.R` source (in order: concept sets first, then cohorts).

---

## Concept Set Import

### Importing Concept Sets from ATLAS

This pattern uses `inputs/conceptSets/R/import_atlas_concept_set.R`.

Prerequisite setup for manifests, load files, and credentials is covered in
[Launching a Picard Study](launching_a_study.html).

#### Step 1: Connect to ATLAS and import

```{r}
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

This downloads JSON definitions to `inputs/conceptSets/json/` and updates your manifest with metadata.

**Tip:** You can also pass the dataframe directly without reading from a file, which is useful for programmatic workflows.

#### Step 2: Load and review

```{r}
conceptSetManifest <- loadConceptSetManifest()
conceptSetManifest$tabulateManifest()
```

**Auto-discovery:** `loadConceptSetManifest()` scans `inputs/conceptSets/json/`
and auto-registers any `.json` files not yet in the database. Drop new concept
set JSON files there and re-run `loadConceptSetManifest()` to pick them up
without any additional import step.

### Other import patterns for Concept Sets

Use this pattern when you want to supplement ATLAS-imported concept sets with
programmatic Capr definitions, then combine them into one manifest entry.

```{r}
library(Capr)

conceptSetManifest <- loadConceptSetManifest()

# Add Capr concept set example 1
metforminCs <- cs(descendants(1503297), name = "metformin")

conceptSetManifest$addCaprConceptSet(
  caprConceptSet = metforminCs,
  label = "Metformin",
  category = "Diabetes Treatments",
  tags = list(source = "capr")
)

# Add Capr concept set example 2
empagliflozinCs <- cs(
  descendants(45774751), # empagliflozin
  name  = "empagliflozin"
)

conceptSetManifest$addCaprConceptSet(
  caprConceptSet = empagliflozinCs,
  label = "Empagliflozin",
  category = "Diabetes Treatments",
  tags = list(source = "capr")
)

# get the ids
metforminId <- conceptSetManifest$queryConceptSetsByLabel("Metformin")$id
empagliflozinId <- conceptSetManifest$queryConceptSetsByLabel("Empagliflozin")$id

# Combine concept sets (works for IDs from ATLAS, Capr, or mixed sources)
conceptSetManifest$combineConceptSets(
  conceptSetIds = c(metforminId, empagliflozinId),
  combinedLabel = "Diabetes Treatments",
  combinedCategory = "Treatment Group",
  combinedTags = list(owner = "epi_team")
)

conceptSetManifest$tabulateManifest()
```

## Cohort Import

### Importing Cohorts from ATLAS

This pattern uses `inputs/cohorts/R/import_atlas_cohort.R`.

Prerequisite setup for manifests, load files, and credentials is covered in
[Launching a Picard Study](launching_a_study.html).

#### Step 1: Connect to ATLAS and import

```{r}
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

Downloads CIRCE JSON definitions to `inputs/cohorts/json/` and records each
cohort in SQLite.

**Tip:** You can also pass the dataframe directly without reading from a file, which is useful for programmatic workflows.

#### Step 2: Load and review

```{r}
cohortManifest <- loadCohortManifest()
cohortManifest$tabulateManifest()
```

---

## Builder Pattern 2: Capr-Based Building

### Building Concept Sets with Capr

This pattern uses `inputs/conceptSets/R/import_capr_concept_set.R` and requires the Capr package.

Capr provides an R interface for building OMOP concept sets programmatically:

```{r}
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

See the [Capr documentation](https://ohdsi.github.io/Capr/) for detailed syntax
and more complex concept set definitions.

### Building Cohorts with Capr

This pattern uses `inputs/cohorts/R/import_capr_cohort.R` and requires the Capr package.

Capr provides a fluent interface for building cohort definitions in R:

```{r}
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

See the [Capr documentation](https://ohdsi.github.io/Capr/) for detailed examples.

---

## Builder Pattern 3: Custom SQL Cohorts

This pattern uses `inputs/cohorts/R/import_sql_cohort.R`.

Custom SQL cohorts let you define cohorts using hand-written SQL queries. Place
your SQL files in `inputs/cohorts/sql/`:

```{r}
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
WHERE condition_concept_id IN (201820, 443238)
  AND condition_start_date >= '2015-01-01';
```

Key SqlRender parameters:
- `@target_cohort_id` — The numeric ID for your cohort
- `@target_database_schema` — The schema where results will be written
- `@cdm_database_schema` — The CDM database schema location
- `@vocabulary_database_schema` — The vocabulary schema location

> Always use `DELETE` before `INSERT` to make your cohort idempotent
> (can be re-run without duplication).

### Custom Dependent SQL Cohorts 

Use this pattern when a custom SQL cohort depends on one or more previously
defined cohorts (for example inclusion/exclusion cohorts). This registers the
cohort as a dependency-aware derived type (`custom_derived`) so execution order,
stale detection, and dependency hashing are handled automatically. 

```{r}
cohortManifest <- loadCohortManifest()

# Example dependencies already in the manifest:
# - 1001 = Inclusion cohort
# - 1002 = Exclusion cohort

cohortManifest$addDependentCustomCohort(
  filePath = here::here("inputs/cohorts/sql/my_custom_dependent.sql"),
  label = "Eligible_With_Exclusions",
  category = "Derived Cohorts",
  dependentCohortIdList = list(
    inc_cohort_id = 1001L,
    exc_cohort_id = 1002L
  ),
  tags = list(owner = "epi_team", source = "custom_sql")
)
```

How it works:

- `dependentCohortIdList` is a **named mapping** of SqlRender parameter name to
  cohort ID.
- Parameter names are flexible (for example `inc_cohort_id`, `exc_cohort_id`,
  `baseline_cohort_id`) and are injected at runtime.
- All mapped cohort IDs must already exist in the manifest.

Your SQL file should reference the mapped placeholders:

```sql
DELETE FROM @target_database_schema.@target_cohort_table
WHERE cohort_definition_id = @target_cohort_id;

INSERT INTO @target_database_schema.@target_cohort_table
  (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
SELECT
  @target_cohort_id,
  i.subject_id,
  i.cohort_start_date,
  i.cohort_end_date
FROM @target_database_schema.@target_cohort_table i
LEFT JOIN @target_database_schema.@target_cohort_table e
  ON i.subject_id = e.subject_id
  AND e.cohort_definition_id = @exc_cohort_id
WHERE i.cohort_definition_id = @inc_cohort_id
  AND e.subject_id IS NULL;
```

Required contract for dependent custom SQL:

- Must `DELETE` from `@target_database_schema.@target_cohort_table` using
  `@target_cohort_id`.
- Must `INSERT` into `@target_database_schema.@target_cohort_table` with columns
  `(cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)`.

This ensures custom dependent SQL cohorts behave consistently with other derived
cohorts in manifest review and pipeline execution.

For dependency internals (dependency graph ordering, `dependency_rule` storage,
and stale/hash behavior), see
[Manifest Management](manifest_management.html).

---

## Builder Pattern 4: Derived Cohorts

This pattern uses `inputs/cohorts/R/build_dependent_cohorts.R`.

Derived cohorts are relationships between existing base cohorts. All base cohorts
must be imported first (via ATLAS, Capr, or SQL).

Start by loading the cohort manifest.

```{r derived_setup}
cohortManifest <- loadCohortManifest()
```

Assume these base cohorts already exist in your manifest:

- CohortId 1: Chronic Kidney Disease
- CohortId 2: Type 2 Diabetes
- CohortId 3: Major Bleeding Outcome
- CohortId 4: All-Cause Death

### Example 1: Temporal Subset

Build a cohort of CKD patients with a T2D event in a start-date window from 365 days before to 0 days after the base cohort start date.

```{r derived_temporal_subset}
startWindow <- createSubsetStartWindow(
  subsetCohortWindowAnchor = "cohort_start_date",
  startDays = -365,
  endDays = 0,
  baseCohortWindowAnchor = "cohort_start_date"
)

cohortManifest$buildSubsetCohortTemporal(
  label = "CKD_With_Prior_T2D",
  category = "Derived Cohorts",
  baseCohortId = 1,
  filterCohortId = 2,
  startWindow = startWindow
)
```

### Example 2: Union Cohort

Build a cohort that includes anyone in either CKD or T2D.

```{r derived_union}
cohortManifest$buildUnionCohort(
  label = "CKD_or_T2D",
  category = "Derived Cohorts",
  cohortIds = c(1, 2),
  gapDays = 0L
)
```

### Example 3: Complement Cohort

Build a CKD cohort that excludes patients in T2D.

```{r derived_complement}
cohortManifest$buildComplementCohort(
  label = "CKD_Without_T2D",
  category = "Derived Cohorts",
  populationCohortId = 1,
  excludeCohortIds = c(2)
)
```

### Example 4: Composite Cohort

Build a cohort requiring membership in multiple component cohorts (intersection style criteria).

```{r derived_composite}
cohortManifest$buildCompositeCohort(
  label = "CKD_and_T2D_Composite",
  category = "Derived Cohorts",
  criteriaCohortIds = c(1, 2),
  minEventCount = 2L,
  eventSelection = "First"
)
```

### Example 5: Demographic Subset Cohort

Build a demographic subset of CKD patients (for example, age and sex criteria).

```{r derived_demographic}
cohortManifest$buildDemographicCohort(
  label = "CKD_Males_40_to_75",
  baseCohortId = 1,
  category = "Derived Cohorts",
  minAge = 40L,
  maxAge = 75L,
  genderConceptIds = c(8507)
)
```

### Example 6: Stratified Cohorts

Split one base cohort into multiple strata plus an automatic Unclassified cohort.

```{r derived_stratified}
strata <- list(
  "Female" = list(genderConceptIds = c(8532)),
  "Male" = list(genderConceptIds = c(8507)),
  "Age_65_plus" = list(minAge = 65L)
)

cohortManifest$buildStratifiedCohorts(
  baseCohortId = 1,
  strata = strata,
  labelPrefix = "CKD",
  category = "Derived Cohorts"
)
```

### Example 7: O-Prior-T Cohort

Filter outcome events to those with prior target exposure in a 30-day lookback window.

```{r derived_opriort}
cohortManifest$buildOPriorT(
  label = "Outcome_Prior_Target",
  category = "Derived Cohorts",
  outcomeCohortId = 3,
  targetCohortId = 2,
  mode = "prior",
  priorTimeWindowDays = 30L
)
```

### Example 8: T-Prior-O Cohort

Filter target events to those with prior outcome occurrence in a 30-day lookback window.

```{r derived_tprioro}
cohortManifest$buildTPriorO(
  label = "Target_Prior_Outcome",
  category = "Derived Cohorts",
  targetCohortId = 2,
  outcomeCohortId = 3,
  mode = "prior",
  priorTimeWindowDays = 30L
)
```

### Example 9: Censor Cohort

Create a censored version of a target cohort using a censoring event cohort.

```{r derived_censor}
cohortManifest$buildCensorCohort(
  label = "T2D_Censored_At_Death",
  category = "Derived Cohorts",
  targetCohortId = 2,
  censorCohortId = 4
)
```

Build methods shown above:
- `buildSubsetCohortTemporal()`
- `buildUnionCohort()`
- `buildComplementCohort()`
- `buildCompositeCohort()`
- `buildDemographicCohort()`
- `buildStratifiedCohorts()`
- `buildOPriorT()`
- `buildTPriorO()`
- `buildCensorCohort()`

See [Manifest Management](manifest_management.html)
for comprehensive examples of all derived cohort types.

---

## Subsequent Sessions

After the first-time import, subsequent sessions only need the manifest load calls:

```{r}
conceptSetManifest <- loadConceptSetManifest()
cohortManifest     <- loadCohortManifest()
```

Both functions read from SQLite and rebuild the in-memory R6 objects. No
network connection or CSV file is required.

These calls are included in the default builder scripts and will run automatically
when `main.R` executes `sourceInputBuilderScripts()`.

---

## What's Next

| Task | Where to go |
|---|---|
| Study setup and editable inputs | [Launching a Picard Study](launching_a_study.html) |
| Manifest checks, updates, delete, and reset | [Manifest Management](manifest_management.html) |
| Running the analysis pipeline | [Running the Pipeline](running_the_pipeline.html) |
| Pipeline development and testing | [Developing the Pipeline](developing_the_pipeline.html) |
| Creating a new study | [Launching a Picard Study](launching_a_study.html) |
