# CohortManifest R6 Class

An R6 class that manages a collection of CohortDef objects and maintains
metadata in a SQLite database.

The CohortManifest class manages multiple cohort definitions and stores
their metadata in a SQLite database located at
inputs/cohorts/cohortManifest.sqlite. Each CohortDef is assigned a
sequential ID based on its position in the manifest.

This is the detection phase of the ATLAS maintenance workflow. Use this
to identify which ATLAS cohorts have changed, then optionally call
`updateAtlasCohorts()` to apply updates. Changes are detected by
comparing expression JSON hashes.

This method updates ATLAS cohorts that have changed in the remote
repository. It:

- Fetches current definitions from ATLAS

- Updates JSON files on disk

- Recomputes and stores hashes

- Updates the manifest database

Use `checkAtlasChanges()` first to identify which cohorts have changed,
then call this method to apply updates.

Requires that executionSettings has been set and includes:

- A database connection (via getConnection()

- workDatabaseSchema for the target schema

- cohortTable with the desired table name

Requires that executionSettings has been set and includes:

- A database connection (via getConnection()

- workDatabaseSchema for the target schema

- cohortTable with the desired table name

- tempEmulationSchema if needed for the database platform

Use `createAllCohortTables()` instead. This alias is kept for backward
compatibility.

Requires that executionSettings has been set and includes:

- A database connection (via getConnection()

- workDatabaseSchema for the target schema

- cohortTable with the desired table name

Requires that `executionSettings` has been set with a valid database
connection, `workDatabaseSchema`, and `cohortTable`.

Execution flow:

1.  Build dependency graph from all CohortDef objects

2.  Validate no circular dependencies (error if found)

3.  Topologically sort cohorts by dependencies (parents before children)

4.  For each cohort in topological order:

    - circe cohorts: check SQL hash (existing logic)

    - dependent cohorts: compute dependency hash from parent hashes +
      rule

5.  Render and execute SQL (circe uses SqlRender parameters, dependent
    uses metadata JSON)

6.  Record checksums and dependency hashes in database

7.  Report results with cohort_type, depends_on, dependency_status
    columns

Requires that executionSettings has been set and includes:

- A database connection (via getConnection()

- cdmDatabaseSchema (where the OMOP CDM data resides)

- workDatabaseSchema (where cohort results are written)

- cohortTable (destination table name)

- tempEmulationSchema if needed for the database platform

## Methods

### Public methods

- [`CohortManifest$new()`](#method-CohortManifest-initialize)

- [`CohortManifest$getManifest()`](#method-CohortManifest-getManifest)

- [`CohortManifest$getManifestHash()`](#method-CohortManifest-getManifestHash)

- [`CohortManifest$reviewDependentCohorts()`](#method-CohortManifest-reviewDependentCohorts)

- [`CohortManifest$tabulateManifest()`](#method-CohortManifest-tabulateManifest)

- [`CohortManifest$viewManifest()`](#method-CohortManifest-viewManifest)

- [`CohortManifest$reviewStaleCohorts()`](#method-CohortManifest-reviewStaleCohorts)

- [`CohortManifest$reloadFromDb()`](#method-CohortManifest-reloadFromDb)

- [`CohortManifest$getDbPath()`](#method-CohortManifest-getDbPath)

- [`CohortManifest$getProjectRoot()`](#method-CohortManifest-getProjectRoot)

- [`CohortManifest$getExecutionSettings()`](#method-CohortManifest-getExecutionSettings)

- [`CohortManifest$setExecutionSettings()`](#method-CohortManifest-setExecutionSettings)

- [`CohortManifest$getAtlasConnection()`](#method-CohortManifest-getAtlasConnection)

- [`CohortManifest$setAtlasConnection()`](#method-CohortManifest-setAtlasConnection)

- [`CohortManifest$addAtlasCohort()`](#method-CohortManifest-addAtlasCohort)

- [`CohortManifest$importAtlasCohorts()`](#method-CohortManifest-importAtlasCohorts)

- [`CohortManifest$addCaprCohort()`](#method-CohortManifest-addCaprCohort)

- [`CohortManifest$updateCaprCohort()`](#method-CohortManifest-updateCaprCohort)

- [`CohortManifest$addSqlCohort()`](#method-CohortManifest-addSqlCohort)

- [`CohortManifest$addDependentCustomCohort()`](#method-CohortManifest-addDependentCustomCohort)

- [`CohortManifest$addCirceCohort()`](#method-CohortManifest-addCirceCohort)

- [`CohortManifest$buildUnionCohort()`](#method-CohortManifest-buildUnionCohort)

- [`CohortManifest$buildSubsetCohortTemporal()`](#method-CohortManifest-buildSubsetCohortTemporal)

- [`CohortManifest$buildComplementCohort()`](#method-CohortManifest-buildComplementCohort)

- [`CohortManifest$buildCompositeCohort()`](#method-CohortManifest-buildCompositeCohort)

- [`CohortManifest$buildDemographicCohort()`](#method-CohortManifest-buildDemographicCohort)

- [`CohortManifest$buildStratifiedCohorts()`](#method-CohortManifest-buildStratifiedCohorts)

- [`CohortManifest$queryCohortsByIds()`](#method-CohortManifest-queryCohortsByIds)

- [`CohortManifest$queryCohortsByTag()`](#method-CohortManifest-queryCohortsByTag)

- [`CohortManifest$queryCohortsByLabel()`](#method-CohortManifest-queryCohortsByLabel)

- [`CohortManifest$queryCohortsByCategory()`](#method-CohortManifest-queryCohortsByCategory)

- [`CohortManifest$queryCohortsByTagName()`](#method-CohortManifest-queryCohortsByTagName)

- [`CohortManifest$queryCohortsMissingTag()`](#method-CohortManifest-queryCohortsMissingTag)

- [`CohortManifest$queryCohortsWithTagValues()`](#method-CohortManifest-queryCohortsWithTagValues)

- [`CohortManifest$getTagValuesSummary()`](#method-CohortManifest-getTagValuesSummary)

- [`CohortManifest$nCohorts()`](#method-CohortManifest-nCohorts)

- [`CohortManifest$getCohortById()`](#method-CohortManifest-getCohortById)

- [`CohortManifest$getCohortsByTag()`](#method-CohortManifest-getCohortsByTag)

- [`CohortManifest$getCohortsByLabel()`](#method-CohortManifest-getCohortsByLabel)

- [`CohortManifest$updateCohortLabel()`](#method-CohortManifest-updateCohortLabel)

- [`CohortManifest$updateCohortCategory()`](#method-CohortManifest-updateCohortCategory)

- [`CohortManifest$updateCohortTags()`](#method-CohortManifest-updateCohortTags)

- [`CohortManifest$removeCohortTag()`](#method-CohortManifest-removeCohortTag)

- [`CohortManifest$modifyCohortTagValue()`](#method-CohortManifest-modifyCohortTagValue)

- [`CohortManifest$addCohortTag()`](#method-CohortManifest-addCohortTag)

- [`CohortManifest$getCohortTags()`](#method-CohortManifest-getCohortTags)

- [`CohortManifest$mergeTagsIntoCohort()`](#method-CohortManifest-mergeTagsIntoCohort)

- [`CohortManifest$listAllUniqueTags()`](#method-CohortManifest-listAllUniqueTags)

- [`CohortManifest$getTagValue()`](#method-CohortManifest-getTagValue)

- [`CohortManifest$renameTagKey()`](#method-CohortManifest-renameTagKey)

- [`CohortManifest$bulkModifyTagValue()`](#method-CohortManifest-bulkModifyTagValue)

- [`CohortManifest$checkAtlasCohorts()`](#method-CohortManifest-checkAtlasCohorts)

- [`CohortManifest$updateAtlasCohorts()`](#method-CohortManifest-updateAtlasCohorts)

- [`CohortManifest$statusReport()`](#method-CohortManifest-statusReport)

- [`CohortManifest$print()`](#method-CohortManifest-print)

- [`CohortManifest$checkCohortTables()`](#method-CohortManifest-checkCohortTables)

- [`CohortManifest$createCohortTable()`](#method-CohortManifest-createCohortTable)

- [`CohortManifest$createAllCohortTables()`](#method-CohortManifest-createAllCohortTables)

- [`CohortManifest$createCohortTables()`](#method-CohortManifest-createCohortTables)

- [`CohortManifest$dropCohortTables()`](#method-CohortManifest-dropCohortTables)

- [`CohortManifest$syncManifest()`](#method-CohortManifest-syncManifest)

- [`CohortManifest$cleanCohortTable()`](#method-CohortManifest-cleanCohortTable)

- [`CohortManifest$executeCohortGeneration()`](#method-CohortManifest-executeCohortGeneration)

- [`CohortManifest$retrieveCohortCounts()`](#method-CohortManifest-retrieveCohortCounts)

- [`CohortManifest$validateManifest()`](#method-CohortManifest-validateManifest)

- [`CohortManifest$getManifestStatus()`](#method-CohortManifest-getManifestStatus)

- [`CohortManifest$deleteCohort()`](#method-CohortManifest-deleteCohort)

- [`CohortManifest$buildOPriorT()`](#method-CohortManifest-buildOPriorT)

- [`CohortManifest$buildTPriorO()`](#method-CohortManifest-buildTPriorO)

- [`CohortManifest$buildCensorCohort()`](#method-CohortManifest-buildCensorCohort)

- [`CohortManifest$cleanupMissing()`](#method-CohortManifest-cleanupMissing)

- [`CohortManifest$clone()`](#method-CohortManifest-clone)

------------------------------------------------------------------------

### `CohortManifest$new()`

Initialize a new CohortManifest

#### Usage

    CohortManifest$new(
      dbPath = "inputs/cohorts/cohortManifest.sqlite",
      projectRoot = NULL
    )

#### Arguments

- `dbPath`:

  Character. Path to the SQLite database. Defaults to
  "inputs/cohorts/cohortManifest.sqlite"

- `projectRoot`:

  Character or NULL. Study repository root against which stored file
  paths are resolved. When `NULL` (default) the root is discovered once
  via
  [`findStudyProjectRoot()`](https://ohdsi.github.io/Picard/reference/findStudyProjectRoot.md)
  from the manifest's directory and cached for the life of the object.
  Supply an explicit path for tests or unusual layouts. Get the manifest
  as a list of CohortDef objects

------------------------------------------------------------------------

### `CohortManifest$getManifest()`

#### Usage

    CohortManifest$getManifest()

#### Returns

List. A list of CohortDef objects in the manifest, indexed by cohort ID.
Compute a deterministic hash of the manifest for task-rerun detection

------------------------------------------------------------------------

### `CohortManifest$getManifestHash()`

Produces a single SHA256 string over everything about the active or
stale cohorts that a task can depend on. Used by the study pipeline (via
[`shouldRerunTask()`](https://ohdsi.github.io/Picard/reference/shouldRerunTask.md)):
when it changes, tasks rerun.

This is distinct from a cohort's *definition hash*
(`CohortDef$getSqlHash()`), which covers only the rendered SQL. Tasks
also select cohorts by label, category, or tag, so a change to that
metadata changes the analysis even when no definition changed.

For each cohort, ordered by id, the hash combines:

- `id`, `label`, `category`, `tags`

- `cohort_type`, `source_type`

- `depends_on` and `dependency_rule` (normalized JSON)

- the definition hash (`CohortDef$getSqlHash()`) of the loaded cohort,
  or the sentinel `"<missing>"` when the cohort file is absent from disk

Because the definition hash is over the rendered SQL, a cosmetic
reformat of a cohort's JSON that renders to identical SQL does not move
the hash. The stored file path is excluded, so path normalization does
not force spurious reruns.

#### Usage

    CohortManifest$getManifestHash()

#### Returns

Character. A SHA256 hash string. An empty manifest hashes to a stable
constant. Review dependent cohorts and their dependency metadata

------------------------------------------------------------------------

### `CohortManifest$reviewDependentCohorts()`

Returns a summary tibble of all active derived cohorts (union, subset,
complement, composite, oprior, tprior, censor, custom_derived) with
parsed dependency information sourced directly from SQLite. Useful for
quickly auditing what each derived cohort depends on and how it was
built.

#### Usage

    CohortManifest$reviewDependentCohorts()

#### Returns

A tibble with columns:

- `id` - Cohort ID

- `label` - Cohort label

- `cohort_type` - One of 'union', 'subset', 'complement', 'composite',
  'oprior', 'tprior', 'censor', 'custom_derived'

- `parent_cohorts` - Human-readable parent list, e.g. "Label A (1),
  Label B (2)"

- `rule_summary` - Compact summary of the dependency rule parameters

- `status` - 'active', or 'stale' when the cohort awaits regeneration

- `created_at` - Timestamp of creation

------------------------------------------------------------------------

### `CohortManifest$tabulateManifest()`

Tabulate the cohort manifest

#### Usage

    CohortManifest$tabulateManifest(
      filter = c("active", "deleted", "stale", "all"),
      tags_format = c("nested", "json", "wide")
    )

#### Arguments

- `filter`:

  Character. One of "active", "deleted", "stale", or "all". Defaults to
  "active".

  `"active"` returns every cohort registered in the study — both
  `'active'` and `'stale'` rows. `'stale'` is a *freshness* marker (the
  definition changed since it was last generated in the database), not a
  lifecycle state: a stale cohort is still a full member of the study
  and is regenerated by the next
  [`generateCohorts()`](https://ohdsi.github.io/Picard/reference/generateCohorts.md)
  run. Use `filter = "stale"` to see just those, or read the `status`
  column of the returned tibble.

- `tags_format`:

  Character. One of "nested", "json", or "wide".

  - "nested" (default): Parse JSON tags into a nested tibble with
    tag_name/tag_value columns

  - "json": Keep tags as raw JSON string

  - "wide": Expand tags into individual columns (one per unique tag key)

#### Returns

Tibble with cohort manifest data. Tags format depends on tags_format
parameter.

------------------------------------------------------------------------

### `CohortManifest$viewManifest()`

View the cohort manifest in RStudio viewer

Opens an interactive RStudio viewer showing key cohort metadata: id,
label, category, tags, status, and file_path. This is a convenience
function for exploring manifest contents without console clutter.

#### Usage

    CohortManifest$viewManifest(
      filter = c("active", "deleted", "stale", "all"),
      tagDelimiter = " | "
    )

#### Arguments

- `filter`:

  Character. One of "active", "deleted", "stale", or "all". Defaults to
  "active", which shows every registered cohort — including ones marked
  `'stale'` (pending regeneration). See `tabulateManifest()` for the
  full filter semantics.

- `tagDelimiter`:

  a character used to seperate tags in the view. Default is \|

#### Returns

Invisibly returns the tibble displayed in the viewer. Review stale
derived cohorts

------------------------------------------------------------------------

### `CohortManifest$reviewStaleCohorts()`

Returns a summary of all cohorts currently marked `'stale'` — meaning
the cohort's own definition, or that of a parent it is built on, has
changed since it was last executed. Stale cohorts are still fully
registered members of the study (they appear in `tabulateManifest()` and
the query methods) and are still valid SQL; they just need to be
re-executed. `executeCohortGeneration()` will run them automatically
regardless of checksum state, and clear the flag.

Use `resetCohortManifest(scope = "derived")` followed by re-running your
build script if you need to change build parameters rather than just
re-execute.

#### Usage

    CohortManifest$reviewStaleCohorts()

#### Returns

A tibble with columns: id, label, cohort_type, category, depends_on,
updated_at. Returns `NULL` invisibly if no stale cohorts exist. Reload
the in-memory manifest from the SQLite database

------------------------------------------------------------------------

### `CohortManifest$reloadFromDb()`

Re-reads all active cohort records from SQLite and rebuilds the
in-memory list of CohortDef objects. Useful after external changes to
the database (e.g., after `resetCohortManifest(scope = "derived")`).

#### Usage

    CohortManifest$reloadFromDb()

#### Returns

Invisible self. Get the manifest path

------------------------------------------------------------------------

### `CohortManifest$getDbPath()`

#### Usage

    CohortManifest$getDbPath()

#### Returns

Character. The path to the SQLite database. Get the study repository
root

------------------------------------------------------------------------

### `CohortManifest$getProjectRoot()`

#### Usage

    CohortManifest$getProjectRoot()

#### Returns

Character. The cached study repository root used to resolve stored file
paths. Get the execution settings

------------------------------------------------------------------------

### `CohortManifest$getExecutionSettings()`

#### Usage

    CohortManifest$getExecutionSettings()

#### Returns

Object. The execution settings object for DBMS cohort generation, or
NULL if not set. Set the execution settings

------------------------------------------------------------------------

### `CohortManifest$setExecutionSettings()`

#### Usage

    CohortManifest$setExecutionSettings(executionSettings)

#### Arguments

- `executionSettings`:

  Object. Execution settings for DBMS cohort generation. Get the stored
  ATLAS connection

------------------------------------------------------------------------

### `CohortManifest$getAtlasConnection()`

#### Usage

    CohortManifest$getAtlasConnection()

#### Returns

The ATLAS connection object, or NULL if not set. Set an ATLAS connection
for use by add/import methods

Stores a connection so it does not need to be passed to
`addAtlasCohort()` or `importAtlasCohorts()` on every call.

------------------------------------------------------------------------

### `CohortManifest$setAtlasConnection()`

#### Usage

    CohortManifest$setAtlasConnection(atlasConnection)

#### Arguments

- `atlasConnection`:

  An ATLAS connection object (from
  [`getAtlasConnection()`](https://ohdsi.github.io/Picard/reference/getAtlasConnection.md)).

#### Returns

Invisible self for method chaining.

------------------------------------------------------------------------

### `CohortManifest$addAtlasCohort()`

Add a single cohort from ATLAS

Fetches a cohort JSON from ATLAS, saves it to `json/`, and registers the
cohort in the manifest.

#### Usage

    CohortManifest$addAtlasCohort(
      atlasId,
      label,
      category,
      tags = list(),
      atlasConnection = NULL,
      stopIfExists = TRUE
    )

#### Arguments

- `atlasId`:

  Integer. The ATLAS cohort definition ID.

- `label`:

  Character. Display name for the cohort.

- `category`:

  Character. Required classification (e.g., 'target', 'outcome').

- `tags`:

  Named list. Optional metadata tags.

- `atlasConnection`:

  An ATLAS connection object (e.g., from
  ROhdsiWebApi::createConnectionDetails) with a method
  `getCohortDefinition(cohortId)` that returns a list with an
  `expression` element. If `NULL`, falls back to the connection stored
  via `$setAtlasConnection()`.

- `stopIfExists`:

  Logical. If TRUE (default), raises an error when an active cohort with
  this label is already registered. If FALSE, fetches the current
  definition from ATLAS and updates the registered cohort in place —
  same ID and file path, hash refreshed, `category`/`tags`/atlasId
  replaced, derived dependents marked 'stale'. An unchanged definition
  leaves the file untouched. Default: TRUE (fail-safe).

#### Returns

Invisible integer. The assigned cohort ID.

------------------------------------------------------------------------

### `CohortManifest$importAtlasCohorts()`

Batch-import cohorts from ATLAS via a cohortsLoad dataframe

Either create a dataframe or read in a csv file with columns `atlasId`,
`label`, `category` (required) plus any additional columns treated as
tag key-value pairs for tags. Calls `addAtlasCohort()` for each row.

The load file is kept in the study repository as the record of which
ATLAS cohorts the study uses. By default, rows whose atlasId is already
registered in the manifest are an error, not an update, so an import
only adds new cohorts. Set `stopIfExists = FALSE` to instead update
those rows in place (delegates to `addAtlasCohort(stopIfExists = FALSE)`
for each), which lets the whole load file be re-imported on every run.
To sync registered cohorts with ATLAS without re-importing, use
`updateAtlasCohorts()`.

#### Usage

    CohortManifest$importAtlasCohorts(
      cohortsLoad,
      atlasConnection = NULL,
      stopIfExists = TRUE
    )

#### Arguments

- `cohortsLoad`:

  a data frame requiring the columns atlasId, label and category used to
  bulk add cohorts to the manifest

- `atlasConnection`:

  An ATLAS connection object with a `getCohortDefinition(cohortId)`
  method. If `NULL`, falls back to the connection stored via
  `$setAtlasConnection()`.

- `stopIfExists`:

  Logical. If TRUE (default), raises an error when any load row's
  atlasId is already registered in the manifest. If FALSE, those rows
  are updated in place instead (same ID/file path, hash refreshed,
  category/tags replaced) via `addAtlasCohort(stopIfExists = FALSE)`.
  Default: TRUE (fail-safe).

#### Returns

Invisible tibble of imported cohorts.

------------------------------------------------------------------------

### `CohortManifest$addCaprCohort()`

Add a Capr cohort

Takes a Capr Cohort object, exports it to JSON in `json/`, and registers
the cohort in the manifest.

#### Usage

    CohortManifest$addCaprCohort(
      caprCohort,
      label,
      category,
      tags = list(),
      stopIfExists = TRUE
    )

#### Arguments

- `caprCohort`:

  A Capr Cohort object (inherits from "Cohort").

- `label`:

  Character. Display name for the cohort.

- `category`:

  Character. Required classification.

- `tags`:

  Named list. Optional metadata tags.

- `stopIfExists`:

  Logical. If TRUE (default), raises an error when an active cohort with
  this label is already registered. If FALSE, updates the existing
  cohort in place via `updateCaprCohort()` — the cohort keeps its ID and
  file path, and `category`/`tags` replace the registered metadata
  (previous tags are dropped if none are supplied). Default: TRUE
  (fail-safe).

#### Returns

Invisible integer. The assigned cohort ID.

------------------------------------------------------------------------

### `CohortManifest$updateCaprCohort()`

Update an existing Capr cohort's JSON definition

Takes a revised Capr Cohort object and upserts it over a cohort already
registered via `addCaprCohort()`: the JSON file recorded in the manifest
is overwritten in place and the manifest hash is refreshed, so the
cohort keeps its ID and file path. Any derived cohorts that depend on it
are marked 'stale'. If the new definition is identical to the registered
one, nothing is changed.

#### Usage

    CohortManifest$updateCaprCohort(caprCohort, label)

#### Arguments

- `caprCohort`:

  A Capr Cohort object (inherits from "Cohort").

- `label`:

  Character. Label of the active cohort to update.

#### Returns

Invisible integer. The cohort ID.

------------------------------------------------------------------------

### `CohortManifest$addSqlCohort()`

Add a custom SQL cohort

Registers an existing SQL file in the manifest. The file must already
exist on disk (typically in `sql/`).

#### Usage

    CohortManifest$addSqlCohort(
      filePath,
      label,
      category,
      tags = list(),
      stopIfExists = TRUE
    )

#### Arguments

- `filePath`:

  Character. Path to the SQL file.

- `label`:

  Character. Display name for the cohort.

- `category`:

  Character. Required classification.

- `tags`:

  Named list. Optional metadata tags.

- `stopIfExists`:

  Logical. If TRUE (default), raises an error when an active cohort with
  this label is already registered, or the file path is registered to
  another cohort. If FALSE, updates the registered cohort in place —
  same ID, file path registration and content hash refreshed,
  `category`/`tags` replace the registered metadata (previous tags are
  dropped if none are supplied), and derived dependents are marked
  'stale' when the definition changed. Default: TRUE (fail-safe).

#### Returns

Invisible integer. The assigned cohort ID.

------------------------------------------------------------------------

### `CohortManifest$addDependentCustomCohort()`

Add a dependent custom SQL cohort

Registers a SQL file in the manifest as a dependency-aware derived
cohort. The source SQL file must preserve the standard Picard cohort
write contract using `@target_database_schema.@target_cohort_table` and
`@target_cohort_id`.

`dependentCohortIdList` and `sqlParameters` values are rendered into the
source SQL immediately (via
[`SqlRender::render()`](https://ohdsi.github.io/SqlRender/reference/render.html))
and the result is written to `inputs/cohorts/derived/<label>.sql` — the
file registered in the manifest — exactly like the built-in derived
cohort types (subset, union, etc.). Only the connection/schema
placeholders (`@target_cohort_id` and friends) are left for
[`generateCohorts()`](https://ohdsi.github.io/Picard/reference/generateCohorts.md)
to fill in at execution time.

#### Usage

    CohortManifest$addDependentCustomCohort(
      filePath,
      label,
      category,
      dependentCohortIdList,
      sqlParameters = list(),
      tags = list(),
      stopIfExists = TRUE
    )

#### Arguments

- `filePath`:

  Character. Path to the source SQL file/template.

- `label`:

  Character. Display name for the cohort.

- `category`:

  Character. Required classification.

- `dependentCohortIdList`:

  Named list. Each name is a SqlRender parameter to render into the SQL
  file. Each value is, preferably, a manifest entry — a
  data.frame/tibble with an `id` column, as returned by query methods
  like `queryCohortsByLabel()` (a single row bakes in one ID; a
  multi-row table bakes in a comma-separated vector, for `IN (@param)`
  clauses) — or, for backward compatibility, a raw integer cohort ID (or
  integer vector). These IDs also become this cohort's `depends_on`
  parents for staleness tracking. When entries carry a `label` column,
  it's included (purely for QC) in a generated comment header at the top
  of the derived SQL file. Example:
  `list(inc_cohort_id = ckdEntry, exc_cohort_id = t2dEntry)`.

- `sqlParameters`:

  Named list. Optional additional SqlRender parameters to render into
  the SQL file (any type — thresholds, dates, strings, etc.), not
  treated as cohort dependencies. Example:
  `list(min_days = 30L, index_year = 2020L)`.

- `tags`:

  Named list. Optional metadata tags.

- `stopIfExists`:

  Logical. If TRUE (default), raises an error when an active or stale
  cohort with this label is already registered. If FALSE, updates the
  registered cohort in place (same ID): the dependent cohort
  IDs/sqlParameters are re-rendered into the generated file, and — only
  if that actually changes the definition — the cohort is marked 'stale'
  for regeneration along with its own dependents. Re-running with
  unchanged inputs leaves the cohort exactly as it was. Default: TRUE
  (fail-safe).

#### Returns

Invisible integer. The assigned cohort ID.

------------------------------------------------------------------------

### `CohortManifest$addCirceCohort()`

Add a Circe JSON cohort from disk

Registers an existing Circe-compatible JSON file in the manifest. The
file must already exist on disk (typically in `json/`). Validates that
the JSON is valid Circe format using CirceR.

#### Usage

    CohortManifest$addCirceCohort(filePath, label, category, tags = list())

#### Arguments

- `filePath`:

  Character. Path to the Circe JSON file.

- `label`:

  Character. Display name for the cohort.

- `category`:

  Character. Required classification.

- `tags`:

  Named list. Optional metadata tags.

#### Returns

Invisible integer. The assigned cohort ID.

------------------------------------------------------------------------

### `CohortManifest$buildUnionCohort()`

Build a union cohort from existing cohorts

Creates a derived cohort that is the union of specified parent cohorts.
Delegates SQL generation to the internal builder function.

Input route policy:

- Preferred: provide `cohortEntries` (manifest query rows with `id`)

- Backward compatible: provide `cohortIds`

- Exactly one route must be provided; passing both or neither is an
  error.

#### Usage

    CohortManifest$buildUnionCohort(
      label,
      category,
      tags = list(),
      cohortIds = NULL,
      cohortEntries = NULL,
      gapDays = 0L,
      eraPadDays = 0L,
      minEraDays = 0L,
      minCohorts = 1L,
      washoutDays = 0L,
      firstEraOnly = FALSE,
      stopIfExists = TRUE
    )

#### Arguments

- `label`:

  Character. Display name for the derived cohort.

- `category`:

  Character. Required classification.

- `tags`:

  Named list. Optional metadata tags.

- `cohortIds`:

  Numeric vector (minimum 2). Legacy ID route to union cohorts.
  Supported for backward compatibility and emits a migration warning
  unless `options(picard.suppressIdRouteWarning = TRUE)` is set.

- `cohortEntries`:

  Data frame/tibble with an `id` column (minimum 2 rows). Preferred
  route using manifest query results.

- `gapDays`:

  Integer. Bridge eras separated by up to this many days. Default: 0
  (only overlapping periods collapse).

- `eraPadDays`:

  Integer. Expand each source period by this many days on each end
  before collapsing. Applied to individual periods, not the collapsed
  result. Default: 0.

- `minEraDays`:

  Integer. Drop collapsed eras shorter than this many days. Default: 0
  (keep all eras).

- `minCohorts`:

  Integer. Only include subjects appearing in at least this many
  distinct source cohorts. Default: 1 (any subject from any cohort).

- `washoutDays`:

  Integer. Require a clean period of at least this many days before a
  new era can open. Subjects must have no source cohort membership for
  this period. Default: 0.

- `firstEraOnly`:

  Logical. Return only the first collapsed era per subject. Default:
  FALSE.

- `stopIfExists`:

  Logical. If TRUE (default), raises an error when an active or stale
  cohort with this label is already registered. If FALSE, updates the
  registered derived cohort in place (same ID and file path): the SQL is
  re-rendered, parents and build parameters are replaced, the cohort is
  marked 'stale' for regeneration (and its own dependents with it) only
  when the definition actually changed — re-running with unchanged
  inputs is a no-op. Default: TRUE (fail-safe).

#### Returns

Invisible integer. The assigned cohort ID.

------------------------------------------------------------------------

### `CohortManifest$buildSubsetCohortTemporal()`

Build a subset cohort with temporal criteria

Creates a derived cohort that subsets a base cohort using temporal
relationship to a filter cohort.

Input route policy:

- Preferred: provide `baseCohortEntry`/`filterCohortEntry`

- Backward compatible: provide `baseCohortId`/`filterCohortId`

- Exactly one route per role must be provided; both/neither is an error.

#### Usage

    CohortManifest$buildSubsetCohortTemporal(
      label,
      category,
      tags = list(),
      baseCohortId = NULL,
      filterCohortId = NULL,
      baseCohortEntry = NULL,
      filterCohortEntry = NULL,
      startWindow,
      endWindow = NULL,
      endDateType = "base",
      subsetLimit = "First",
      stopIfExists = TRUE
    )

#### Arguments

- `label`:

  Character. Display name.

- `category`:

  Character. Required classification.

- `tags`:

  Named list. Optional metadata tags.

- `baseCohortId`:

  Integer. Legacy ID route for the base cohort.

- `filterCohortId`:

  Integer. Legacy ID route for the filter cohort.

- `baseCohortEntry`:

  Data frame/tibble with one row and an `id` column. Preferred route
  using manifest query results for the base cohort.

- `filterCohortEntry`:

  Data frame/tibble with one row and an `id` column. Preferred route
  using manifest query results for the filter cohort.

- `startWindow`:

  SubsetWindowOperator object. Defines the temporal window for the
  subset cohort start date relative to the filter cohort event.

- `endWindow`:

  SubsetWindowOperator object (optional, NULL allowed). Defines the
  temporal window for the subset cohort end date relative to the filter
  cohort event. If NULL, the filter cohort end date is not used.

- `endDateType`:

  Character. Whether to use the base cohort end date ('base') or filter
  cohort end date ('filter') as the cohort end date in the output subset
  cohort. Default: 'base'.

- `subsetLimit`:

  Character. One of 'First', 'Last', or 'All'. Specifies which
  qualifying filter cohort event(s) to retain per subject. 'First' keeps
  the earliest event, 'Last' keeps the most recent event, 'All' keeps
  all qualifying events. Default: 'First'.

- `stopIfExists`:

  Logical. If TRUE (default), raises an error when an active or stale
  cohort with this label is already registered. If FALSE, updates the
  registered derived cohort in place (same ID and file path): the SQL is
  re-rendered, parents and build parameters are replaced, the cohort is
  marked 'stale' for regeneration (and its own dependents with it) only
  when the definition actually changed — re-running with unchanged
  inputs is a no-op. Default: TRUE (fail-safe).

#### Returns

Invisible integer. The assigned cohort ID.

------------------------------------------------------------------------

### `CohortManifest$buildComplementCohort()`

Build a complement cohort

Creates a derived cohort containing all subjects from the population
cohort who do NOT appear in any (or all) of the exclude cohorts.

Input route policy:

- Preferred: provide `populationCohortEntry`/`excludeCohortEntries`

- Backward compatible: provide `populationCohortId`/`excludeCohortIds`

- Exactly one route per role must be provided; both/neither is an error.

#### Usage

    CohortManifest$buildComplementCohort(
      label,
      category,
      tags = list(),
      populationCohortId = NULL,
      excludeCohortIds = NULL,
      populationCohortEntry = NULL,
      excludeCohortEntries = NULL,
      complementType = "exclude_any",
      stopIfExists = TRUE
    )

#### Arguments

- `label`:

  Character. Display name.

- `category`:

  Character. Required classification.

- `tags`:

  Named list. Optional metadata tags.

- `populationCohortId`:

  Integer. Legacy ID route for the population (base) cohort.

- `excludeCohortIds`:

  Integer vector (min length 1). Legacy ID route for cohorts whose
  subjects should be excluded from the population.

- `populationCohortEntry`:

  Data frame/tibble with one row and an `id` column. Preferred route
  using manifest query results for the population cohort.

- `excludeCohortEntries`:

  Data frame/tibble with an `id` column (minimum 1 row). Preferred route
  using manifest query results for exclusion cohorts.

- `complementType`:

  Character. One of `"exclude_any"` (default) or `"exclude_all"`.
  `"exclude_any"` removes subjects present in ANY exclude cohort;
  `"exclude_all"` removes subjects only if they appear in ALL exclude
  cohorts.

- `stopIfExists`:

  Logical. If TRUE (default), raises an error when an active or stale
  cohort with this label is already registered. If FALSE, updates the
  registered derived cohort in place (same ID and file path): the SQL is
  re-rendered, parents and build parameters are replaced, the cohort is
  marked 'stale' for regeneration (and its own dependents with it) only
  when the definition actually changed — re-running with unchanged
  inputs is a no-op. Default: TRUE (fail-safe).

#### Returns

Invisible integer. The assigned cohort ID.

------------------------------------------------------------------------

### `CohortManifest$buildCompositeCohort()`

Build a composite cohort

Creates a derived cohort of subjects who belong to at least
`minEventCount` of the criteria cohorts. Set `minEventCount` to the
number of criteria cohorts for an intersection (subjects must be in
every criteria cohort); lower values relax the requirement.

Input route policy:

- Preferred: provide `criteriaCohortEntries`

- Backward compatible: provide `criteriaCohortIds`

- Exactly one route must be provided; passing both or neither is an
  error.

#### Usage

    CohortManifest$buildCompositeCohort(
      label,
      category,
      tags = list(),
      criteriaCohortIds = NULL,
      criteriaCohortEntries = NULL,
      eventSelection = "First",
      minEventCount = 1L,
      stopIfExists = TRUE
    )

#### Arguments

- `label`:

  Character. Display name.

- `category`:

  Character. Required classification.

- `tags`:

  Named list. Optional metadata tags.

- `criteriaCohortIds`:

  Integer vector. Legacy ID route for cohorts to include in the
  composite (e.g., c(1, 2, 3) for Type 1 diabetes, Type 2 diabetes, and
  secondary diabetes).

- `criteriaCohortEntries`:

  Data frame/tibble with an `id` column (minimum 2 rows). Preferred
  route using manifest query results.

- `eventSelection`:

  Character. One of 'First', 'Last', or 'All'. Specifies which event(s)
  to retain as the cohort_start_date and cohort_end_date in the output:

  - 'First': Keep the earliest event (earliest index date)

  - 'Last': Keep the most recent event

  - 'All': Keep all qualifying events per subject (may result in
    multiple rows per subject) Default: 'First'.

- `minEventCount`:

  Integer. Minimum number of distinct criteria cohorts a subject must
  belong to in order to qualify for the composite. Must be between 1 and
  the number of criteria cohorts. Default: 1 (subject in any criteria
  cohort qualifies). A warning is raised when it is not supplied; for an
  intersection, set it to the number of criteria cohorts.

- `stopIfExists`:

  Logical. If TRUE (default), raises an error when an active or stale
  cohort with this label is already registered. If FALSE, updates the
  registered derived cohort in place (same ID and file path): the SQL is
  re-rendered, parents and build parameters are replaced, the cohort is
  marked 'stale' for regeneration (and its own dependents with it) only
  when the definition actually changed — re-running with unchanged
  inputs is a no-op. Default: TRUE (fail-safe).

#### Returns

Invisible integer. The assigned cohort ID.

------------------------------------------------------------------------

### `CohortManifest$buildDemographicCohort()`

Build a demographic subset cohort

Creates a derived cohort that subsets a base cohort by filtering on
person-level demographic attributes (age, gender, race, ethnicity).

Input route policy:

- Preferred: provide `baseCohortEntry`

- Backward compatible: provide `baseCohortId`

- Exactly one route must be provided; passing both or neither is an
  error.

#### Usage

    CohortManifest$buildDemographicCohort(
      label,
      baseCohortId = NULL,
      baseCohortEntry = NULL,
      category,
      minAge = NULL,
      maxAge = NULL,
      genderConceptIds = NULL,
      raceConceptIds = NULL,
      ethnicityConceptIds = NULL,
      tags = list(),
      stopIfExists = TRUE
    )

#### Arguments

- `label`:

  Character. Display name (e.g., "CKD - Males 40-75").

- `baseCohortId`:

  Integer. Legacy ID route for the base cohort.

- `baseCohortEntry`:

  Data frame/tibble with one row and an `id` column. Preferred route
  using manifest query results.

- `category`:

  Character. Required classification.

- `minAge`:

  Integer or NULL. Minimum age at cohort start. Default: NULL (no
  minimum).

- `maxAge`:

  Integer or NULL. Maximum age at cohort start. Default: NULL (no
  maximum).

- `genderConceptIds`:

  Integer vector or NULL. Gender concept IDs to include. Common values:
  8507 = Male, 8532 = Female. Default: NULL (all genders).

- `raceConceptIds`:

  Integer vector or NULL. Race concept IDs to include. Default: NULL.

- `ethnicityConceptIds`:

  Integer vector or NULL. Ethnicity concept IDs to include. Default:
  NULL.

- `tags`:

  Named list. Optional metadata tags.

- `stopIfExists`:

  Logical. If TRUE (default), raises an error when an active or stale
  cohort with this label is already registered. If FALSE, updates the
  registered derived cohort in place (same ID and file path): the SQL is
  re-rendered, parents and build parameters are replaced, the cohort is
  marked 'stale' for regeneration (and its own dependents with it) only
  when the definition actually changed — re-running with unchanged
  inputs is a no-op. Default: TRUE (fail-safe).

#### Returns

Invisible integer. The assigned cohort ID.

------------------------------------------------------------------------

### `CohortManifest$buildStratifiedCohorts()`

Split a base cohort into stratified sub-cohorts

Splits a single base cohort into N named stratum cohorts plus an
automatic **Unclassified** cohort containing subjects that match none of
the named strata. Each stratum is registered as a separate manifest
entry with `cohort_type = "subset"`.

Input route policy:

- Preferred: provide `baseCohortEntry`

- Backward compatible: provide `baseCohortId`

- Exactly one route must be provided; passing both or neither is an
  error.

#### Usage

    CohortManifest$buildStratifiedCohorts(
      baseCohortId = NULL,
      baseCohortEntry = NULL,
      strata,
      labelPrefix = NULL,
      category = "derived",
      tags = list(),
      stopIfExists = TRUE
    )

#### Arguments

- `baseCohortId`:

  Integer. Legacy ID route for the cohort definition ID to split.

- `baseCohortEntry`:

  Data frame/tibble with one row and an `id` column. Preferred route
  using manifest query results.

- `strata`:

  Named list. Each element is either a named list of demographic filters
  (keys: `genderConceptIds`, `raceConceptIds`, `ethnicityConceptIds`,
  `minAge`, `maxAge`) or a character string SQL WHERE condition
  referencing `bc` (cohort table) and `p` (person table). Names become
  cohort labels.

- `labelPrefix`:

  Character or NULL. If provided, prepended to each stratum name with a
  `" - "` separator.

- `category`:

  Character. Category applied to every stratum cohort. Default:
  `"derived"`.

- `tags`:

  Named list. Optional metadata tags applied to every stratum cohort.

- `stopIfExists`:

  Logical. If TRUE (default), errors when any stratum label is already
  registered. If FALSE, updates existing derived strata in place and
  creates any new strata.

#### Returns

Invisibly returns a named list of assigned cohort IDs, keyed by cohort
label. Query cohorts by IDs

------------------------------------------------------------------------

### `CohortManifest$queryCohortsByIds()`

#### Usage

    CohortManifest$queryCohortsByIds(
      ids,
      tags_format = c("nested", "json", "wide")
    )

#### Arguments

- `ids`:

  Integer vector. One or more cohort IDs.

- `tags_format`:

  Character. One of "nested", "json", or "wide".

  - "nested" (default): Tags as nested tibble with tag_name/tag_value
    columns

  - "json": Tags as raw JSON string

  - "wide": Tags expanded into individual columns

#### Returns

Tibble with matching cohorts. Tag columns depend on `tags_format`.
Returns NULL if no matches are found. Query cohorts by tag

------------------------------------------------------------------------

### `CohortManifest$queryCohortsByTag()`

#### Usage

    CohortManifest$queryCohortsByTag(
      tagStrings,
      match = c("any", "all"),
      tags_format = c("nested", "json", "wide")
    )

#### Arguments

- `tagStrings`:

  Character vector. One or more tags in the format "name: value" (e.g.,
  "category: primary"). When multiple tags are supplied, the `match`
  argument controls whether a cohort must satisfy any or all of them.

- `match`:

  Character. "any" (default) returns cohorts matching at least one tag;
  "all" returns only cohorts matching every tag.

- `tags_format`:

  Character. One of "nested", "json", or "wide".

  - "nested" (default): Tags as nested tibble with tag_name/tag_value
    columns

  - "json": Tags as raw JSON string

  - "wide": Tags expanded into individual columns

#### Returns

Tibble with matching cohorts. Tag columns depend on `tags_format`.
Returns NULL if no matches are found. Query cohorts by label

------------------------------------------------------------------------

### `CohortManifest$queryCohortsByLabel()`

#### Usage

    CohortManifest$queryCohortsByLabel(
      labels,
      matchType = c("exact", "pattern"),
      tags_format = c("nested", "json", "wide")
    )

#### Arguments

- `labels`:

  Character vector. One or more labels to search for. A cohort is
  included when it matches at least one of the supplied labels (OR
  logic).

- `matchType`:

  Character. Either "exact" for exact match or "pattern" for pattern
  matching. Defaults to "exact".

- `tags_format`:

  Character. One of "nested", "json", or "wide".

  - "nested" (default): Tags as nested tibble with tag_name/tag_value
    columns

  - "json": Tags as raw JSON string

  - "wide": Tags expanded into individual columns

#### Returns

Tibble with matching cohorts. Tag columns depend on `tags_format`.
Returns NULL if no matches are found. Query cohorts by tag name

------------------------------------------------------------------------

### `CohortManifest$queryCohortsByCategory()`

#### Usage

    CohortManifest$queryCohortsByCategory(
      category,
      matchType = c("exact", "pattern"),
      tags_format = c("nested", "json", "wide")
    )

#### Arguments

- `category`:

  Character vector. One or more category to search for. A cohort is
  included when it matches at least one of the supplied category (OR
  logic).

- `matchType`:

  Character. Either "exact" for exact match or "pattern" for pattern
  matching. Defaults to "exact".

- `tags_format`:

  Character. One of "nested", "json", or "wide".

  - "nested" (default): Tags as nested tibble with tag_name/tag_value
    columns

  - "json": Tags as raw JSON string

  - "wide": Tags expanded into individual columns

#### Returns

Tibble with matching cohorts. Tag columns depend on `tags_format`.
Returns NULL if no matches are found. Query cohorts by category

------------------------------------------------------------------------

### `CohortManifest$queryCohortsByTagName()`

#### Usage

    CohortManifest$queryCohortsByTagName(
      tagName,
      tags_format = c("nested", "json", "wide")
    )

#### Arguments

- `tagName`:

  Character vector. The name of tags to query.

- `tags_format`:

  Character. One of "nested", "json", or "wide".

  - "nested" (default): Tags as nested tibble with tag_name/tag_value
    columns

  - "json": Tags as raw JSON string

  - "wide": Tags expanded into individual columns

#### Returns

Tibble with matching cohorts. Tag columns depend on `tags_format`.
Returns NULL if no matches are found.

------------------------------------------------------------------------

### `CohortManifest$queryCohortsMissingTag()`

Query cohorts missing a specific tag

#### Usage

    CohortManifest$queryCohortsMissingTag(
      tagName,
      tags_format = c("nested", "json", "wide")
    )

#### Arguments

- `tagName`:

  Character. The name of the tag to check for absence.

- `tags_format`:

  Character. One of "nested", "json", or "wide".

  - "nested" (default): Tags as nested tibble with tag_name/tag_value
    columns

  - "json": Tags as raw JSON string

  - "wide": Tags expanded into individual columns

#### Returns

Tibble with matching cohorts. Tag columns depend on `tags_format`.
Returns NULL if all cohorts have the tag.

------------------------------------------------------------------------

### `CohortManifest$queryCohortsWithTagValues()`

Query cohorts by tag value mapping

#### Usage

    CohortManifest$queryCohortsWithTagValues(
      tagValueMapping,
      tags_format = c("nested", "json", "wide")
    )

#### Arguments

- `tagValueMapping`:

  Named list. Keys are tag names, values are tag values to match.
  Example: `list(status = "approved", type = "primary")` requires both
  conditions (AND logic).

- `tags_format`:

  Character. One of "nested", "json", or "wide".

  - "nested" (default): Tags as nested tibble with tag_name/tag_value
    columns

  - "json": Tags as raw JSON string

  - "wide": Tags expanded into individual columns

#### Returns

Tibble with matching cohorts. Tag columns depend on `tags_format`.
Returns NULL if no cohorts match all tag conditions.

------------------------------------------------------------------------

### `CohortManifest$getTagValuesSummary()`

Get a summary of all unique values for a specific tag

#### Usage

    CohortManifest$getTagValuesSummary(tagName)

#### Arguments

- `tagName`:

  Character. The name of the tag to summarize.

#### Returns

Tibble with columns: value, count, cohorts (comma-separated IDs).
Returns NULL if no cohorts have the tag.

------------------------------------------------------------------------

### `CohortManifest$nCohorts()`

Get number of cohorts in manifest

#### Usage

    CohortManifest$nCohorts()

#### Returns

Integer. The number of cohorts. Get a specific cohort by ID

------------------------------------------------------------------------

### `CohortManifest$getCohortById()`

#### Usage

    CohortManifest$getCohortById(id)

#### Arguments

- `id`:

  Integer. The cohort ID.

#### Returns

CohortDef. The CohortDef object with matching ID, or NULL if not found.
Get cohorts by tag

------------------------------------------------------------------------

### `CohortManifest$getCohortsByTag()`

#### Usage

    CohortManifest$getCohortsByTag(tagStrings, match = c("any", "all"))

#### Arguments

- `tagStrings`:

  Character vector. One or more tags in the format "name: value" (e.g.,
  "category: primary"). When multiple tags are supplied, the `match`
  argument controls whether a cohort must satisfy any or all of them.

- `match`:

  Character. "any" (default) returns cohorts matching at least one tag;
  "all" returns only cohorts matching every tag.

#### Returns

List. A list of CohortDef objects with matching tags, or NULL if none
found. Get cohorts by label

------------------------------------------------------------------------

### `CohortManifest$getCohortsByLabel()`

#### Usage

    CohortManifest$getCohortsByLabel(labels, matchType = c("exact", "pattern"))

#### Arguments

- `labels`:

  Character vector. One or more labels to search for. A cohort is
  included when it matches at least one of the supplied labels (OR
  logic).

- `matchType`:

  Character. Either "exact" for exact match or "pattern" for pattern
  matching. Defaults to "exact".

#### Returns

List. A list of CohortDef objects with matching labels, or NULL if none
found.

------------------------------------------------------------------------

### `CohortManifest$updateCohortLabel()`

Update a cohort label

#### Usage

    CohortManifest$updateCohortLabel(cohortId, newLabel)

#### Arguments

- `cohortId`:

  Integer. The cohort ID to update.

- `newLabel`:

  Character. The new label for the cohort.

#### Returns

Invisible NULL.

------------------------------------------------------------------------

### `CohortManifest$updateCohortCategory()`

Update a cohort category

#### Usage

    CohortManifest$updateCohortCategory(cohortId, newCategory)

#### Arguments

- `cohortId`:

  Integer. The cohort ID to update.

- `newCategory`:

  Character. The new category for the cohort.

#### Returns

Invisible NULL.

------------------------------------------------------------------------

### `CohortManifest$updateCohortTags()`

Update cohort tags

#### Usage

    CohortManifest$updateCohortTags(cohortId, newTags)

#### Arguments

- `cohortId`:

  Integer. The cohort ID to update.

- `newTags`:

  Named list. The new tags for the cohort.

#### Returns

Invisible NULL.

------------------------------------------------------------------------

### `CohortManifest$removeCohortTag()`

Remove a specific tag from a cohort

#### Usage

    CohortManifest$removeCohortTag(cohortId, tagName)

#### Arguments

- `cohortId`:

  Integer. The cohort ID to update.

- `tagName`:

  Character. The name of the tag to remove.

#### Returns

Invisible NULL. Emits success message if tag was removed, warning if tag
was not found.

------------------------------------------------------------------------

### `CohortManifest$modifyCohortTagValue()`

Modify the value of an existing tag

#### Usage

    CohortManifest$modifyCohortTagValue(cohortId, tagName, newValue)

#### Arguments

- `cohortId`:

  Integer. The cohort ID to update.

- `tagName`:

  Character. The name of the tag to modify.

- `newValue`:

  Character. The new value for the tag.

#### Returns

Invisible NULL. Emits success message if tag was modified, error if tag
does not exist.

------------------------------------------------------------------------

### `CohortManifest$addCohortTag()`

Add a single tag to a cohort (non-destructive)

#### Usage

    CohortManifest$addCohortTag(cohortId, tagName, tagValue)

#### Arguments

- `cohortId`:

  Integer. The cohort ID to update.

- `tagName`:

  Character. The name of the tag to add.

- `tagValue`:

  Character. The value for the new tag.

#### Returns

Invisible NULL. Emits success message if tag was added.

------------------------------------------------------------------------

### `CohortManifest$getCohortTags()`

Get all tags for a specific cohort

#### Usage

    CohortManifest$getCohortTags(cohortId)

#### Arguments

- `cohortId`:

  Integer. The cohort ID to query.

#### Returns

Named list of tags, or NULL if cohort not found.

------------------------------------------------------------------------

### `CohortManifest$mergeTagsIntoCohort()`

Merge multiple tags into a cohort (non-destructive, additive)

#### Usage

    CohortManifest$mergeTagsIntoCohort(cohortId, newTags)

#### Arguments

- `cohortId`:

  Integer. The cohort ID to update.

- `newTags`:

  Named list. The tags to add/merge (overwrites existing keys with same
  name).

#### Returns

Invisible NULL. Emits success message.

------------------------------------------------------------------------

### `CohortManifest$listAllUniqueTags()`

Get all unique tag names used across the manifest

#### Usage

    CohortManifest$listAllUniqueTags()

#### Returns

Character vector of unique tag names, sorted alphabetically.

------------------------------------------------------------------------

### `CohortManifest$getTagValue()`

Get value of a single tag for a cohort

#### Usage

    CohortManifest$getTagValue(cohortId, tagName)

#### Arguments

- `cohortId`:

  Integer. The cohort ID to query.

- `tagName`:

  Character. The name of the tag to retrieve.

#### Returns

Character. The tag value, or NULL if tag or cohort not found.

------------------------------------------------------------------------

### `CohortManifest$renameTagKey()`

Rename a tag key across specified cohorts (or all cohorts)

#### Usage

    CohortManifest$renameTagKey(oldTagName, newTagName, cohortIds = NULL)

#### Arguments

- `oldTagName`:

  Character. The current tag name to rename.

- `newTagName`:

  Character. The new tag name.

- `cohortIds`:

  Integer vector or NULL. If NULL, renames across all cohorts that have
  this tag.

#### Returns

Invisible tibble with id, label, old_value showing what was renamed.

------------------------------------------------------------------------

### `CohortManifest$bulkModifyTagValue()`

Bulk modify a tag value across cohorts matching an old value

#### Usage

    CohortManifest$bulkModifyTagValue(tagName, oldValue, newValue)

#### Arguments

- `tagName`:

  Character. The name of the tag to modify.

- `oldValue`:

  Character. The current value to match and replace.

- `newValue`:

  Character. The new value to set.

#### Returns

Invisible tibble with id, label showing what was modified.

------------------------------------------------------------------------

### `CohortManifest$checkAtlasCohorts()`

Auto-detect changes to ATLAS cohorts in remote repository

Queries the manifest for all active ATLAS cohorts (identified by
`atlasId` in tags), fetches their current definitions from ATLAS,
computes hashes, and compares against the stored local hash. Provides a
read-only summary of which cohorts have changed in ATLAS since import.
No modifications are made.

#### Usage

    CohortManifest$checkAtlasCohorts(atlasConnection = NULL, stopOnError = TRUE)

#### Arguments

- `atlasConnection`:

  An ATLAS connection object with a method
  `getCohortDefinition(cohortId)` that returns a list with an
  `expression` element. If `NULL` (default), uses the connection stored
  via `$setAtlasConnection()`. If no connection is available, raises an
  error.

- `stopOnError`:

  Logical. If TRUE (default), a failed ATLAS fetch aborts the sync. If
  FALSE, the cohort is skipped with a warning and the remaining cohorts
  are still synced.

#### Returns

Invisible tibble with columns:

- `id` - Cohort ID in manifest

- `label` - Cohort label

- `atlasId` - ATLAS cohort definition ID

- `hasChanged` - Logical; TRUE if remote hash differs from local

- `localHash` - Hash of stored JSON

- `remoteHash` - Hash of current ATLAS JSON

------------------------------------------------------------------------

### `CohortManifest$updateAtlasCohorts()`

Update ATLAS cohorts with remote definitions

Fetches current definitions from ATLAS for specified cohorts and updates
the stored JSON files and manifest entries. This is the modification
phase that applies changes detected by checkAtlasChanges().

#### Usage

    CohortManifest$updateAtlasCohorts(atlasConnection = NULL, stopOnError = TRUE)

#### Arguments

- `atlasConnection`:

  An ATLAS connection object with a method
  `getCohortDefinition(cohortId)`. If `NULL` (default), uses the
  connection stored via `$setAtlasConnection()`.

- `stopOnError`:

  Logical. If TRUE (default), a failed ATLAS fetch aborts the sync. If
  FALSE, the cohort is skipped with a warning and the remaining cohorts
  are still synced.

#### Returns

invisible of the tibble of atlas changes to update

------------------------------------------------------------------------

### `CohortManifest$statusReport()`

Generate a status report for the manifest

Prints a summary table showing all registered cohorts with their
dependencies and source types. Cohorts marked `'stale'` (pending
regeneration) are included — the `status` column tells them apart.
Useful for auditing the manifest structure.

#### Usage

    CohortManifest$statusReport()

#### Returns

Invisible tibble with columns: id, label, category, source_type,
depends_on, status.

------------------------------------------------------------------------

### `CohortManifest$print()`

Print a friendly view of the CohortManifest

Displays key metadata about the manifest and its contents. Check cohort
tables in the database

#### Usage

    CohortManifest$print()

------------------------------------------------------------------------

### `CohortManifest$checkCohortTables()`

Checks if necessary tables have been created for execution

#### Usage

    CohortManifest$checkCohortTables()

#### Returns

tibble with cohort tables and there exist status Create a single cohort
table in the database

------------------------------------------------------------------------

### `CohortManifest$createCohortTable()`

Creates one required cohort table by type using the current execution
settings.

#### Usage

    CohortManifest$createCohortTable(type, tableName = NULL)

#### Arguments

- `type`:

  Character. One of "main", "inclusion", "inclusion_result",
  "inclusion_stats", "summary_stats", "censor_stats", or "checksum".

- `tableName`:

  Character. Optional explicit table name. If NULL, defaults to the name
  derived from execution settings for the selected type.

#### Returns

Invisible NULL. Create cohort tables in the database

------------------------------------------------------------------------

### `CohortManifest$createAllCohortTables()`

Creates the necessary cohort tables in the target database using the
execution settings. First checks if tables already exist before
attempting creation. This is an advanced/manual setup function. Most
users should run `executeCohortGeneration()` and let it create missing
tables automatically.

#### Usage

    CohortManifest$createAllCohortTables()

#### Returns

Invisible NULL. Creates tables in the database and prints status
messages.

------------------------------------------------------------------------

### `CohortManifest$createCohortTables()`

Deprecated alias for createAllCohortTables

#### Usage

    CohortManifest$createCohortTables()

#### Returns

Invisible NULL. Drop cohort tables from the database

------------------------------------------------------------------------

### `CohortManifest$dropCohortTables()`

Drops cohort tables from the target database. Can drop all standard
cohort tables or specific tables. This is useful for cleaning up or
resetting the cohort generation environment.

#### Usage

    CohortManifest$dropCohortTables(tableTypes = NULL)

#### Arguments

- `tableTypes`:

  Character vector. Types of tables to drop. Options: "cohort",
  "inclusion", "inclusion_result", "inclusion_stats", "summary_stats",
  "censor_stats", "checksum". If NULL (default), drops all table types.

#### Returns

Invisible NULL. Drops tables from the database and prints status
messages. Sync the manifest against cohort files on disk

------------------------------------------------------------------------

### `CohortManifest$syncManifest()`

Scans the `json/` and `sql/` subdirectories of the cohorts folder,
reconciles them against the SQLite manifest, and updates both the
database and the in-memory list:

- Active manifest records whose file no longer exists are soft-deleted,
  along with their derived dependents (which cannot generate without the
  parent).

- Existing files whose SQL hash has changed are updated in the manifest.

- Orphaned files on disk not in manifest are automatically deleted.

Only the `json/` and `sql/` source directories are scanned — derived
cohorts managed via `build*()` methods are not touched.

Stored file paths are resolved against the study repository root before
any disk comparison, and hashes are computed from file contents only, so
a row is reported as `"hash_updated"` only when the file's contents
actually changed — never because its stored path used an older
convention. To rewrite legacy stored paths to the current
repo-root-relative form, run
[`normalizeCohortManifestPaths()`](https://ohdsi.github.io/Picard/reference/normalizeCohortManifestPaths.md)
once; `syncManifest()` does not do this.

#### Usage

    CohortManifest$syncManifest(strict_mode = TRUE)

#### Arguments

- `strict_mode`:

  Logical. If TRUE (default), automatically removes orphaned files found
  on disk. If FALSE, only warns about them without deletion. Default:
  TRUE.

#### Returns

Data frame with columns: id, label, action (`"hash_updated"`,
`"missing_flagged"`, `"cascade_deleted"`, `"unchanged"`,
`"auto_removed_orphan"`). Clean cohort data from the DBMS for deleted
manifest entries

------------------------------------------------------------------------

### `CohortManifest$cleanCohortTable()`

For every cohort with `status = 'deleted'` in the SQLite manifest,
deletes the corresponding rows from the DBMS cohort table and checksum
table, then marks the manifest record as `status = 'purged'` so it is
not processed again.

#### Usage

    CohortManifest$cleanCohortTable()

#### Returns

Data frame with columns: id, label.

------------------------------------------------------------------------

### `CohortManifest$executeCohortGeneration()`

Generates cohorts in the manifest in the target database using the
execution settings. Checks dependency ordering and regenerates dependent
cohorts when parents change. Checks the hash of each cohort definition
and skips generation if the hash matches what's already stored in the
cohort_checksum table. If hashes differ or the cohort is not yet in the
checksum table, regenerates and updates the hash.

#### Usage

    CohortManifest$executeCohortGeneration(confirm = TRUE)

#### Arguments

- `confirm`:

  Logical. If TRUE and interactive, asks for confirmation before
  creating missing tables. If FALSE, missing tables are created without
  prompting. In non-interactive sessions, missing tables are not created
  automatically.

#### Returns

Data frame with execution results including:

- cohort_id: ID of the generated cohort

- label: Label of the cohort

- cohort_type: 'circe', 'subset', 'union', or 'complement'

- depends_on: Comma-separated parent cohort IDs (empty for circe
  cohorts)

- execution_time_min: Time taken to generate (0 for skipped)

- status: 'Success', 'Skipped - already generated', 'Dependency
  skipped', or error message

- dependency_status: 'Not applicable' for circe, 'Parent changed' or
  'Unchanged' for dependent

------------------------------------------------------------------------

### `CohortManifest$retrieveCohortCounts()`

Retrieve cohort counts from the database

Retrieves entry and subject counts for registered cohorts from the
cohort table in the target database. Can retrieve counts for all
active/stale manifest cohorts or a specific subset. Enriches the results
with metadata (label and tags) from the CohortDef objects in the
manifest.

#### Usage

    CohortManifest$retrieveCohortCounts(cohortIds = NULL)

#### Arguments

- `cohortIds`:

  Integer vector. Optional. Specific registered cohort IDs to retrieve
  counts for. If NULL (default), returns counts for all active/stale
  cohorts in the manifest.

#### Returns

Data frame with columns:

- cohort_id: The cohort definition ID

- label: The cohort label from the CohortDef object

- tags: The cohort tags formatted as a string

- cohort_entries: Total number of cohort records

- cohort_subjects: Number of distinct subjects in the cohort

------------------------------------------------------------------------

### `CohortManifest$validateManifest()`

Validate manifest and return status of all cohorts

#### Usage

    CohortManifest$validateManifest()

#### Returns

A tibble with columns: id, label, status (active/missing/deleted),
deleted_at, file_exists

------------------------------------------------------------------------

### `CohortManifest$getManifestStatus()`

Get summary status of manifest

#### Usage

    CohortManifest$getManifestStatus()

#### Returns

List with elements: active_count (registered cohorts, including stale
ones), stale_count, missing_count, deleted_count, next_available_id

------------------------------------------------------------------------

### `CohortManifest$deleteCohort()`

Delete a cohort from manifest and file system

Marks a cohort as deleted in the manifest and removes its file from the
file system (json/ or sql/ directory). The SQLite record is preserved
with status='deleted' for audit trail purposes.

When a manifest is loaded, only active cohorts are loaded into memory.
This enforces strict 1:1 correspondence between active manifest entries
and files on disk.

#### Usage

    CohortManifest$deleteCohort(
      id,
      confirm = FALSE,
      dropFromDBMS = FALSE,
      cascade = FALSE
    )

#### Arguments

- `id`:

  Integer. The cohort ID to delete.

- `confirm`:

  Logical. If FALSE (default), prompts for interactive confirmation.
  Pass TRUE to skip the prompt (suitable for scripts).

- `dropFromDBMS`:

  Logical. If TRUE, also deletes the cohort from the DBMS cohort table
  and checksum table. Requires `executionSettings` to be set. Default:
  FALSE (filesystem/manifest cleanup only).

- `cascade`:

  Logical. If FALSE (default), deletion is refused when the cohort has
  derived dependents (deleting it would orphan them and break cohort
  generation). If TRUE, all transitive dependents are deleted too,
  deepest-first. Default: FALSE (fail-safe).

#### Returns

Invisible NULL.

------------------------------------------------------------------------

### `CohortManifest$buildOPriorT()`

Clean up missing cohorts from manifest

Build a cohort of outcome events with prior target exposure

Creates a derived cohort based on the temporal relationship between an
outcome cohort and a target (exposure) cohort. Filters outcome events
that have (or lack) a prior target event, optionally within a time
window.

Input route policy:

- Preferred: provide `outcomeCohortEntry`/`targetCohortEntry`

- Backward compatible: provide `outcomeCohortId`/`targetCohortId`

- Exactly one route per role must be provided; both/neither is an error.

#### Usage

    CohortManifest$buildOPriorT(
      label,
      category,
      tags = list(),
      outcomeCohortId = NULL,
      targetCohortId = NULL,
      mode = "prior",
      priorTimeWindowDays = NULL,
      subsetLimit = "First",
      outcomeCohortEntry = NULL,
      targetCohortEntry = NULL,
      stopIfExists = TRUE
    )

#### Arguments

- `label`:

  Character. Display name (e.g., "GI Bleed - Prior NSAID").

- `category`:

  Character. Required classification.

- `tags`:

  Named list. Optional metadata tags.

- `outcomeCohortId`:

  Integer. Legacy ID route for the outcome cohort definition ID (e.g.,
  GI bleed).

- `targetCohortId`:

  Integer. Legacy ID route for the target cohort definition ID (e.g.,
  NSAID use).

- `mode`:

  Character. One of 'prior' or 'no_prior':

  - 'prior': Retain outcome events where a prior target event exists.

  - 'no_prior': Retain outcome events where no prior target event
    exists. Default: 'prior'.

- `priorTimeWindowDays`:

  Integer or NULL. If provided (e.g., 365), only consider target events
  within this many days before the outcome start. NULL or 0 means all
  time. Default: NULL.

- `subsetLimit`:

  Character. One of 'First', 'Last', or 'All'. Controls which prior
  target event anchors the match when multiple exist:

  - 'First': Keep the earliest prior target event (default).

  - 'Last': Keep the most recent prior target event.

  - 'All': Keep all prior target events (one output row per pair).
    Default: 'First'.

- `outcomeCohortEntry`:

  Data frame/tibble with one row and an `id` column. Preferred route
  using manifest query results for the outcome cohort.

- `targetCohortEntry`:

  Data frame/tibble with one row and an `id` column. Preferred route
  using manifest query results for the target cohort.

- `stopIfExists`:

  Logical. If TRUE (default), raises an error when an active or stale
  cohort with this label is already registered. If FALSE, updates the
  registered derived cohort in place (same ID and file path): the SQL is
  re-rendered, parents and build parameters are replaced, the cohort is
  marked 'stale' for regeneration (and its own dependents with it) only
  when the definition actually changed — re-running with unchanged
  inputs is a no-op. Default: TRUE (fail-safe).

- `keep_trace`:

  Logical. If TRUE, marks missing as deleted with timestamp (soft
  delete). If FALSE, permanently removes from database (hard delete).
  Defaults to TRUE.

#### Returns

Invisible integer. The assigned cohort ID.

------------------------------------------------------------------------

### `CohortManifest$buildTPriorO()`

Build a cohort of target events with prior outcome occurrence

Creates a derived cohort based on the temporal relationship between a
target (exposure) cohort and an outcome cohort. Filters target events
that have (or lack) a prior outcome event, optionally within a time
window.

This is the reverse direction of `buildOPriorT()`: instead of filtering
outcome by prior target, filter target by prior outcome.

Input route policy:

- Preferred: provide `targetCohortEntry`/`outcomeCohortEntry`

- Backward compatible: provide `targetCohortId`/`outcomeCohortId`

- Exactly one route per role must be provided; both/neither is an error.

#### Usage

    CohortManifest$buildTPriorO(
      label,
      category,
      tags = list(),
      targetCohortId = NULL,
      outcomeCohortId = NULL,
      mode = "prior",
      priorTimeWindowDays = NULL,
      subsetLimit = "First",
      targetCohortEntry = NULL,
      outcomeCohortEntry = NULL,
      stopIfExists = TRUE
    )

#### Arguments

- `label`:

  Character. Display name (e.g., "NSAID - Prior GI Bleed").

- `category`:

  Character. Required classification.

- `tags`:

  Named list. Optional metadata tags.

- `targetCohortId`:

  Integer. Legacy ID route for the target cohort definition ID (e.g.,
  NSAID use).

- `outcomeCohortId`:

  Integer. Legacy ID route for the outcome cohort definition ID (e.g.,
  GI bleed).

- `mode`:

  Character. One of 'prior' or 'no_prior':

  - 'prior': Retain target events where a prior outcome exists.

  - 'no_prior': Retain target events where no prior outcome exists.
    Default: 'prior'.

- `priorTimeWindowDays`:

  Integer or NULL. If provided (e.g., 365), only consider outcome events
  within this many days before the target start. NULL or 0 means all
  time. Default: NULL.

- `subsetLimit`:

  Character. One of 'First', 'Last', or 'All'. Controls which prior
  outcome event anchors the match when multiple exist:

  - 'First': Keep the earliest prior outcome event (default).

  - 'Last': Keep the most recent prior outcome event.

  - 'All': Keep all prior outcome events (one output row per pair).
    Default: 'First'.

- `targetCohortEntry`:

  Data frame/tibble with one row and an `id` column. Preferred route
  using manifest query results for the target cohort.

- `outcomeCohortEntry`:

  Data frame/tibble with one row and an `id` column. Preferred route
  using manifest query results for the outcome cohort.

- `stopIfExists`:

  Logical. If TRUE (default), raises an error when an active or stale
  cohort with this label is already registered. If FALSE, updates the
  registered derived cohort in place (same ID and file path): the SQL is
  re-rendered, parents and build parameters are replaced, the cohort is
  marked 'stale' for regeneration (and its own dependents with it) only
  when the definition actually changed — re-running with unchanged
  inputs is a no-op. Default: TRUE (fail-safe).

#### Returns

Invisible integer. The assigned cohort ID.

------------------------------------------------------------------------

### `CohortManifest$buildCensorCohort()`

Censor a target cohort based on a censoring event

Truncates the cohort_end_date of each target cohort record to the
earliest censoring event that occurs between the cohort_start_date and
cohort_end_date. If no censoring event occurs, the original
cohort_end_date is preserved.

Typical use cases:

- Censor a drug exposure cohort at the date of death

- Censor a disease cohort at the date of disease exacerbation

- Censor a treatment cohort at the date of a procedure (e.g., surgery)

Input route policy:

- Preferred: provide `targetCohortEntry`/`censorCohortEntry`

- Backward compatible: provide `targetCohortId`/`censorCohortId`

- Exactly one route per role must be provided; both/neither is an error.

#### Usage

    CohortManifest$buildCensorCohort(
      label,
      category,
      tags = list(),
      targetCohortId = NULL,
      censorCohortId = NULL,
      targetCohortEntry = NULL,
      censorCohortEntry = NULL,
      stopIfExists = TRUE
    )

#### Arguments

- `label`:

  Character. Display name (e.g., "NSAID Use - Censored at Death").

- `category`:

  Character. Required classification.

- `tags`:

  Named list. Optional metadata tags.

- `targetCohortId`:

  Integer. Legacy ID route for the cohort definition ID to censor.

- `censorCohortId`:

  Integer. Legacy ID route for the cohort definition ID for the
  censoring event.

- `targetCohortEntry`:

  Data frame/tibble with one row and an `id` column. Preferred route
  using manifest query results for the target cohort.

- `censorCohortEntry`:

  Data frame/tibble with one row and an `id` column. Preferred route
  using manifest query results for the censor cohort.

- `stopIfExists`:

  Logical. If TRUE (default), raises an error when an active or stale
  cohort with this label is already registered. If FALSE, updates the
  registered derived cohort in place (same ID and file path): the SQL is
  re-rendered, parents and build parameters are replaced, the cohort is
  marked 'stale' for regeneration (and its own dependents with it) only
  when the definition actually changed — re-running with unchanged
  inputs is a no-op. Default: TRUE (fail-safe).

#### Returns

Invisible integer. The assigned cohort ID.

------------------------------------------------------------------------

### `CohortManifest$cleanupMissing()`

clean up missing files from manifest

#### Usage

    CohortManifest$cleanupMissing(keep_trace = TRUE)

#### Arguments

- `keep_trace`:

  Logical. soft delete with trace

#### Returns

Invisibly returns NULL. Displays summary of cleanup actions.

------------------------------------------------------------------------

### `CohortManifest$clone()`

The objects of this class are cloneable with this method.

#### Usage

    CohortManifest$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
