# The Manifest: Architecture, Workflows, and Helpers

This document covers the manifest system in depth — how it works under the hood,
how to handle non-trivial situations mid-cycle, and the review helpers available
for both cohort and concept set manifests.

If you are setting up a study for the first time, start with the
[Loading Inputs: Getting Started](03-loading-inputs.md) guide instead.

---

## 1. Architecture

### SQLite as the source of truth

Each manifest is a SQLite database file stored inside your study's `inputs/` folder:

```
inputs/
├── cohorts/
│   ├── cohortManifest.sqlite    # cohort manifest DB
│   ├── json/                    # CIRCE JSON definitions (ATLAS / Capr)
│   ├── sql/                     # custom hand-written SQL cohorts
│   └── derived/                 # auto-generated SQL for derived cohorts
└── conceptSets/
    ├── conceptSetManifest.sqlite
    └── json/                    # CIRCE JSON concept set definitions
```

The SQLite database is the **single source of truth** for all metadata. The R6
`CohortManifest` and `ConceptSetManifest` objects are in-memory mirrors loaded
from SQLite at startup.

### Key columns in `cohort_manifest`

| Column | Purpose |
|---|---|
| `id` | Auto-assigned integer ID |
| `label` | User-defined display name (unique among active records) |
| `category` | User classification (e.g., "Disease Populations") |
| `cohort_type` | `circe`, `custom`, `union`, `subset`, `complement`, `composite`, `oprior`, `tprior`, `censor` |
| `source_type` | `circe`, `sql`, `derived` |
| `file_path` | Relative path to the SQL/JSON file on disk |
| `hash` | MD5 of the file — used by `generateCohorts()` to skip unchanged cohorts |
| `depends_on` | JSON array of parent cohort IDs (derived cohorts only) |
| `dependency_rule` | JSON object of build parameters (derived cohorts only) |
| `status` | `active`, `stale`, `deleted`, or `purged` |
| `created_at` | Timestamp of registration |

### In-memory R6 object vs SQLite

When you call `loadCohortManifest()`, the package:

1. Opens the SQLite file
2. Reads all `status = 'active'` rows
3. Constructs a `CohortDef` R6 object for each row and holds them in a list

Mutations (add, delete, update) write to **both** SQLite and the in-memory list.
If you edit SQLite externally, call `manifest$reloadFromDb()` to sync.

**Loading with automatic sync:**

```r
# Auto-sync manifest against disk files on load (default: TRUE)
manifest <- loadCohortManifest(autoSync = TRUE, verbose = TRUE)

# Skip auto-sync if you know the manifest is up-to-date
manifest <- loadCohortManifest(autoSync = FALSE)

# Concept set manifest
csm <- loadConceptSetManifest(autoSync = TRUE, verbose = TRUE)
```

### Hash-based skip logic

Every cohort file has an MD5 hash stored in the manifest. At execution time,
`generateCohorts()` compares the current file hash to the stored hash and skips
cohorts whose files have not changed. For derived cohorts, a combined hash of
parent hashes plus the `dependency_rule` is used.

**Stale cohorts** (`status = 'stale'`) bypass the hash check and are always
re-executed. They are reset to `'active'` automatically after successful
execution. See [Section 4](#mid-cycle-changes) for how cohorts become stale.

---

## 2. Adding Cohorts Mid-Cycle

Use the `$add*()` R6 methods to register individual cohorts without a bulk CSV
import. Each method validates uniqueness and writes to SQLite immediately.

### From ATLAS (CIRCE JSON)

```r
atlasConn <- getAtlasConnection()
manifest$setAtlasConnection(atlasConn)

manifest$addAtlasCohort(
  atlasId   = 1234L,
  label     = "Type 2 Diabetes - Incident",
  category  = "Disease Populations"
)
```

### From Capr

```r
library(Capr)

t2dm <- cs(descendants(201826), name = "Type 2 Diabetes")
cohort_def <- cohort(entry = entry(conditionOccurrence(t2dm)))

manifest$addCaprCohort(
  caprCohort = cohort_def,
  label      = "Type 2 Diabetes - Capr",
  category   = "Disease Populations"
)
```

### Custom SQL

Place your `.sql` file in `inputs/cohorts/sql/`, then register it:

```r
manifest$addSqlCohort(
  filePath = here::here("inputs/cohorts/sql/my_cohort.sql"),
  label    = "My Custom Cohort",
  category = "Exposure"
)
```

The SQL must use SqlRender parameters — see `?CohortManifest` for required
parameter names (`@target_cohort_id`, `@target_database_schema`, etc.).

### From a Local CIRCE JSON file

If you have a Circe-compatible `.json` file on disk, register it with:

```r
manifest$addCirceCohort(
  filePath = here::here("inputs/cohorts/json/my_cohort.json"),
  label    = "My Circe Cohort",
  category = "Disease Populations"
)
```

---

## 3. Derived Cohorts

Derived cohorts are built from existing manifest cohorts using builder methods. 
They write rendered SQL to `derived/` and record all dependency metadata directly 
in SQLite — no sidecar files needed.

> **Dependency order is handled automatically.** `generateCohorts()` runs a
> topological sort before execution, ensuring parents always run before
> dependents.

### Union cohort

Combines the observation periods of two or more cohorts into a single cohort.

```r
manifest$buildUnionCohort(
  label     = "T2DM or HF - Any",
  cohortIds = c(1L, 2L),
  category  = "Composite Populations",
  gapDays   = 30L          # merge eras within 30 days
)
```

### Subset cohort (temporal)

Subsets a base cohort to members who also appear in a filter cohort within a
specified time window.

```r
library(picard)

start_window <- createSubsetStartWindow(
  subsetCohortWindowAnchor = "cohort_start_date",
  startDays = -365L,
  endDays   = 0L,
  baseCohortWindowAnchor = "cohort_start_date"
)

manifest$buildSubsetCohortTemporal(
  label          = "T2DM with Prior Metformin",
  baseCohortId   = 1L,
  filterCohortId = 3L,
  category       = "Disease Populations",
  startWindow    = start_window
)
```

### Complement cohort

Members of a population cohort who are **not** in a base cohort.

```r
manifest$buildComplementCohort(
  label              = "No T2DM - General Population",
  excludeCohortIds   = 1L,
  populationCohortId = 5L,
  category           = "Comparators"
)
```

### Custom dependent cohort

Registers a user-supplied `.sql` file as a derived cohort with explicit
dependencies on existing manifest cohorts.

```r
manifest$buildCustomDependentCohort(
  filePath  = here::here("extras/my_custom_logic.sql"),
  label     = "Custom Outcome Definition",
  category  = "Outcomes",
  cohortIds = c(1L, 3L)
)
```

### Composite cohort

Requires membership in a minimum number of component cohorts.

```r
manifest$buildCompositeCohort(
  label      = "T2DM + HF + CKD",
  cohortIds  = c(1L, 2L, 4L),
  category   = "Complex Populations",
  minCohorts = 2L          # must appear in at least 2 of 3
)
```

### Temporal operators: O-Prior-T and T-Prior-O

**O-Prior-T:** Outcome events where a prior target (exposure) event exists

```r
manifest$buildOPriorT(
  label              = "GI Bleed - Prior NSAID",
  outcomeCohortId    = 1L,
  targetCohortId     = 2L,
  category           = "Outcomes",
  mode               = "prior",
  priorTimeWindowDays = 365L,
  subsetLimit        = "Last"
)
```

**T-Prior-O:** Target events with prior outcome

```r
manifest$buildTPriorO(
  label              = "NSAID - Prior GI Bleed",
  targetCohortId     = 2L,
  outcomeCohortId    = 1L,
  category           = "Exposures",
  mode               = "prior",
  priorTimeWindowDays = NULL,
  subsetLimit        = "First"
)
```

### Censor cohort

Truncates cohort end dates to the earliest censoring event (e.g., death).

```r
manifest$buildCensorCohort(
  label          = "NSAID - Censored at Death",
  targetCohortId = 2L,
  censorCohortId = 3L,
  category       = "Exposures"
)
```

### Reviewing derived cohorts

```r
# Tabular summary with parent labels and rule parameters
manifest$reviewDependentCohorts()

# Mermaid dependency graph (renders in RStudio / Quarto / GitHub)
plotCohortGraph(manifest)
```

---

## 4. Mid-Cycle Changes

### Sync manifest against disk files

If SQL or JSON files have been edited outside picard, `$syncManifest()` updates
stored hashes, reports unregistered files on disk, and **cascades a `stale` flag 
to all derived cohorts that depend on any changed file**.

```r
manifest$syncManifest()
```

When a base cohort's SQL/JSON file changes, `syncManifest()` will:

1. Detect the hash difference and update the stored hash
2. Walk the dependency graph and mark every downstream derived cohort as `'stale'`
3. Report each staled cohort by name

Stale derived cohorts still have valid SQL — their parent data has changed but
their build logic has not. They will be **re-executed automatically** the next
time `generateCohorts()` runs (the hash-skip is bypassed for stale cohorts).

### Checking for ATLAS updates (mid-cycle)

After the initial import, check if definitions in ATLAS have been updated. This 
is done in two phases:

**Phase 1: Detection** — Compare remote ATLAS hashes to stored local hashes:

```r
# For cohorts
manifest$checkAtlasCohorts(atlasConnection)

# For concept sets
conceptSetManifest$checkAtlasConceptSets(atlasConnection)
```

This returns a report of which definitions have changed in ATLAS.

**Phase 2: Update** — Download updated definitions and re-write JSON files:

```r
# For cohorts
manifest$updateAtlasCohorts(atlasConnection)

# For concept sets
conceptSetManifest$updateAtlasConceptSets(atlasConnection)
```

When ATLAS definitions are updated:
- JSON files are overwritten with the latest definitions
- Stored hashes are updated to reflect the new versions
- If the cohort is a base cohort, all downstream derived cohorts automatically cascade to `'stale'` status
- Derived cohorts will be **re-executed automatically** on the next `generateCohorts()` run

### Review stale cohorts

```r
# See which derived cohorts are waiting for re-execution
manifest$reviewStaleCohorts()
```

### Rebuilding the derived pipeline

If you need to change a build parameter (e.g. adjust `gapDays` on a union
cohort), the derived cohort SQL needs to be re-rendered:

```r
# 1. Clear all derived cohorts (keeps base cohort registrations)
resetCohortManifest(manifest = manifest, scope = "derived")

# 2. Re-run your build script with corrected parameters
manifest$buildUnionCohort(
  label     = "T2DM or HF - Any",
  cohortIds = c(1L, 2L),
  category  = "Composite Populations",
  gapDays   = 7L   # corrected value
)

# 3. Generate
generateCohorts(executionSettings = execSettings, pipelineVersion = pipelineVersion)
```

### Update label, category, or tags

```r
# Update label
manifest$updateCohortLabel(cohortId = 3L, newLabel = "Metformin Initiators (revised)")

# Update category
manifest$updateCohortCategory(cohortId = 3L, newCategory = "Exposure")

# Update tags
manifest$updateCohortTags(cohortId = 3L, newTags = list(subCategory = "Antidiabetics"))
```

### Delete a cohort or concept set

Marks the item as `deleted` in SQLite with a deletion timestamp (soft delete). The
item is excluded from generation but the record is preserved for audit trail.

```r
# Soft delete cohort (default)
manifest$deleteCohort(id = 3L, confirm = TRUE)

# Delete cohort and also remove from DBMS cohort table (requires executionSettings)
manifest$deleteCohort(id = 3L, dropFromDBMS = TRUE, confirm = TRUE)

# Delete concept set
csm <- loadConceptSetManifest()
csm$deleteConceptSet(id = 5, confirm = TRUE)
```

When `dropFromDBMS = TRUE` for cohorts:
- Deletes the cohort file from disk
- Marks the manifest record as `deleted`
- Removes rows from the DBMS cohort table and checksum table (if it exists)
- Requires `executionSettings` to be attached to the manifest

**Note:** All deletions are soft deletes — records are preserved with a `deleted_at`
timestamp for audit purposes. Deleted items are excluded from all manifest operations.

---

## 5. Reset

Use `resetCohortManifest()` or `resetConceptSetManifest()` when you need to clear data. 
Choose the scope based on what you want to preserve:

### Cohort Reset Scopes

| Scope | SQLite | `derived/` | `json/` + `sql/` | OMOP tables |
|---|---|---|---|---|
| `"derived"` | Updated (derived rows removed) | Deleted | Kept | Not touched |
| `"manifest"` | Deleted | Deleted | Kept | Not touched |
| `"full"` | Deleted | Deleted | Deleted | Dropped |

### Which scope do I need?

- **Rebuilding derived pipeline with new parameters** → `"derived"`. Your base
  cohort registrations and ATLAS imports are preserved.
- **Corrupt or restructured database** → `"manifest"`. Source files are kept;
  call `initCohortManifest()` then re-register via `$add*()` or `$importAtlasCohorts()`.
- **Complete restart** → `"full"`. Requires `executionSettings` to drop OMOP
  tables. Use with caution.

### Cohort Manifest Reset

```r
# Rebuild derived pipeline only (keeps base cohorts)
resetCohortManifest(manifest = manifest, scope = "derived")

# Wipe manifest DB, keep json/ and sql/ source files
# With archive: creates timestamped backup before deletion
resetCohortManifest(cohortsFolderPath = here::here("inputs/cohorts"),
                    scope = "manifest",
                    archive = TRUE)  # creates backup at inputs/cohorts/.archive/

# Full nuclear reset (also drops OMOP cohort tables)
resetCohortManifest(manifest          = manifest,
                    scope             = "full",
                    executionSettings = execSettings,
                    archive           = TRUE)
```

All scopes prompt for confirmation. Pass `confirm = FALSE` to skip in scripts.

When `archive = TRUE`, the SQLite database is backed up to `.archive/` with a
timestamp before being deleted, allowing recovery if needed.

### Concept Set Manifest Reset

```r
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

---

## 6. Review and Helpers

### Cohort Manifest

```r
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

# Validate manifest health
manifest$validateManifest()

# Get manifest status summary
manifest$getManifestStatus()
```

### Concept Set Manifest

```r
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

`extractSourceCodes()` requires `executionSettings` to be attached to the
manifest (it queries the vocabulary tables in your CDM):

```r
csm$setExecutionSettings(execSettings)
csm$extractSourceCodes(conceptSetIds = c(1L, 2L), sourceVocabs = "ICD10CM")
```
