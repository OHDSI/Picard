# CohortManifest R6 Class

CohortManifest R6 Class

CohortManifest R6 Class

## Details

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

- tempEmulationSchema if needed for the database platform

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

- [`CohortManifest$new()`](#method-CohortManifest-new)

- [`CohortManifest$getManifest()`](#method-CohortManifest-getManifest)

- [`CohortManifest$reviewDependentCohorts()`](#method-CohortManifest-reviewDependentCohorts)

- [`CohortManifest$tabulateManifest()`](#method-CohortManifest-tabulateManifest)

- [`CohortManifest$reviewStaleCohorts()`](#method-CohortManifest-reviewStaleCohorts)

- [`CohortManifest$reloadFromDb()`](#method-CohortManifest-reloadFromDb)

- [`CohortManifest$getDbPath()`](#method-CohortManifest-getDbPath)

- [`CohortManifest$getExecutionSettings()`](#method-CohortManifest-getExecutionSettings)

- [`CohortManifest$setExecutionSettings()`](#method-CohortManifest-setExecutionSettings)

- [`CohortManifest$getAtlasConnection()`](#method-CohortManifest-getAtlasConnection)

- [`CohortManifest$setAtlasConnection()`](#method-CohortManifest-setAtlasConnection)

- [`CohortManifest$addAtlasCohort()`](#method-CohortManifest-addAtlasCohort)

- [`CohortManifest$importAtlasCohorts()`](#method-CohortManifest-importAtlasCohorts)

- [`CohortManifest$addCaprCohort()`](#method-CohortManifest-addCaprCohort)

- [`CohortManifest$addSqlCohort()`](#method-CohortManifest-addSqlCohort)

- [`CohortManifest$addCirceCohort()`](#method-CohortManifest-addCirceCohort)

- [`CohortManifest$buildUnionCohort()`](#method-CohortManifest-buildUnionCohort)

- [`CohortManifest$buildSubsetCohortTemporal()`](#method-CohortManifest-buildSubsetCohortTemporal)

- [`CohortManifest$buildComplementCohort()`](#method-CohortManifest-buildComplementCohort)

- [`CohortManifest$buildCustomDependentCohort()`](#method-CohortManifest-buildCustomDependentCohort)

- [`CohortManifest$buildCompositeCohort()`](#method-CohortManifest-buildCompositeCohort)

- [`CohortManifest$buildDemographicCohort()`](#method-CohortManifest-buildDemographicCohort)

- [`CohortManifest$buildStratifiedCohorts()`](#method-CohortManifest-buildStratifiedCohorts)

- [`CohortManifest$queryCohortsByIds()`](#method-CohortManifest-queryCohortsByIds)

- [`CohortManifest$queryCohortsByTag()`](#method-CohortManifest-queryCohortsByTag)

- [`CohortManifest$queryCohortsByLabel()`](#method-CohortManifest-queryCohortsByLabel)

- [`CohortManifest$queryCohortsByCategory()`](#method-CohortManifest-queryCohortsByCategory)

- [`CohortManifest$queryCohortsByTagName()`](#method-CohortManifest-queryCohortsByTagName)

- [`CohortManifest$nCohorts()`](#method-CohortManifest-nCohorts)

- [`CohortManifest$getCohortById()`](#method-CohortManifest-getCohortById)

- [`CohortManifest$getCohortsByTag()`](#method-CohortManifest-getCohortsByTag)

- [`CohortManifest$getCohortsByLabel()`](#method-CohortManifest-getCohortsByLabel)

- [`CohortManifest$updateCohortLabel()`](#method-CohortManifest-updateCohortLabel)

- [`CohortManifest$updateCohortCategory()`](#method-CohortManifest-updateCohortCategory)

- [`CohortManifest$updateCohortTags()`](#method-CohortManifest-updateCohortTags)

- [`CohortManifest$checkAtlasCohorts()`](#method-CohortManifest-checkAtlasCohorts)

- [`CohortManifest$updateAtlasCohorts()`](#method-CohortManifest-updateAtlasCohorts)

- [`CohortManifest$statusReport()`](#method-CohortManifest-statusReport)

- [`CohortManifest$print()`](#method-CohortManifest-print)

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

### Method `new()`

Initialize a new CohortManifest

#### Usage

    CohortManifest$new(dbPath = "inputs/cohorts/cohortManifest.sqlite")

#### Arguments

- `dbPath`:

  Character. Path to the SQLite database. Defaults to
  "inputs/cohorts/cohortManifest.sqlite" Get the manifest as a list of
  CohortDef objects

------------------------------------------------------------------------

### Method `getManifest()`

#### Usage

    CohortManifest$getManifest()

#### Returns

List. A list of CohortDef objects in the manifest, indexed by cohort ID.
Review dependent cohorts and their dependency metadata

------------------------------------------------------------------------

### Method `reviewDependentCohorts()`

Returns a summary tibble of all active derived cohorts (union, subset,
complement, composite, oprior, tprior, censor) with parsed dependency
information sourced directly from SQLite. Useful for quickly auditing
what each derived cohort depends on and how it was built.

#### Usage

    CohortManifest$reviewDependentCohorts()

#### Returns

A tibble with columns:

- `id` - Cohort ID

- `label` - Cohort label

- `cohort_type` - One of 'union', 'subset', 'complement', 'composite',
  'oprior', 'tprior', 'censor'

- `category` - User-defined category

- `parent_cohorts` - Human-readable parent list, e.g. "Label A (1),
  Label B (2)"

- `rule_summary` - Compact summary of the dependency rule parameters

- `created_at` - Timestamp of creation

------------------------------------------------------------------------

### Method `tabulateManifest()`

Tabulate the manifest as a tibble

#### Usage

    CohortManifest$tabulateManifest(
      filter = c("active", "deleted", "stale", "all")
    )

#### Arguments

- `filter`:

  Character. Controls which rows are returned. One of `"active"`
  (default), `"deleted"`, or `"all"`.

#### Returns

A tibble with columns: id, label, category, tags, file_path, hash,
source_type, cohort_type, status, created_at, deleted_at Review stale
derived cohorts

------------------------------------------------------------------------

### Method `reviewStaleCohorts()`

Returns a summary of all cohorts currently marked `'stale'` — meaning a
parent cohort's SQL file has changed since the derived cohort was last
executed. Stale cohorts are still valid SQL; they just need to be
re-executed. `executeCohortGeneration()` will run them automatically
regardless of checksum state.

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

### Method `reloadFromDb()`

Re-reads all active cohort records from SQLite and rebuilds the
in-memory list of CohortDef objects. Useful after external changes to
the database (e.g., after `resetCohortManifest(scope = "derived")`).

#### Usage

    CohortManifest$reloadFromDb()

#### Returns

Invisible self. Get the manifest path

------------------------------------------------------------------------

### Method `getDbPath()`

#### Usage

    CohortManifest$getDbPath()

#### Returns

Character. The path to the SQLite database. Get the execution settings

------------------------------------------------------------------------

### Method `getExecutionSettings()`

#### Usage

    CohortManifest$getExecutionSettings()

#### Returns

Object. The execution settings object for DBMS cohort generation, or
NULL if not set. Set the execution settings

------------------------------------------------------------------------

### Method `setExecutionSettings()`

#### Usage

    CohortManifest$setExecutionSettings(executionSettings)

#### Arguments

- `executionSettings`:

  Object. Execution settings for DBMS cohort generation. Get the stored
  ATLAS connection

------------------------------------------------------------------------

### Method [`getAtlasConnection()`](https://ohdsi.github.io/Picard/reference/getAtlasConnection.md)

#### Usage

    CohortManifest$getAtlasConnection()

#### Returns

The ATLAS connection object, or NULL if not set. Set an ATLAS connection
for use by add/import methods

Stores a connection so it does not need to be passed to
`addAtlasCohort()` or `importAtlasCohorts()` on every call.

------------------------------------------------------------------------

### Method [`setAtlasConnection()`](https://ohdsi.github.io/Picard/reference/setAtlasConnection.md)

#### Usage

    CohortManifest$setAtlasConnection(atlasConnection)

#### Arguments

- `atlasConnection`:

  An ATLAS connection object (from
  [`getAtlasConnection()`](https://ohdsi.github.io/Picard/reference/getAtlasConnection.md)).

#### Returns

Invisible self for method chaining.

------------------------------------------------------------------------

### Method `addAtlasCohort()`

Add a single cohort from ATLAS

Fetches a cohort JSON from ATLAS, saves it to `json/`, and registers the
cohort in the manifest.

#### Usage

    CohortManifest$addAtlasCohort(
      atlasId,
      label,
      category,
      tags = list(),
      atlasConnection = NULL
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

#### Returns

Invisible integer. The assigned cohort ID.

------------------------------------------------------------------------

### Method `importAtlasCohorts()`

Batch-import cohorts from ATLAS via a cohortsLoad dataframe

Either create a dataframe or read in a csv file with columns `atlasId`,
`label`, `category` (required) plus any additional columns treated as
tag key-value pairs for tags. Calls `addAtlasCohort()` for each row
inside a `tryCatch` so a single failure does not abort the entire batch.

#### Usage

    CohortManifest$importAtlasCohorts(cohortsLoad, atlasConnection = NULL)

#### Arguments

- `cohortsLoad`:

  a data frame requiring the columns atlasId, label and category used to
  bulk add cohorts to the manifest

- `atlasConnection`:

  An ATLAS connection object with a `getCohortDefinition(cohortId)`
  method. If `NULL`, falls back to the connection stored via
  `$setAtlasConnection()`.

#### Returns

Invisible tibble of imported cohorts.

------------------------------------------------------------------------

### Method `addCaprCohort()`

Add a Capr cohort

Takes a Capr Cohort object, exports it to JSON in `json/`, and registers
the cohort in the manifest.

#### Usage

    CohortManifest$addCaprCohort(caprCohort, label, category, tags = list())

#### Arguments

- `caprCohort`:

  A Capr Cohort object (inherits from "Cohort").

- `label`:

  Character. Display name for the cohort.

- `category`:

  Character. Required classification.

- `tags`:

  Named list. Optional metadata tags.

#### Returns

Invisible integer. The assigned cohort ID.

------------------------------------------------------------------------

### Method `addSqlCohort()`

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

  Logical. If TRUE (default), raises an error if the file already exists
  on disk or is already registered in the manifest. If FALSE, overwrites
  silently with a warning. Default: TRUE (fail-safe).

#### Returns

Invisible integer. The assigned cohort ID.

------------------------------------------------------------------------

### Method `addCirceCohort()`

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

### Method `buildUnionCohort()`

Build a union cohort from existing cohorts

Creates a derived cohort that is the union of specified parent cohorts.
Delegates SQL generation to the internal builder function.

#### Usage

    CohortManifest$buildUnionCohort(
      label,
      category,
      tags = list(),
      cohortIds,
      gapDays = 0L,
      eraPadDays = 0L,
      minEraDays = 0L,
      minCohorts = 1L,
      washoutDays = 0L,
      firstEraOnly = FALSE
    )

#### Arguments

- `label`:

  Character. Display name for the derived cohort.

- `category`:

  Character. Required classification.

- `tags`:

  Named list. Optional metadata tags.

- `cohortIds`:

  Numeric vector (minimum 2). Cohort IDs to union.

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

#### Returns

Invisible integer. The assigned cohort ID.

------------------------------------------------------------------------

### Method `buildSubsetCohortTemporal()`

Build a subset cohort with temporal criteria

Creates a derived cohort that subsets a base cohort using temporal
relationship to a filter cohort.

#### Usage

    CohortManifest$buildSubsetCohortTemporal(
      label,
      category,
      tags = list(),
      baseCohortId,
      filterCohortId,
      startWindow,
      endWindow = NULL,
      endDateType = "base",
      subsetLimit = "First"
    )

#### Arguments

- `label`:

  Character. Display name.

- `category`:

  Character. Required classification.

- `tags`:

  Named list. Optional metadata tags.

- `baseCohortId`:

  Integer. The cohort ID to subset.

- `filterCohortId`:

  Integer. The cohort ID to use for temporal filtering.

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

#### Returns

Invisible integer. The assigned cohort ID.

------------------------------------------------------------------------

### Method `buildComplementCohort()`

Build a complement cohort

Creates a derived cohort containing all subjects from the population
cohort who do NOT appear in any (or all) of the exclude cohorts.

#### Usage

    CohortManifest$buildComplementCohort(
      label,
      category,
      tags = list(),
      populationCohortId,
      excludeCohortIds,
      complementType = "exclude_any"
    )

#### Arguments

- `label`:

  Character. Display name.

- `category`:

  Character. Required classification.

- `tags`:

  Named list. Optional metadata tags.

- `populationCohortId`:

  Integer. ID of the population (base) cohort.

- `excludeCohortIds`:

  Integer vector (min length 1). IDs of cohorts whose subjects should be
  excluded from the population.

- `complementType`:

  Character. One of `"exclude_any"` (default) or `"exclude_all"`.
  `"exclude_any"` removes subjects present in ANY exclude cohort;
  `"exclude_all"` removes subjects only if they appear in ALL exclude
  cohorts.

#### Returns

Invisible integer. The assigned cohort ID.

------------------------------------------------------------------------

### Method `buildCustomDependentCohort()`

Build a custom dependent cohort from a user-supplied SQL file

Registers an existing `.sql` file as a derived cohort with explicit
dependencies on manifest cohorts. Unlike `addSqlCohort()` (which treats
the file as a base cohort), this method copies the SQL into the
`derived/` directory and sets `depends_on`, so the skip-logic uses
dependency-aware hashing (see Phase 1.1).

#### Usage

    CohortManifest$buildCustomDependentCohort(
      filePath,
      label,
      category,
      cohortIds,
      tags = list()
    )

#### Arguments

- `filePath`:

  Character. Path to the user's `.sql` file. The file is **copied** into
  the `derived/` directory — the original is not referenced after
  registration.

- `label`:

  Character. Display name (must be unique in manifest).

- `category`:

  Character. Required classification.

- `cohortIds`:

  Integer vector (min. 1). Parent cohort IDs this SQL depends on. All
  must exist in the manifest.

- `tags`:

  Named list. Optional metadata tags.

#### Returns

Invisible integer. The assigned cohort ID.

------------------------------------------------------------------------

### Method `buildCompositeCohort()`

Build a composite cohort

Creates a derived cohort that requires membership in multiple cohorts
(intersection logic).

#### Usage

    CohortManifest$buildCompositeCohort(
      label,
      category,
      tags = list(),
      criteriaCohortIds,
      eventSelection = "First",
      minEventCount = 1L
    )

#### Arguments

- `label`:

  Character. Display name.

- `category`:

  Character. Required classification.

- `tags`:

  Named list. Optional metadata tags.

- `criteriaCohortIds`:

  Integer vector. The cohort IDs to include in the composite (e.g., c(1,
  2, 3) for Type 1 diabetes, Type 2 diabetes, and secondary diabetes).

- `eventSelection`:

  Character. One of 'First', 'Last', or 'All'. Specifies which event(s)
  to retain as the cohort_start_date and cohort_end_date in the output:

  - 'First': Keep the earliest event (earliest index date)

  - 'Last': Keep the most recent event

  - 'All': Keep all qualifying events per subject (may result in
    multiple rows per subject) Default: 'First'.

- `minEventCount`:

  Integer. Minimum number of distinct cohort events required for a
  subject to qualify for the composite. Default: 1 (any subject with at
  least 1 event qualifies).

#### Returns

Invisible integer. The assigned cohort ID.

------------------------------------------------------------------------

### Method `buildDemographicCohort()`

Build a demographic subset cohort

Creates a derived cohort that subsets a base cohort by filtering on
person-level demographic attributes (age, gender, race, ethnicity).

#### Usage

    CohortManifest$buildDemographicCohort(
      label,
      baseCohortId,
      category,
      minAge = NULL,
      maxAge = NULL,
      genderConceptIds = NULL,
      raceConceptIds = NULL,
      ethnicityConceptIds = NULL,
      tags = list()
    )

#### Arguments

- `label`:

  Character. Display name (e.g., "CKD - Males 40-75").

- `baseCohortId`:

  Integer. ID of the base cohort to subset.

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

#### Returns

Invisible integer. The assigned cohort ID.

------------------------------------------------------------------------

### Method `buildStratifiedCohorts()`

Split a base cohort into stratified sub-cohorts

Splits a single base cohort into N named stratum cohorts plus an
automatic **Unclassified** cohort containing subjects that match none of
the named strata. Each stratum is registered as a separate manifest
entry with `cohort_type = "subset"`.

#### Usage

    CohortManifest$buildStratifiedCohorts(
      baseCohortId,
      strata,
      labelPrefix = NULL,
      category = "derived",
      tags = list()
    )

#### Arguments

- `baseCohortId`:

  Integer. The cohort definition ID to split.

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

#### Returns

Invisibly returns a named list of assigned cohort IDs, keyed by cohort
label. Query cohorts by IDs

------------------------------------------------------------------------

### Method `queryCohortsByIds()`

#### Usage

    CohortManifest$queryCohortsByIds(ids)

#### Arguments

- `ids`:

  Integer vector. One or more cohort IDs.

#### Returns

Data frame. A subset of the manifest with columns id, label, tags,
filePath, hash, timestamp for matching cohorts, or NULL if none found.
Query cohorts by tag

------------------------------------------------------------------------

### Method `queryCohortsByTag()`

#### Usage

    CohortManifest$queryCohortsByTag(tagStrings, match = c("any", "all"))

#### Arguments

- `tagStrings`:

  Character vector. One or more tags in the format "name: value" (e.g.,
  "category: primary"). When multiple tags are supplied, the `match`
  argument controls whether a cohort must satisfy any or all of them.

- `match`:

  Character. "any" (default) returns cohorts matching at least one tag;
  "all" returns only cohorts matching every tag.

#### Returns

Tibble with columns: id, label, category, tags, file_path, hash,
source_type, created_at. Query cohorts by label

------------------------------------------------------------------------

### Method `queryCohortsByLabel()`

#### Usage

    CohortManifest$queryCohortsByLabel(labels, matchType = c("exact", "pattern"))

#### Arguments

- `labels`:

  Character vector. One or more labels to search for. A cohort is
  included when it matches at least one of the supplied labels (OR
  logic).

- `matchType`:

  Character. Either "exact" for exact match or "pattern" for pattern
  matching. Defaults to "exact".

#### Returns

Tibble with columns: id, label, category, tags, file_path, hash,
source_type, created_at. Query cohorts by category

------------------------------------------------------------------------

### Method `queryCohortsByCategory()`

#### Usage

    CohortManifest$queryCohortsByCategory(
      category,
      matchType = c("exact", "pattern")
    )

#### Arguments

- `category`:

  Character vector. One or more category to search for. A cohort is
  included when it matches at least one of the supplied category (OR
  logic).

- `matchType`:

  Character. Either "exact" for exact match or "pattern" for pattern
  matching. Defaults to "exact".

#### Returns

Tibble with columns: id, label, category, tags, file_path, hash,
source_type, created_at. Query cohorts by category

------------------------------------------------------------------------

### Method `queryCohortsByTagName()`

#### Usage

    CohortManifest$queryCohortsByTagName(tagName)

#### Arguments

- `tagName`:

  Character vector. The name of tags to query

#### Returns

Tibble with columns: id, label, category, tags, file_path, hash,
source_type, created_at.

------------------------------------------------------------------------

### Method `nCohorts()`

Get number of cohorts in manifest

#### Usage

    CohortManifest$nCohorts()

#### Returns

Integer. The number of cohorts. Get a specific cohort by ID

------------------------------------------------------------------------

### Method `getCohortById()`

#### Usage

    CohortManifest$getCohortById(id)

#### Arguments

- `id`:

  Integer. The cohort ID.

#### Returns

CohortDef. The CohortDef object with matching ID, or NULL if not found.
Get cohorts by tag

------------------------------------------------------------------------

### Method `getCohortsByTag()`

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

### Method `getCohortsByLabel()`

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

### Method `updateCohortLabel()`

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

### Method `updateCohortCategory()`

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

### Method `updateCohortTags()`

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

### Method `checkAtlasCohorts()`

Auto-detect changes to ATLAS cohorts in remote repository

Queries the manifest for all active ATLAS cohorts (identified by
`atlasId` in tags), fetches their current definitions from ATLAS,
computes hashes, and compares against the stored local hash. Provides a
read-only summary of which cohorts have changed in ATLAS since import.
No modifications are made.

#### Usage

    CohortManifest$checkAtlasCohorts(atlasConnection = NULL)

#### Arguments

- `atlasConnection`:

  An ATLAS connection object with a method
  `getCohortDefinition(cohortId)` that returns a list with an
  `expression` element. If `NULL` (default), uses the connection stored
  via `$setAtlasConnection()`. If no connection is available, raises an
  error.

#### Returns

Invisible tibble with columns:

- `id` - Cohort ID in manifest

- `label` - Cohort label

- `atlasId` - ATLAS cohort definition ID

- `hasChanged` - Logical; TRUE if remote hash differs from local

- `localHash` - Hash of stored JSON

- `remoteHash` - Hash of current ATLAS JSON

------------------------------------------------------------------------

### Method `updateAtlasCohorts()`

Update ATLAS cohorts with remote definitions

Fetches current definitions from ATLAS for specified cohorts and updates
the stored JSON files and manifest entries. This is the modification
phase that applies changes detected by checkAtlasChanges().

#### Usage

    CohortManifest$updateAtlasCohorts(atlasConnection = NULL)

#### Arguments

- `atlasConnection`:

  An ATLAS connection object with a method
  `getCohortDefinition(cohortId)`. If `NULL` (default), uses the
  connection stored via `$setAtlasConnection()`.

#### Returns

invisible of the tibble of atlas changes to update

------------------------------------------------------------------------

### Method `statusReport()`

Generate a status report for the manifest

Prints a summary table showing all active cohorts with their
dependencies and source types. Useful for auditing the manifest
structure.

#### Usage

    CohortManifest$statusReport()

#### Returns

Invisible tibble with columns: id, label, category, source_type,
depends_on, status.

------------------------------------------------------------------------

### Method [`print()`](https://rdrr.io/r/base/print.html)

Print a friendly view of the CohortManifest

Displays key metadata about the manifest and its contents. Create cohort
tables in the database

#### Usage

    CohortManifest$print()

------------------------------------------------------------------------

### Method `createCohortTables()`

Creates the necessary cohort tables in the target database using the
execution settings. First checks if tables already exist before
attempting creation.

#### Usage

    CohortManifest$createCohortTables()

#### Returns

Invisible NULL. Creates tables in the database and prints status
messages. Drop cohort tables from the database

------------------------------------------------------------------------

### Method `dropCohortTables()`

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

### Method `syncManifest()`

Scans the `json/` and `sql/` subdirectories of the cohorts folder,
reconciles them against the SQLite manifest, and updates both the
database and the in-memory list:

- Active manifest records whose file no longer exists are soft-deleted.

- Existing files whose SQL hash has changed are updated in the manifest.

- Orphaned files on disk not in manifest are automatically deleted.

Only the `json/` and `sql/` source directories are scanned — derived
cohorts managed via `build*()` methods are not touched.

#### Usage

    CohortManifest$syncManifest(strict_mode = TRUE)

#### Arguments

- `strict_mode`:

  Logical. If TRUE (default), automatically removes orphaned files found
  on disk. If FALSE, only warns about them without deletion. Default:
  TRUE.

#### Returns

Data frame with columns: id, label, action (`"hash_updated"`,
`"missing_flagged"`, `"unchanged"`, `"auto_removed_orphan"`). Clean
cohort data from the DBMS for deleted manifest entries

------------------------------------------------------------------------

### Method `cleanCohortTable()`

For every cohort with `status = 'deleted'` in the SQLite manifest,
deletes the corresponding rows from the DBMS cohort table and checksum
table, then marks the manifest record as `status = 'purged'` so it is
not processed again.

#### Usage

    CohortManifest$cleanCohortTable()

#### Returns

Data frame with columns: id, label.

------------------------------------------------------------------------

### Method `executeCohortGeneration()`

Generates cohorts in the manifest in the target database using the
execution settings. Checks dependency ordering and regenerates dependent
cohorts when parents change. Checks the hash of each cohort definition
and skips generation if the hash matches what's already stored in the
cohort_checksum table. If hashes differ or the cohort is not yet in the
checksum table, regenerates and updates the hash.

#### Usage

    CohortManifest$executeCohortGeneration()

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

### Method `retrieveCohortCounts()`

Retrieve cohort counts from the database

Retrieves entry and subject counts for cohorts from the cohort table in
the target database. Can retrieve counts for all cohorts or a specific
subset. Enriches the results with metadata (label and tags) from the
CohortDef objects in the manifest.

#### Usage

    CohortManifest$retrieveCohortCounts(cohortIds = NULL)

#### Arguments

- `cohortIds`:

  Integer vector. Optional. Specific cohort IDs to retrieve counts for.
  If NULL (default), returns counts for all cohorts.

#### Returns

Data frame with columns:

- cohort_id: The cohort definition ID

- label: The cohort label from the CohortDef object

- tags: The cohort tags formatted as a string

- cohort_entries: Total number of cohort records

- cohort_subjects: Number of distinct subjects in the cohort

------------------------------------------------------------------------

### Method `validateManifest()`

Validate manifest and return status of all cohorts

#### Usage

    CohortManifest$validateManifest()

#### Returns

A tibble with columns: id, label, status (active/missing/deleted),
deleted_at, file_exists

------------------------------------------------------------------------

### Method `getManifestStatus()`

Get summary status of manifest

#### Usage

    CohortManifest$getManifestStatus()

#### Returns

List with elements: active_count, missing_count, deleted_count,
next_available_id

------------------------------------------------------------------------

### Method `deleteCohort()`

Delete a cohort from manifest and file system

Marks a cohort as deleted in the manifest and removes its file from the
file system (json/ or sql/ directory). The SQLite record is preserved
with status='deleted' for audit trail purposes.

When a manifest is loaded, only active cohorts are loaded into memory.
This enforces strict 1:1 correspondence between active manifest entries
and files on disk.

#### Usage

    CohortManifest$deleteCohort(id, confirm = FALSE, dropFromDBMS = FALSE)

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

#### Returns

Invisible NULL.

------------------------------------------------------------------------

### Method `buildOPriorT()`

Clean up missing cohorts from manifest

Build a cohort of outcome events with prior target exposure

Creates a derived cohort based on the temporal relationship between an
outcome cohort and a target (exposure) cohort. Filters outcome events
that have (or lack) a prior target event, optionally within a time
window.

#### Usage

    CohortManifest$buildOPriorT(
      label,
      category,
      tags = list(),
      outcomeCohortId,
      targetCohortId,
      mode = "prior",
      priorTimeWindowDays = NULL,
      subsetLimit = "First"
    )

#### Arguments

- `label`:

  Character. Display name (e.g., "GI Bleed - Prior NSAID").

- `category`:

  Character. Required classification.

- `tags`:

  Named list. Optional metadata tags.

- `outcomeCohortId`:

  Integer. The cohort definition ID for the outcome (e.g., GI bleed).

- `targetCohortId`:

  Integer. The cohort definition ID for the target (e.g., NSAID use).

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

- `keep_trace`:

  Logical. If TRUE, marks missing as deleted with timestamp (soft
  delete). If FALSE, permanently removes from database (hard delete).
  Defaults to TRUE.

#### Returns

Invisible integer. The assigned cohort ID.

------------------------------------------------------------------------

### Method `buildTPriorO()`

Build a cohort of target events with prior outcome occurrence

Creates a derived cohort based on the temporal relationship between a
target (exposure) cohort and an outcome cohort. Filters target events
that have (or lack) a prior outcome event, optionally within a time
window.

This is the reverse direction of `buildOPriorT()`: instead of filtering
outcome by prior target, filter target by prior outcome.

#### Usage

    CohortManifest$buildTPriorO(
      label,
      category,
      tags = list(),
      targetCohortId,
      outcomeCohortId,
      mode = "prior",
      priorTimeWindowDays = NULL,
      subsetLimit = "First"
    )

#### Arguments

- `label`:

  Character. Display name (e.g., "NSAID - Prior GI Bleed").

- `category`:

  Character. Required classification.

- `tags`:

  Named list. Optional metadata tags.

- `targetCohortId`:

  Integer. The cohort definition ID for the target (e.g., NSAID use).

- `outcomeCohortId`:

  Integer. The cohort definition ID for the outcome (e.g., GI bleed).

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

#### Returns

Invisible integer. The assigned cohort ID.

------------------------------------------------------------------------

### Method `buildCensorCohort()`

Censor a target cohort based on a censoring event

Truncates the cohort_end_date of each target cohort record to the
earliest censoring event that occurs between the cohort_start_date and
cohort_end_date. If no censoring event occurs, the original
cohort_end_date is preserved.

Typical use cases:

- Censor a drug exposure cohort at the date of death

- Censor a disease cohort at the date of disease exacerbation

- Censor a treatment cohort at the date of a procedure (e.g., surgery)

#### Usage

    CohortManifest$buildCensorCohort(
      label,
      category,
      tags = list(),
      targetCohortId,
      censorCohortId
    )

#### Arguments

- `label`:

  Character. Display name (e.g., "NSAID Use - Censored at Death").

- `category`:

  Character. Required classification.

- `tags`:

  Named list. Optional metadata tags.

- `targetCohortId`:

  Integer. The cohort definition ID for the cohort to censor.

- `censorCohortId`:

  Integer. The cohort definition ID for the censoring event.

#### Returns

Invisible integer. The assigned cohort ID.

------------------------------------------------------------------------

### Method `cleanupMissing()`

clean up missing files from manifest

#### Usage

    CohortManifest$cleanupMissing(keep_trace = TRUE)

#### Arguments

- `keep_trace`:

  Logical. soft delete with trace

#### Returns

Invisibly returns NULL. Displays summary of cleanup actions.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    CohortManifest$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
