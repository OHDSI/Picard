# Manifest Management

This vignette focuses on mid-cycle manifest management: checking for
updates, syncing and reviewing stale records, updating metadata,
deleting records, and resetting manifests safely.

If you are setting up a study for the first time, start with the
[Loading Inputs: Getting
Started](https://ohdsi.github.io/Picard/articles/loading_inputs.md)
vignette instead.

For keyring and credential setup, use [Launching a Picard
Study](https://ohdsi.github.io/Picard/articles/launching_a_study.md).

------------------------------------------------------------------------

## Manifest Architecture Primer

### SQLite as the source of truth

Each manifest is a SQLite database file stored inside your study’s
`inputs/` folder:

    inputs/
    ├── cohorts/
    │   ├── cohortManifest.sqlite    # cohort manifest DB
    │   ├── json/                    # CIRCE JSON definitions (ATLAS / Capr)
    │   ├── sql/                     # custom hand-written SQL cohorts
    │   └── derived/                 # auto-generated SQL for derived cohorts
    └── conceptSets/
        ├── conceptSetManifest.sqlite
        └── json/                    # CIRCE JSON concept set definitions

The SQLite database is the **single source of truth** for all metadata.
The R6 `CohortManifest` and `ConceptSetManifest` objects are in-memory
mirrors loaded from SQLite at startup.

### Key columns in `cohort_manifest`

| Column            | Purpose                                                                                                                                |
|-------------------|----------------------------------------------------------------------------------------------------------------------------------------|
| `id`              | Auto-assigned integer ID                                                                                                               |
| `label`           | User-defined display name (unique among active records)                                                                                |
| `category`        | User classification (e.g., “Disease Populations”)                                                                                      |
| `cohort_type`     | `circe`, `custom`, `custom_derived`, `union`, `subset`, `complement`, `composite`, `oprior`, `tprior`, `censor`                        |
| `source_type`     | `circe`, `sql`, `derived`                                                                                                              |
| `file_path`       | Relative path to the SQL/JSON file on disk                                                                                             |
| `hash`            | MD5 of the file — used by [`generateCohorts()`](https://ohdsi.github.io/Picard/reference/generateCohorts.md) to skip unchanged cohorts |
| `depends_on`      | JSON array of parent cohort IDs (derived cohorts only)                                                                                 |
| `dependency_rule` | JSON object of build parameters (derived cohorts only)                                                                                 |
| `status`          | `active`, `stale`, `deleted`, or `purged`                                                                                              |
| `created_at`      | Timestamp of registration                                                                                                              |

### In-memory R6 object vs SQLite

When you call
[`loadCohortManifest()`](https://ohdsi.github.io/Picard/reference/loadCohortManifest.md),
the package:

1.  Opens the SQLite file
2.  Reads all `status = 'active'` rows
3.  Constructs a `CohortDef` R6 object for each row and holds them in a
    list

Mutations (add, delete, update) write to **both** SQLite and the
in-memory list. If you edit SQLite externally, call
`manifest$reloadFromDb()` to sync.

**Loading with automatic sync:**

``` r
# Auto-sync manifest against disk files on load (default: TRUE)
manifest <- loadCohortManifest(autoSync = TRUE, verbose = TRUE)

# Skip auto-sync if you know the manifest is up-to-date
manifest <- loadCohortManifest(autoSync = FALSE)
```

### Hash-based skip logic

Every cohort file has an MD5 hash stored in the manifest. At execution
time,
[`generateCohorts()`](https://ohdsi.github.io/Picard/reference/generateCohorts.md)
compares the current file hash to the stored hash and skips cohorts
whose files have not changed. For derived cohorts, a combined hash of
parent hashes plus the `dependency_rule` is used.

**Stale cohorts** (`status = 'stale'`) bypass the hash check and are
always re-executed. They are reset to `'active'` automatically after
successful execution. See [Section 4](#mid-cycle-changes) for how
cohorts become stale.

------------------------------------------------------------------------

## Manual Cohort Execution from CohortManifest

In most studies, cohort execution is triggered by running the study
pipeline (`main.R`) end-to-end. That is the preferred path for routine
runs.

For debugging and validation, you can also execute directly from
`CohortManifest` to verify table setup and check cohort enumeration.

### Typical manual sequence

``` r
# Load manifest and attach execution settings
manifest <- loadCohortManifest()
manifest$setExecutionSettings(execSettings)

# 1) Check required cohort tables in the target schema
manifest$checkCohortTables()

# 2) Create all required cohort tables (advanced/manual path)
manifest$createAllCohortTables()

# 3) Optionally create one table type explicitly
# Valid types: main, inclusion, inclusion_result, inclusion_stats,
# summary_stats, censor_stats, checksum
manifest$createCohortTable(type = "checksum")

# 4) Execute cohort generation from the manifest
manifest$executeCohortGeneration(confirm = TRUE)

# 5) Retrieve counts to verify cohort enumeration
manifest$retrieveCohortCounts()
```

Notes:

- `executeCohortGeneration()` checks required tables before running and
  can create missing tables in interactive sessions.
- `retrieveCohortCounts()` is useful for quick validation that expected
  cohorts were generated and populated.
- For production workflows, keep execution in the standard study
  pipeline path so all tasks run in the intended order.

------------------------------------------------------------------------

## Mid-Cycle Changes

### Sync manifest against disk files

If SQL or JSON files have been edited outside picard, `$syncManifest()`
updates stored hashes, reports unregistered files on disk, and —
crucially — **cascades a `stale` flag to all derived cohorts that depend
on any changed file**.

``` r
manifest$syncManifest()
```

When a base cohort’s SQL/JSON file changes, `syncManifest()` will:

1.  Detect the hash difference and update the stored hash
2.  Walk the dependency graph and mark every downstream derived cohort
    as `'stale'`
3.  Report each staled cohort by name

Stale derived cohorts still have valid SQL — their parent data has
changed but their build logic has not. They will be **re-executed
automatically** the next time
[`generateCohorts()`](https://ohdsi.github.io/Picard/reference/generateCohorts.md)
runs (the hash-skip is bypassed for stale cohorts).

### Checking for ATLAS updates (mid-cycle)

After the initial import, you can periodically check whether definitions
in ATLAS have been updated. This is done in two phases:

**Phase 1: Detection** — Compare remote ATLAS hashes to stored local
hashes:

``` r
# For cohorts
manifest$checkAtlasCohorts(atlasConnection)

# For concept sets
conceptSetManifest$checkAtlasConceptSets(atlasConnection)
```

This returns a report of which definitions have changed in ATLAS.

**Phase 2: Update** — Download updated definitions and re-write JSON
files:

``` r
# For cohorts
manifest$updateAtlasCohorts(atlasConnection)

# For concept sets
conceptSetManifest$updateAtlasConceptSets(atlasConnection)
```

When ATLAS definitions are updated: - JSON files are overwritten with
the latest definitions - Stored hashes are updated to reflect the new
versions - If the cohort is a base cohort, all downstream derived
cohorts automatically cascade to `'stale'` status - Derived cohorts will
be **re-executed automatically** on the next
[`generateCohorts()`](https://ohdsi.github.io/Picard/reference/generateCohorts.md)
run

### Review stale cohorts

``` r
# See which derived cohorts are waiting for re-execution
manifest$reviewStaleCohorts()
```

### Rebuilding the derived pipeline

If you need to change a build parameter (e.g. adjust `gapDays` on a
union cohort, or change demographic filters), the derived cohort SQL
needs to be re-rendered — not just re-executed. The workflow is:

``` r
# 1. Clear all derived cohorts (keeps base cohort registrations)
resetCohortManifest(manifest = manifest, scope = "derived")

# 2. Re-run your build script with corrected parameters
manifest$buildUnionCohort(
  label     = "T2DM or HF - Any",
  cohortIds = c(1L, 2L),
  category  = "Composite Populations",
  gapDays   = 7L   # corrected value
)
# ... other build calls ...
```

### Update label, category, or tags

``` r
# Update label
manifest$updateCohortLabel(cohortId = 3L, newLabel = "Metformin Initiators (revised)")

# Update category
manifest$updateCohortCategory(cohortId = 3L, newCategory = "Exposure")

# Update tags
manifest$updateCohortTags(cohortId = 3L, newTags = list(subCategory = "Antidiabetics"))
```

### Delete a cohort

Marks the cohort as `deleted` in SQLite with a deletion timestamp (soft
delete). The cohort is excluded from generation but the record is
preserved for audit trail.

``` r
# Soft delete (default)
manifest$deleteCohort(id = 3L, confirm = TRUE)

# Delete and also remove from DBMS cohort table (requires executionSettings)
manifest$deleteCohort(id = 3L, dropFromDBMS = TRUE, confirm = TRUE)
```

When `dropFromDBMS = TRUE`: - Deletes the cohort file from disk - Marks
the manifest record as `deleted` - Removes rows from the DBMS cohort
table and checksum table (if it exists) - Requires `executionSettings`
to be attached to the manifest

**Note:** Deletion is soft (records are preserved). For permanent hard
deletion from SQLite, use administrative database tools directly.

------------------------------------------------------------------------

## Reset

Use
[`resetCohortManifest()`](https://ohdsi.github.io/Picard/reference/resetCohortManifest.md)
when you need to clear cohort data. Choose the scope based on what you
want to preserve:

| Scope        | SQLite                         | `derived/` | `json/` + `sql/` | OMOP tables |
|--------------|--------------------------------|------------|------------------|-------------|
| `"derived"`  | Updated (derived rows removed) | Deleted    | Kept             | Not touched |
| `"manifest"` | Deleted                        | Deleted    | Kept             | Not touched |
| `"full"`     | Deleted                        | Deleted    | Deleted          | Dropped     |

### Which scope do I need?

- **Rebuilding derived pipeline with new parameters** → `"derived"`.
  Your base cohort registrations and ATLAS imports are preserved; just
  re-run the `$build*()` calls.
- **Corrupt or restructured database** → `"manifest"`. Source files are
  kept; call
  [`initCohortManifest()`](https://ohdsi.github.io/Picard/reference/initCohortManifest.md)
  then re-register via `$add*()` or `$importAtlasCohorts()`.
- **Complete restart** → `"full"`. Requires `executionSettings` to drop
  OMOP tables. Use with caution.

``` r
# Rebuild derived pipeline only (keeps base cohorts)
resetCohortManifest(manifest = manifest, scope = "derived")

# Wipe manifest DB, keep json/ and sql/ source files
# With archive: creates timestamped backup before deletion
resetCohortManifest(cohortsFolderPath = here::here("inputs/cohorts"),
                    scope = "manifest",
                    archive = TRUE)  # create backup at inputs/cohorts/.archive/

# Full nuclear reset (also drops OMOP cohort tables)
resetCohortManifest(manifest          = manifest,
                    scope             = "full",
                    executionSettings = execSettings,
                    archive           = TRUE)
```

All scopes prompt for confirmation. Pass `confirm = FALSE` to skip in
scripts.

When `archive = TRUE`, the SQLite database is backed up to `.archive/`
with a timestamp before being deleted, allowing recovery if needed.

### Concept set manifest reset

``` r
# Delete only the SQLite DB; json/ files are preserved and auto-re-registered
# on the next loadConceptSetManifest() call
resetConceptSetManifest(scope = "manifest")

# Delete everything
resetConceptSetManifest(scope = "full")

# Create a timestamped backup before deletion
resetConceptSetManifest(scope = "manifest", archive = TRUE)

# Load with auto-sync enabled (default)
csm <- loadConceptSetManifest(autoSync = TRUE, verbose = TRUE)
```

------------------------------------------------------------------------

## Review and Helpers

### Cohort manifest

``` r
# Full tabular view (all active cohorts)
manifest$tabulateManifest()

# Filter to stale cohorts only
manifest$tabulateManifest(filter = "stale")

# Stale cohorts with dependency context
manifest$reviewStaleCohorts()

# Derived cohorts only — with parent labels and rule summaries
manifest$reviewDependentCohorts()

# Mermaid dependency graph
plotCohortGraph(manifest)
```

### Concept set manifest

``` r
csm <- loadConceptSetManifest(autoSync = TRUE, verbose = TRUE)

# Tabular view of all concept sets
csm$tabulateManifest()

# Extract concept set member codes (standard concept IDs)
csm$extractIncludedCodes(
  conceptSetIds = c(1L, 2L, 3L)
)

# Extract source codes mapped from concept set members
# Useful for inspecting ICD-10, NDC, etc. coverage
csm$extractSourceCodes(
  conceptSetIds  = c(1L, 2L),
  sourceVocabs   = c("ICD10CM", "ICD9CM")
)
```

`extractSourceCodes()` requires `executionSettings` to be attached to
the manifest (it queries the vocabulary tables in your CDM):

``` r
csm$setExecutionSettings(execSettings)
csm$extractSourceCodes(conceptSetIds = c(1L, 2L), sourceVocabs = "ICD10CM")
```
