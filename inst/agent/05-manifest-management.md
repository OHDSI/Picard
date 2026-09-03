<!-- AUTO-GENERATED FILE. DO NOT EDIT DIRECTLY. -->
<!-- Source: vignettes/manifest_management.Rmd -->


```{r setup, include = FALSE}
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  eval = FALSE
)
```

This vignette focuses on mid-cycle manifest management: checking for updates,
syncing and reviewing stale records, updating metadata, deleting records, and
resetting manifests safely.

If you are setting up a study for the first time, start with the
[Loading Inputs: Getting Started](loading_inputs.html) vignette instead.

For keyring and credential setup, use [Launching a Picard Study](launching_a_study.html).

---

## Manifest Architecture Primer

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
| `cohort_type` | `circe`, `custom`, `custom_derived`, `union`, `subset`, `complement`, `composite`, `oprior`, `tprior`, `censor` |
| `source_type` | `circe`, `sql`, `derived` |
| `file_path` | Path to the SQL/JSON file, stored relative to the study repository root (e.g. `inputs/cohorts/json/mycohort.json`) |
| `hash` | MD5 of the file **contents** — used by `generateCohorts()` to skip unchanged cohorts |
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
```

### Hash-based skip logic

Every cohort file has an MD5 hash stored in the manifest. At execution time,
`generateCohorts()` compares the current file hash to the stored hash and skips
cohorts whose files have not changed. For derived cohorts, a combined hash of
parent hashes plus the `dependency_rule` is used.

**Stale cohorts** (`status = 'stale'`) bypass the hash check and are always
re-executed. They are reset to `'active'` automatically after successful
execution. See [Section 4](#mid-cycle-changes) for how cohorts become stale.

### File paths and portability

Cohort and concept-set file paths are stored **relative to the study repository
root** — the directory that contains `config.yml`, `README.md`, `analysis/`,
`inputs/` and `dissemination/`. `loadCohortManifest()` (and
`loadConceptSetManifest()`) find that root with `findStudyProjectRoot()` and
resolve every stored path against it, so:

- a manifest loads the same way on any machine and for any collaborator,
  regardless of the working directory they run R from — you do **not** need to
  `setwd()` into the study repo first;
- the `hash` column is always a hash of the file's **contents**, never of its
  path, so moving between path conventions never changes a hash or marks a
  cohort as changed.

Manifests created with older picard versions may hold working-directory-relative
or absolute paths. Those still load — a compatibility resolver tries the
repo-root-relative location, then the manifest-folder-relative location, then the
absolute path. To rewrite them to the current convention in one explicit pass:

```r
# Preview what would change
normalizeCohortManifestPaths(dryRun = TRUE)

# Apply — rewrites file_path only; hashes, status and timestamps are untouched
normalizeCohortManifestPaths()

# Concept-set equivalent
normalizeConceptSetManifestPaths()
```

Rows whose file cannot be found are reported as `broken` and left unchanged.
Ordinary `loadCohortManifest()` / `syncManifest()` calls never rewrite stored
paths — normalization is always something you run deliberately. Note that
`autoSync = FALSE` only turns off file/row reconciliation; it is unrelated to
path resolution and is not a fix for a manifest that will not load.

---

## Manual Cohort Execution from CohortManifest

In most studies, cohort execution is triggered by running the study pipeline
(`main.R`) end-to-end. That is the preferred path for routine runs.

For debugging and validation, you can also execute directly from
`CohortManifest` to verify table setup and check cohort enumeration.

### Typical manual sequence

```{r}
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

- `executeCohortGeneration()` checks required tables before running and can
  create missing tables in interactive sessions.
- `retrieveCohortCounts()` is useful for quick validation that expected cohorts
  were generated and populated.
- For production workflows, keep execution in the standard study pipeline path
  so all tasks run in the intended order.

---


## Mid-Cycle Changes

### Sync manifest against disk files

If SQL or JSON files have been edited outside picard, `$syncManifest()` updates
stored hashes, reports unregistered files on disk, and — crucially — **cascades
a `stale` flag to all derived cohorts that depend on any changed file**.

```{r}
manifest$syncManifest()
```

When a base cohort's SQL/JSON file changes, `syncManifest()` will:

1. Detect the hash difference and update the stored hash
2. Walk the dependency graph and mark every downstream derived cohort as `'stale'`
3. Report each staled cohort by name

`syncManifest()` compares **file contents**, not paths. A row is only reported as
`hash_updated` when the file itself changed — a manifest whose stored paths use
an older convention (see [File paths and portability](#file-paths-and-portability))
syncs cleanly with no spurious updates.

Stale derived cohorts still have valid SQL — their parent data has changed but
their build logic has not. They will be **re-executed automatically** the next
time `generateCohorts()` runs (the hash-skip is bypassed for stale cohorts).

### Checking for ATLAS updates (mid-cycle)

After the initial import, you can periodically check whether definitions in ATLAS
have been updated. This is done in two phases:

**Phase 1: Detection** — Compare remote ATLAS hashes to stored local hashes:

```{r}
# For cohorts
manifest$checkAtlasCohorts(atlasConnection)

# For concept sets
conceptSetManifest$checkAtlasConceptSets(atlasConnection)
```

This returns a report of which definitions have changed in ATLAS.

**Phase 2: Update** — Download updated definitions and re-write JSON files:

```{r}
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

```{r}
# See which derived cohorts are waiting for re-execution
manifest$reviewStaleCohorts()
```

### Rebuilding the derived pipeline

If you need to change a build parameter (e.g. adjust `gapDays` on a union
cohort, or change demographic filters), the derived cohort SQL needs to be
re-rendered — not just re-executed. The workflow is:

```{r}
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

```{r}
# Update label
manifest$updateCohortLabel(cohortId = 3L, newLabel = "Metformin Initiators (revised)")

# Update category
manifest$updateCohortCategory(cohortId = 3L, newCategory = "Exposure")

# Update tags
manifest$updateCohortTags(cohortId = 3L, newTags = list(subCategory = "Antidiabetics"))
```

### Delete a cohort

Marks the cohort as `deleted` in SQLite with a deletion timestamp (soft delete). The
cohort is excluded from generation but the record is preserved for audit trail.

```{r}
# Soft delete (default)
manifest$deleteCohort(id = 3L, confirm = TRUE)

# Delete and also remove from DBMS cohort table (requires executionSettings)
manifest$deleteCohort(id = 3L, dropFromDBMS = TRUE, confirm = TRUE)
```

When `dropFromDBMS = TRUE`:
- Deletes the cohort file from disk
- Marks the manifest record as `deleted`
- Removes rows from the DBMS cohort table and checksum table (if it exists)
- Requires `executionSettings` to be attached to the manifest

**Note:** Deletion is soft (records are preserved). For permanent hard deletion from
SQLite, use administrative database tools directly.

---

## Reset

Use `resetCohortManifest()` when you need to clear cohort data. Choose the
scope based on what you want to preserve:

| Scope | SQLite | `derived/` | `json/` + `sql/` | OMOP tables |
|---|---|---|---|---|
| `"derived"` | Updated (derived rows removed) | Deleted | Kept | Not touched |
| `"manifest"` | Deleted | Deleted | Kept | Not touched |
| `"full"` | Deleted | Deleted | Deleted | Dropped |

### Which scope do I need?

- **Rebuilding derived pipeline with new parameters** → `"derived"`. Your base
  cohort registrations and ATLAS imports are preserved; just re-run the
  `$build*()` calls.
- **Corrupt or restructured database** → `"manifest"`. Source files are kept;
  call `initCohortManifest()` then re-register via `$add*()` or
  `$importAtlasCohorts()`.
- **Complete restart** → `"full"`. Requires `executionSettings` to drop OMOP
  tables. Use with caution.

```{r}
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

All scopes prompt for confirmation. Pass `confirm = FALSE` to skip in scripts.

When `archive = TRUE`, the SQLite database is backed up to `.archive/` with a
timestamp before being deleted, allowing recovery if needed.

### Concept set manifest reset

```{r}
# Delete only the SQLite DB; json/ files are archived (or deleted, if archive = FALSE) —
# re-register them explicitly with $addConceptSetFile() afterward, they are not auto-restored
resetConceptSetManifest(scope = "manifest")

# Delete everything
resetConceptSetManifest(scope = "full")

# Create a timestamped backup before deletion
resetConceptSetManifest(scope = "manifest", archive = TRUE)

# Load with auto-sync enabled (default)
csm <- loadConceptSetManifest(autoSync = TRUE, verbose = TRUE)
```

---

## Review and Helpers

### Cohort manifest

#### Tabulating and Viewing Manifest Data

The manifest provides two methods for viewing cohort metadata:

**Interactive Viewing (Recommended for Exploration)**

```{r}
# Open an interactive RStudio viewer with streamlined metadata
# Shows: id, label, category, tags, file_path
manifest$viewManifest()

# Filter to specific status
manifest$viewManifest(filter = "active")
manifest$viewManifest(filter = "stale")
manifest$viewManifest(filter = "deleted")

# Control tag format in the viewer:
# - nested (default): tags as structured tibble with tag_name/tag_value
# - json: tags as raw JSON string
# - wide: tags expanded into individual columns
manifest$viewManifest(tags_format = "nested")
manifest$viewManifest(tags_format = "wide")  # Excel-like view
```

**Programmatic Tabulation (for pipelines/analysis)**

```{r}
# Full tabular view with all columns (id, label, category, tags, file_path, hash, source_type, cohort_type, status, depends_on, created_at, deleted_at)
tbl <- manifest$tabulateManifest()

# Filter by status
stale_cohorts <- manifest$tabulateManifest(filter = "stale")
deleted_cohorts <- manifest$tabulateManifest(filter = "deleted")
all_cohorts <- manifest$tabulateManifest(filter = "all")

# Control tag format
# Option 1: nested (default) - tags as nested tibble with tag_name/tag_value pairs
tbl_nested <- manifest$tabulateManifest(tags_format = "nested")
# Access nested tags: tbl_nested$tags[[1]] returns a tibble of tag pairs

# Option 2: json (backward compatible) - tags as raw JSON string
tbl_json <- manifest$tabulateManifest(tags_format = "json")
# Useful for APIs or custom tag parsing

# Option 3: wide - tags expanded into individual columns
# Creates one column per unique tag key across the manifest
tbl_wide <- manifest$tabulateManifest(tags_format = "wide")
# Columns like: id, label, category, file_path, hash, status, approval_status, domain, etc.
```

#### Other Cohort Review Methods

```{r}
# Stale cohorts (files changed since last execution, need regeneration)
manifest$reviewStaleCohorts()

# Derived cohorts only — with parent labels and rule summaries
manifest$reviewDependentCohorts()

# Mermaid dependency graph
plotCohortGraph(manifest)
```

### Concept set manifest

```{r}
csm <- loadConceptSetManifest(autoSync = TRUE, verbose = TRUE)

# Interactive view (recommended for exploring)
csm$viewManifest()
csm$viewManifest(tags_format = "wide")

# Programmatic access with different tag formats
tbl_nested <- csm$tabulateManifest(tags_format = "nested")  # default
tbl_json <- csm$tabulateManifest(tags_format = "json")
tbl_wide <- csm$tabulateManifest(tags_format = "wide")

# Extract concept set member codes (standard concept IDs)
csm$extractIncludedCodes(
  outputFolder = here::here("inputs/conceptSets")
)

# Extract source codes mapped from concept set members
# Useful for inspecting ICD-10, NDC, etc. coverage
csm$extractSourceCodes(
  sourceVocabs = c("ICD10CM", "ICD9CM"),
  outputFolder = here::here("inputs/conceptSets")
)
```

`extractSourceCodes()` requires `executionSettings` to be attached to the
manifest (it queries the vocabulary tables in your CDM):

```{r}
csm$setExecutionSettings(execSettings)
csm$extractSourceCodes(conceptSetIds = c(1L, 2L), sourceVocabs = "ICD10CM")
```

---

## Tag Management

Tags are flexible, key-value metadata pairs attached to cohorts. They enable classification,
auditing, workflow automation, and cohort discovery without requiring SQL schema changes.

### What are tags for?

Common use cases:

- **Classification**: `list(status = "approved", owner = "alice", qa_date = "2025-02-15")`
- **Workflow tracking**: `list(type = "primary", route = "capr", validation_needed = "true")`
- **Data quality**: `list(missing_data_pct = "5.2", enumeration_checked = "yes")`
- **Linkage**: `list(parent_study = "COPD_Registry", version = "2.0")`

Tags are stored as JSON in the `tags` column and persist across manifest reloads.

### Single-cohort tag operations

#### Add or overwrite a tag

```{r}
# Add a single tag (non-destructive; existing tags are preserved)
manifest$addCohortTag(cohortId = 5L, tagName = "status", tagValue = "approved")
```

#### Get all tags for a cohort

```{r}
# Retrieve all tags as a named list
manifest$getCohortTags(cohortId = 5L)
# Returns: list(status = "approved", owner = "alice")
```

#### Get a single tag value

```{r}
# Quick retrieval of one tag value (returns NULL if not found)
manifest$getTagValue(cohortId = 5L, tagName = "status")
# Returns: "approved"
```

#### Modify an existing tag value

```{r}
# Change the value of an existing tag
manifest$modifyCohortTagValue(
  cohortId = 5L,
  tagName = "status",
  newValue = "pending_review"
)
# Logs: Modified tag 'status' in cohort 5: approved → pending_review
```

#### Remove a tag

```{r}
# Delete a specific tag without affecting others
manifest$removeCohortTag(cohortId = 5L, tagName = "owner")
# Logs: Removed tag 'owner' from cohort 5
```

#### Merge multiple tags (non-destructive)

```{r}
# Add or overwrite only specified tags; existing tags are preserved
manifest$mergeTagsIntoCohort(
  cohortId = 5L,
  newTags = list(
    qa_status = "checked",
    qa_date = "2025-02-15"
  )
)
# If cohort 5 already has status = "approved", it remains unchanged
```

### Batch tag operations

#### Rename a tag key across cohorts

```{r}
# Rename a tag name (e.g., "owner" → "responsible_party") across all cohorts
# that have it, or a specific subset
manifest$renameTagKey(
  oldTagName = "owner",
  newTagName = "responsible_party"
)

# Rename only for specific cohorts
manifest$renameTagKey(
  oldTagName = "owner",
  newTagName = "responsible_party",
  cohortIds = c(1L, 2L, 5L)
)
# Returns invisible tibble showing id, label, old_value
```

#### Bulk modify a tag value

```{r}
# Find all cohorts where tagName = oldValue and update to newValue
manifest$bulkModifyTagValue(
  tagName = "status",
  oldValue = "pending_review",
  newValue = "approved"
)
# Returns invisible tibble showing which cohorts were modified
```

### Querying cohorts by tags

#### Query by tag name and value (string format)

```{r}
# Find cohorts with a specific tag name and value
manifest$queryCohortsByTag(tagStrings = "status: approved")

# Match any of multiple tags (OR logic)
manifest$queryCohortsByTag(
  tagStrings = c("status: approved", "status: published"),
  match = "any"
)

# Require all tags to match (AND logic)
manifest$queryCohortsByTag(
  tagStrings = c("status: approved", "owner: alice"),
  match = "all"
)
```

Returns a tibble of matching cohorts or `NULL` if none found.

#### Query by tag name only

```{r}
# Find all cohorts that have a specific tag (regardless of value)
manifest$queryCohortsByTagName(tagName = "owner")
```

Returns a tibble of cohorts with that tag or `NULL`.

#### Query by named list (cleaner syntax)

```{r}
# Cleaner syntax for AND-logic multi-tag queries
manifest$queryCohortsWithTagValues(
  tagValueMapping = list(
    status = "approved",
    owner = "alice"
  )
)
# Equivalent to:
# manifest$queryCohortsByTag(
#   tagStrings = c("status: approved", "owner: alice"),
#   match = "all"
# )
```

Returns a tibble or `NULL`.

#### Find cohorts missing a tag

```{r}
# Quality check: which cohorts don't have an owner tag?
unowned <- manifest$queryCohortsMissingTag(tagName = "owner")

# If all cohorts have it, returns NULL with a warning
# Useful for auditing before workflow milestones
```

### Tag discovery and auditing

#### Get all unique tag names

```{r}
# Discover all tag names in use across the manifest (sorted alphabetically)
manifest$listAllUniqueTags()
# Returns: c("owner", "qa_date", "qa_status", "status", "type")
```

#### Get summary of tag values

```{r}
# For a specific tag, see all unique values and which cohorts use them
manifest$getTagValuesSummary(tagName = "status")

# Returns tibble like:
# | value         | count | cohorts       |
# |:--------------|------:|:--------------|
# | approved      |     8 | "1, 2, 5, 9" |
# | pending_review|     3 | "3, 4, 6"     |
# | draft         |     2 | "7, 8"        |
```

Sorted by count (descending). Useful for auditing tag usage patterns.

### Complete workflow example

```{r}
# 1. Load and inspect
manifest <- loadCohortManifest()

# 2. Tag new cohorts during import
manifest$importAtlasCohorts(
  cohortsLoad = read.csv("cohorts_to_import.csv")
)

# 3. Add QA tags after review
approved_cohorts <- manifest$queryCohortsByTag("route: atlas")
for (row in 1:nrow(approved_cohorts)) {
  cid <- approved_cohorts$id[row]
  manifest$mergeTagsIntoCohort(
    cohortId = cid,
    newTags = list(
      qa_status = "reviewed",
      qa_date = Sys.Date(),
      qa_by = "validation_team"
    )
  )
}

# 4. Validate that all cohorts have required tags
missing_qa <- manifest$queryCohortsMissingTag("qa_status")
if (!is.null(missing_qa)) {
  cli::cli_alert_warning("Cohorts missing QA status: {paste(missing_qa$id, collapse = ', ')}")
}

# 5. Generate report of tag coverage
tag_summary <- manifest$getTagValuesSummary("qa_status")
print(tag_summary)

# 6. Rename or bulk-update tags if needed
manifest$bulkModifyTagValue(
  tagName = "qa_status",
  oldValue = "reviewed",
  newValue = "approved"
)
```
