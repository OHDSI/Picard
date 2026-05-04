# Loading Inputs: Getting Started

## Overview

Before running your study pipeline you need two types of inputs:

- **Cohorts** “” study populations, comparators, and outcomes as CIRCE
  JSON definitions (from ATLAS or Capr) or custom SQL
- **Concept Sets** “” phenotype definitions for diseases, exposures,
  covariates, etc.

Picard tracks both through *manifests* “” SQLite databases that record
every definition’s file path, MD5 hash, metadata, and provenance. Each
session you load the manifest into memory; the SQLite file is the
durable source of truth.

> For a deep-dive into the manifest architecture, derived cohorts,
> mid-cycle changes, and reset options, see the [Manifest: Architecture,
> Workflows, and
> Helpers](https://ohdsi.github.io/Picard/articles/manifest_overview.md)
> vignette.

------------------------------------------------------------------------

## The `loadingInputs.R` Template

Every picard study is generated with a `loadingInputs.R` script in
`extras/`. This script is the canonical place to run first-time setup
and subsequent-session loading. Open it in RStudio and work through the
sections in order.

The template has three top-level sections:

| Section                           | Purpose                                                                                                                                                                                                                     |
|-----------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **A. Concept Sets “” First Time** | [`initConceptSetManifest()`](https://ohdsi.github.io/Picard/reference/initConceptSetManifest.md), fill CSV, connect ATLAS, [`importAtlasConceptSets()`](https://ohdsi.github.io/Picard/reference/importAtlasConceptSets.md) |
| **B. Cohorts “” First Time**      | [`initCohortManifest()`](https://ohdsi.github.io/Picard/reference/initCohortManifest.md), fill CSV, connect ATLAS, [`importAtlasCohorts()`](https://ohdsi.github.io/Picard/reference/importAtlasCohorts.md)                 |
| **C. Subsequent Sessions**        | [`loadConceptSetManifest()`](https://ohdsi.github.io/Picard/reference/loadConceptSetManifest.md) + [`loadCohortManifest()`](https://ohdsi.github.io/Picard/reference/loadCohortManifest.md)                                 |

Run only the section that applies to your current situation.

------------------------------------------------------------------------

## Concept Sets “” First Time

### Step 1: Initialise the manifest

``` r
conceptSetManifest <- initConceptSetManifest()
```

This creates `inputs/conceptSets/conceptSetManifest.sqlite` if it does
not already exist and returns a `ConceptSetManifest` R6 object.

### Step 2: Create and fill the load file

``` r
createBlankConceptSetsLoadFile()
```

Opens `inputs/conceptSets/conceptSetsLoad.csv`. Fill in one row per
concept set:

| Column       | Required | Notes                                          |
|--------------|----------|------------------------------------------------|
| `atlasId`    | Yes      | ATLAS concept set ID                           |
| `label`      | Yes      | Display name                                   |
| `domain`     | Yes      | OMOP domain (e.g., `drug_exposure`)            |
| `sourceCode` | No       | `TRUE`/`FALSE` “” whether it uses source codes |

Any additional columns are stored as tags.

### Step 3: Connect to ATLAS and import

``` r
atlasConnection <- getAtlasConnection()            # reads credentials from .Renviron
conceptSetManifest$setAtlasConnection(atlasConnection)

conceptSetManifest$importAtlasConceptSets(
  conceptSetsLoadPath = here::here("inputs/conceptSets/conceptSetsLoad.csv")
)
```

[`getAtlasConnection()`](https://ohdsi.github.io/Picard/reference/getAtlasConnection.md)
reads `atlasBaseUrl`, `atlasAuthMethod`, `atlasUser`, and
`atlasPassword` from `.Renviron`. Run `usethis::edit_r_environ()` to add
them. For keyring-based storage use
`getAtlasConnection(useKeyring = TRUE)`.

### Step 4: Load and review

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

------------------------------------------------------------------------

## Cohorts “” First Time

### Step 1: Initialise the manifest

``` r
cohortManifest <- initCohortManifest()
```

### Step 2: Create and fill the load file

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

### Step 3: Connect to ATLAS and import

``` r
# Reuse the connection from the concept sets step, or create a new one:
# atlasConnection <- getAtlasConnection()
cohortManifest$setAtlasConnection(atlasConnection)

cohortManifest$importAtlasCohorts(
  cohortsLoadPath = here::here("inputs/cohorts/cohortsLoad.csv")
)
```

Downloads CIRCE JSON definitions to `inputs/cohorts/json/` and records
each cohort in SQLite.

### Step 4: Load and review

``` r
cohortManifest <- loadCohortManifest()
cohortManifest$tabulateManifest()
```

------------------------------------------------------------------------

## Subsequent Sessions

After the first-time import, subsequent sessions only need the two load
calls:

``` r
conceptSetManifest <- loadConceptSetManifest()
cohortManifest     <- loadCohortManifest()
```

Both functions read from SQLite and rebuild the in-memory R6 objects. No
network connection or CSV file is required.

------------------------------------------------------------------------

## What’s Next

| Task                                                   | Where to go                                                                                                    |
|--------------------------------------------------------|----------------------------------------------------------------------------------------------------------------|
| Derived cohorts (union, subset, complement, composite) | [Manifest: Architecture, Workflows, and Helpers](https://ohdsi.github.io/Picard/articles/manifest_overview.md) |
| Custom SQL cohorts                                     | [Manifest: Architecture, Workflows, and Helpers](https://ohdsi.github.io/Picard/articles/manifest_overview.md) |
| Mid-cycle changes, sync, delete, reset                 | [Manifest: Architecture, Workflows, and Helpers](https://ohdsi.github.io/Picard/articles/manifest_overview.md) |
| Running the analysis pipeline                          | [Running the Pipeline](https://ohdsi.github.io/Picard/articles/running_the_pipeline.md)                        |
