# ConceptSetManifest R6 Class

An R6 class that manages a collection of ConceptSetDef objects and
maintains metadata in a SQLite database.

The ConceptSetManifest class manages multiple concept set definitions
and stores their metadata in a SQLite database located at
inputs/conceptSets/conceptSetManifest.sqlite. Each ConceptSetDef is
assigned a sequential ID based on its position in the manifest.

The load file is kept in the study repository as the record of which
ATLAS concept sets the study uses. By default, rows whose atlasId is
already registered in the manifest are an error, not an update, so an
import only adds new concept sets. Set `stopIfExists = FALSE` to instead
update those rows in place, which lets the whole load file be
re-imported on every run. To sync registered concept sets with ATLAS
without re-importing, use `updateAtlasConceptSets()`.

**Processing Steps:**

1.  Validates that all concept set IDs exist and are active

2.  Loads each concept set JSON as a Capr object using
    [`Capr::readConceptSet()`](https://ohdsi.github.io/Capr/reference/readConceptSet.html)

3.  Combines them using set logic (private helper
    `combine_capr_concept_sets()`)

4.  Exports combined Capr object to JSON in `json/` directory

5.  Registers the new combined concept set in the manifest

6.  Returns the new concept set ID

**Concept Set Combination Logic:**

- Includes: All included concepts across sets

- Descendants: All concepts marked with descendants

- Excludes: All excluded concepts (without descendants)

- Exclude+Descendants: All concepts to exclude with descendants

**Requirements:**

- Capr package must be installed

- All source concept sets must be active and have valid JSON files

This is the detection phase of the ATLAS maintenance workflow. Use this
to identify which ATLAS concept sets have changed, then optionally call
`updateAtlasConceptSets()` to apply updates. Changes are detected by
comparing expression JSON hashes.

This method updates ATLAS concept sets that have changed in the remote
repository. It:

- Calls checkAtlasConceptSets() to identify changes

- For each changed concept set: fetches current definition, updates JSON
  file, updates hash in manifest

- Refreshes the in-memory manifest

Use `checkAtlasConceptSets()` first to identify which concept sets have
changed, then call this method to apply updates.

**Requirements:**

- ExecutionSettings must be initialized with a valid database connection

- ExecutionSettings must have `cdmDatabaseSchema` and optionally
  `tempEmulationSchema` set

- User must have READ access to OMOP concept and concept_ancestor tables

**Processing:**

1.  Resolves the concept set by manifest ID or exact label

2.  Retrieves the concept set definition (CIRCE JSON)

3.  Builds SQL query using
    [`CirceR::buildConceptSetQuery()`](https://ohdsi.github.io/CirceR/reference/buildConceptSetQuery.html)

4.  Executes query against the OMOP vocabulary schema

5.  Returns results with concept_id and concept_name columns

Extract Source Codes for Concept Sets

**Vocabulary Suggestion by Domain:** The function automatically suggests
appropriate vocabularies based on concept set domains:

- `condition_occurrence`: ICD10CM, ICD9CM

- `procedure`: HCPCS, CPT4

- `measurement`: LOINC

- `drug_exposure`: NDC

- `observation`: All vocabularies (ICD9CM, ICD10CM, HCPCS, CPT4, LOINC,
  NDC)

- `device_exposure`: NDC

- `visit_occurrence`: ICD10CM, ICD9CM, HCPCS, CPT4

Note: These suggestions are based on OMOP CDM conventions. You can
override with any valid vocabulary combination.

**Processing Workflow:**

1.  Verifies ExecutionSettings is configured with database connection

2.  Detects domains of all concept sets in the manifest

3.  Displays suggested vocabularies based on detected domains

4.  In interactive sessions, prompts the user to accept or override the
    suggestions; non-interactive sessions keep `sourceVocabs`

5.  Creates a new xlsx workbook

6.  For each concept set in the manifest:

    - Reads the CIRCE JSON definition

    - Builds a concept query selecting standard concepts (using CirceR)

    - Performs SQL join: concepts -\> concept_relationship (Maps to) -\>
      source concepts

    - Finds matching source codes in the specified vocabularies

    - Adds results as a new sheet in the xlsx workbook with formatted
      header

    - Provides status messages for each concept set

7.  Exports combined results to `{outputFolder}/SourceCodeWorkbook.xlsx`

8.  Each sheet contains columns: vocabulary_id, concept_code,
    concept_name

9.  Sheet headers are styled with blue background and white bold text

10. Column widths are auto-fitted for readability

**SQL Query Pattern:** For each concept set, the following logic is
executed:

- CTE selects all standard concepts in the concept set

- Joins to concept_relationship table with relationship_id = 'Maps to'

- Maps relationship finds what source codes map TO standard concepts

- Filters to valid, non-invalid source codes in specified vocabularies

- Results ordered by vocabulary_id and concept_code

**Requirements:**

- ExecutionSettings must be initialized with a valid database connection

- Vocabulary schema must be accessible from ExecutionSettings

- openxlsx2 package must be installed

- User must have READ permissions on vocabulary tables

**Error Handling:**

- Displays warnings if any concept set processing fails but continues
  with others

- Provides clear error messages if database connection is unavailable

- Validates source vocabularies against known vocabulary IDs

This function identifies which standard concepts are included in each
concept set by finding the reverse mapping relationship. For each
concept set:

1.  Reads the CIRCE JSON definition

2.  Builds a concept query using CirceR

3.  Joins with concept_relationship via reverse "Maps to" relationship
    (finds what maps TO the concept set concepts)

4.  Filters for standard concepts (standard_concept = 'S')

5.  Adds results to a new sheet in the xlsx workbook

6.  Exports all results to `{outputFolder}/IncludedCodes.xlsx`

7.  Each sheet contains: concept_id, concept_name, vocabulary_id

**Requirements:**

- ExecutionSettings must be initialized with a valid connection

- Vocabulary schema must be accessible from ExecutionSettings

- openxlsx2 package must be installed

## Methods

### Public methods

- [`ConceptSetManifest$new()`](#method-ConceptSetManifest-initialize)

- [`ConceptSetManifest$getManifest()`](#method-ConceptSetManifest-getManifest)

- [`ConceptSetManifest$getManifestHash()`](#method-ConceptSetManifest-getManifestHash)

- [`ConceptSetManifest$tabulateManifest()`](#method-ConceptSetManifest-tabulateManifest)

- [`ConceptSetManifest$viewManifest()`](#method-ConceptSetManifest-viewManifest)

- [`ConceptSetManifest$getDbPath()`](#method-ConceptSetManifest-getDbPath)

- [`ConceptSetManifest$getProjectRoot()`](#method-ConceptSetManifest-getProjectRoot)

- [`ConceptSetManifest$getExecutionSettings()`](#method-ConceptSetManifest-getExecutionSettings)

- [`ConceptSetManifest$setExecutionSettings()`](#method-ConceptSetManifest-setExecutionSettings)

- [`ConceptSetManifest$getAtlasConnection()`](#method-ConceptSetManifest-getAtlasConnection)

- [`ConceptSetManifest$setAtlasConnection()`](#method-ConceptSetManifest-setAtlasConnection)

- [`ConceptSetManifest$addConceptSetFile()`](#method-ConceptSetManifest-addConceptSetFile)

- [`ConceptSetManifest$addAtlasConceptSet()`](#method-ConceptSetManifest-addAtlasConceptSet)

- [`ConceptSetManifest$addCaprConceptSet()`](#method-ConceptSetManifest-addCaprConceptSet)

- [`ConceptSetManifest$updateCaprConceptSet()`](#method-ConceptSetManifest-updateCaprConceptSet)

- [`ConceptSetManifest$importAtlasConceptSets()`](#method-ConceptSetManifest-importAtlasConceptSets)

- [`ConceptSetManifest$queryConceptSetsByIds()`](#method-ConceptSetManifest-queryConceptSetsByIds)

- [`ConceptSetManifest$queryConceptSetsByTag()`](#method-ConceptSetManifest-queryConceptSetsByTag)

- [`ConceptSetManifest$queryConceptSetsByCategory()`](#method-ConceptSetManifest-queryConceptSetsByCategory)

- [`ConceptSetManifest$queryConceptSetsByTagName()`](#method-ConceptSetManifest-queryConceptSetsByTagName)

- [`ConceptSetManifest$queryConceptSetsMissingTag()`](#method-ConceptSetManifest-queryConceptSetsMissingTag)

- [`ConceptSetManifest$queryConceptSetsWithTagValues()`](#method-ConceptSetManifest-queryConceptSetsWithTagValues)

- [`ConceptSetManifest$getTagValuesSummary()`](#method-ConceptSetManifest-getTagValuesSummary)

- [`ConceptSetManifest$queryConceptSetsByLabel()`](#method-ConceptSetManifest-queryConceptSetsByLabel)

- [`ConceptSetManifest$nConceptSets()`](#method-ConceptSetManifest-nConceptSets)

- [`ConceptSetManifest$getConceptSetById()`](#method-ConceptSetManifest-getConceptSetById)

- [`ConceptSetManifest$getConceptSetsByTag()`](#method-ConceptSetManifest-getConceptSetsByTag)

- [`ConceptSetManifest$getConceptSetsByLabel()`](#method-ConceptSetManifest-getConceptSetsByLabel)

- [`ConceptSetManifest$validateManifest()`](#method-ConceptSetManifest-validateManifest)

- [`ConceptSetManifest$getManifestStatus()`](#method-ConceptSetManifest-getManifestStatus)

- [`ConceptSetManifest$deleteConceptSet()`](#method-ConceptSetManifest-deleteConceptSet)

- [`ConceptSetManifest$combineConceptSets()`](#method-ConceptSetManifest-combineConceptSets)

- [`ConceptSetManifest$updateConceptSetLabel()`](#method-ConceptSetManifest-updateConceptSetLabel)

- [`ConceptSetManifest$updateConceptSetCategory()`](#method-ConceptSetManifest-updateConceptSetCategory)

- [`ConceptSetManifest$updateConceptSetTags()`](#method-ConceptSetManifest-updateConceptSetTags)

- [`ConceptSetManifest$removeConceptSetTag()`](#method-ConceptSetManifest-removeConceptSetTag)

- [`ConceptSetManifest$modifyConceptSetTagValue()`](#method-ConceptSetManifest-modifyConceptSetTagValue)

- [`ConceptSetManifest$addConceptSetTag()`](#method-ConceptSetManifest-addConceptSetTag)

- [`ConceptSetManifest$getConceptSetTags()`](#method-ConceptSetManifest-getConceptSetTags)

- [`ConceptSetManifest$mergeTagsIntoConceptSet()`](#method-ConceptSetManifest-mergeTagsIntoConceptSet)

- [`ConceptSetManifest$listAllUniqueTags()`](#method-ConceptSetManifest-listAllUniqueTags)

- [`ConceptSetManifest$getTagValue()`](#method-ConceptSetManifest-getTagValue)

- [`ConceptSetManifest$renameTagKey()`](#method-ConceptSetManifest-renameTagKey)

- [`ConceptSetManifest$bulkModifyTagValue()`](#method-ConceptSetManifest-bulkModifyTagValue)

- [`ConceptSetManifest$checkAtlasConceptSets()`](#method-ConceptSetManifest-checkAtlasConceptSets)

- [`ConceptSetManifest$updateAtlasConceptSets()`](#method-ConceptSetManifest-updateAtlasConceptSets)

- [`ConceptSetManifest$cleanupMissing()`](#method-ConceptSetManifest-cleanupMissing)

- [`ConceptSetManifest$syncManifest()`](#method-ConceptSetManifest-syncManifest)

- [`ConceptSetManifest$grabConceptInfoFromSet()`](#method-ConceptSetManifest-grabConceptInfoFromSet)

- [`ConceptSetManifest$extractSourceCodes()`](#method-ConceptSetManifest-extractSourceCodes)

- [`ConceptSetManifest$extractIncludedCodes()`](#method-ConceptSetManifest-extractIncludedCodes)

- [`ConceptSetManifest$clone()`](#method-ConceptSetManifest-clone)

------------------------------------------------------------------------

### `ConceptSetManifest$new()`

Initialize a new ConceptSetManifest

#### Usage

    ConceptSetManifest$new(
      dbPath = "inputs/conceptSets/conceptSetManifest.sqlite",
      projectRoot = NULL
    )

#### Arguments

- `dbPath`:

  Character. Path to the SQLite database. Defaults to
  "inputs/conceptSets/conceptSetManifest.sqlite". The directory is
  created automatically if it does not exist.

- `projectRoot`:

  Character or NULL. Study repository root against which stored file
  paths are resolved. When `NULL` (default) the root is discovered once
  via
  [`findStudyProjectRoot()`](https://ohdsi.github.io/Picard/reference/findStudyProjectRoot.md)
  from the manifest's directory and cached for the life of the object.
  Supply an explicit path for tests or unusual layouts. Get the manifest
  as a list of ConceptSetDef objects

------------------------------------------------------------------------

### `ConceptSetManifest$getManifest()`

#### Usage

    ConceptSetManifest$getManifest()

#### Returns

List. A list of ConceptSetDef objects in the manifest. Compute a
deterministic hash of the manifest for task-rerun detection

------------------------------------------------------------------------

### `ConceptSetManifest$getManifestHash()`

Produces a single SHA256 string over everything about the active concept
sets that a task can depend on. Used by the study pipeline (via
[`shouldRerunTask()`](https://ohdsi.github.io/Picard/reference/shouldRerunTask.md)):
when it changes, tasks rerun.

This is distinct from a concept set's *definition hash*
(`ConceptSetDef$getHash()`), which covers only the expression JSON.
Tasks also select or group concept sets by label, category, or tag, so a
change to that metadata changes the analysis even when no definition
changed.

For each concept set, ordered by id, the hash combines:

- `id`, `label`, `category`, `tags`

- a hash of the loaded concept set's expression JSON (normalized, so a
  cosmetic reformat does not move the hash), or the sentinel
  `"<missing>"` when the file is absent from disk

The stored file path is excluded, so path normalization does not force
spurious reruns.

#### Usage

    ConceptSetManifest$getManifestHash()

#### Returns

Character. A SHA256 hash string. An empty manifest hashes to a stable
constant.

------------------------------------------------------------------------

### `ConceptSetManifest$tabulateManifest()`

Tabulate the concept set manifest

#### Usage

    ConceptSetManifest$tabulateManifest(
      filter = c("active", "deleted", "all"),
      tags_format = c("nested", "json", "wide")
    )

#### Arguments

- `filter`:

  Character. One of "active", "deleted", or "all". Defaults to "active".

- `tags_format`:

  Character. One of "nested", "json", or "wide".

  - "nested" (default): Parse JSON tags into a nested tibble with
    tag_name/tag_value columns

  - "json": Keep tags as raw JSON string

  - "wide": Expand tags into individual columns (one per unique tag key)

#### Returns

Tibble with concept set manifest data. Tags format depends on
tags_format parameter.

------------------------------------------------------------------------

### `ConceptSetManifest$viewManifest()`

View the concept set manifest in RStudio viewer

Opens an interactive RStudio viewer showing key concept set metadata:
id, label, category, tags, and file_path. This is a convenience function
for exploring manifest contents without console clutter.

#### Usage

    ConceptSetManifest$viewManifest(
      filter = c("active", "deleted", "all"),
      tags_format = c("nested", "json", "wide")
    )

#### Arguments

- `filter`:

  Character. One of "active", "deleted", or "all". Defaults to "active".

- `tags_format`:

  Character. One of "nested", "json", or "wide".

  - "nested" (default): Tags as structured nested tibble

  - "json": Tags as raw JSON string

  - "wide": Tags expanded into individual columns

#### Returns

Invisibly returns the tibble displayed in the viewer. Get the manifest
path

------------------------------------------------------------------------

### `ConceptSetManifest$getDbPath()`

#### Usage

    ConceptSetManifest$getDbPath()

#### Returns

Character. The path to the SQLite database. Get the study repository
root

------------------------------------------------------------------------

### `ConceptSetManifest$getProjectRoot()`

#### Usage

    ConceptSetManifest$getProjectRoot()

#### Returns

Character. The cached study repository root used to resolve stored file
paths. Get the execution settings

------------------------------------------------------------------------

### `ConceptSetManifest$getExecutionSettings()`

#### Usage

    ConceptSetManifest$getExecutionSettings()

#### Returns

Object. The execution settings object for vocabulary access, or NULL if
not set. Set or update execution settings

------------------------------------------------------------------------

### `ConceptSetManifest$setExecutionSettings()`

#### Usage

    ConceptSetManifest$setExecutionSettings(executionSettings)

#### Arguments

- `executionSettings`:

  ExecutionSettings object for database access.

#### Returns

Invisibly returns self for method chaining. Get the stored ATLAS
connection

------------------------------------------------------------------------

### `ConceptSetManifest$getAtlasConnection()`

#### Usage

    ConceptSetManifest$getAtlasConnection()

#### Returns

The ATLAS connection object, or NULL if not set. Set an ATLAS connection
for use by add/import methods

Stores a connection so it does not need to be passed to
`addAtlasConceptSet()` or `importAtlasConceptSets()` on every call.

------------------------------------------------------------------------

### `ConceptSetManifest$setAtlasConnection()`

#### Usage

    ConceptSetManifest$setAtlasConnection(atlasConnection)

#### Arguments

- `atlasConnection`:

  An ATLAS connection object (from
  [`getAtlasConnection()`](https://ohdsi.github.io/Picard/reference/getAtlasConnection.md)).

#### Returns

Invisible self for method chaining.

------------------------------------------------------------------------

### `ConceptSetManifest$addConceptSetFile()`

Register a local CIRCE JSON file in the manifest

#### Usage

    ConceptSetManifest$addConceptSetFile(
      filePath,
      label,
      category = "init",
      tags = list()
    )

#### Arguments

- `filePath`:

  Character. Absolute or relative path to a valid CIRCE JSON file.

- `label`:

  Character. Display name for the concept set.

- `category`:

  Character. Category for the concept set. Defaults to `"init"`.

- `tags`:

  Named list. Optional extra metadata tags. Defaults to
  [`list()`](https://rdrr.io/r/base/list.html).

#### Returns

Invisible integer. The assigned concept set ID.

------------------------------------------------------------------------

### `ConceptSetManifest$addAtlasConceptSet()`

Fetch a single concept set from ATLAS and register it in the manifest

#### Usage

    ConceptSetManifest$addAtlasConceptSet(
      atlasId,
      label,
      category = "init",
      tags = list(),
      atlasConnection = NULL,
      stopIfExists = TRUE
    )

#### Arguments

- `atlasId`:

  Integer. The ATLAS concept set definition ID.

- `label`:

  Character. Display name for the concept set.

- `category`:

  Character. Category for the concept set. Defaults to `"init"`.

- `tags`:

  Named list. Optional extra metadata tags. Defaults to
  [`list()`](https://rdrr.io/r/base/list.html).

- `atlasConnection`:

  An ATLAS connection object with a
  `getConceptSetDefinition(conceptSetId)` method that returns a list
  with `expression` (CIRCE JSON string) and `saveName` elements. If
  `NULL`, falls back to the connection stored via
  `$setAtlasConnection()`.

- `stopIfExists`:

  Logical. If TRUE (default), raises an error when an active concept set
  with this label is already registered. If FALSE, fetches the current
  definition from ATLAS and updates the registered concept set in place
  — same ID and file path, hash refreshed, `category`/`tags`/atlasId
  replaced. An unchanged definition leaves the file untouched. Default:
  TRUE (fail-safe).

#### Returns

Invisible integer. The assigned concept set ID.

------------------------------------------------------------------------

### `ConceptSetManifest$addCaprConceptSet()`

Export a Capr ConceptSet to JSON and register it in the manifest

#### Usage

    ConceptSetManifest$addCaprConceptSet(
      caprConceptSet,
      label,
      category = "init",
      tags = list(),
      stopIfExists = TRUE
    )

#### Arguments

- `caprConceptSet`:

  A Capr `ConceptSet` object.

- `label`:

  Character. Display name for the concept set.

- `category`:

  Character. Category for the concept set. Defaults to `"init"`.

- `tags`:

  Named list. Optional extra metadata tags. Defaults to
  [`list()`](https://rdrr.io/r/base/list.html).

- `stopIfExists`:

  Logical. If TRUE (default), raises an error when an active concept set
  with this label is already registered. If FALSE, updates the existing
  concept set in place via `updateCaprConceptSet()` — it keeps its ID
  and file path, and `category`/`tags` replace the registered metadata
  (previous tags are dropped if none are supplied). Default: TRUE
  (fail-safe).

#### Returns

Invisible integer. The assigned concept set ID.

------------------------------------------------------------------------

### `ConceptSetManifest$updateCaprConceptSet()`

Update an existing Capr concept set's JSON definition

Takes a revised Capr ConceptSet object and upserts it over a concept set
already registered via `addCaprConceptSet()`: the JSON file recorded in
the manifest is overwritten in place and the manifest hash is refreshed,
so the concept set keeps its ID and file path. If the new definition is
identical to the registered one, nothing is changed.

#### Usage

    ConceptSetManifest$updateCaprConceptSet(caprConceptSet, label)

#### Arguments

- `caprConceptSet`:

  A Capr `ConceptSet` object.

- `label`:

  Character. Label of the active concept set to update.

#### Returns

Invisible integer. The concept set ID.

------------------------------------------------------------------------

### `ConceptSetManifest$importAtlasConceptSets()`

Batch-import concept sets from ATLAS via a conceptSetsLoad dataframe

Either create a dataframe or read in a csv file with columns `atlasId`,
`label`, `category` (required) plus any additional columns treated as
tag key-value pairs for tags. Calls `addAtlasConceptSet()` for each row
inside a `tryCatch` so a single failure does not abort the entire batch.

#### Usage

    ConceptSetManifest$importAtlasConceptSets(
      conceptSetsLoad,
      atlasConnection = NULL,
      stopIfExists = TRUE
    )

#### Arguments

- `conceptSetsLoad`:

  a data frame requiring the columns atlasId, label and category used to
  bulk add cohorts to the manifest

- `atlasConnection`:

  An ATLAS connection object with a
  `getConceptSetDefinition(conceptSetId)` method. If `NULL`, falls back
  to the connection stored via `$setAtlasConnection()`.

- `stopIfExists`:

  Logical. If TRUE (default), raises an error when any load row's
  atlasId is already registered in the manifest. If FALSE, those rows
  are updated in place instead (same ID/file path, hash refreshed,
  category/tags replaced) via
  `addAtlasConceptSet(stopIfExists = FALSE)`. Default: TRUE (fail-safe).

#### Returns

Invisible tibble imported concept sets. Query concept sets by IDs

------------------------------------------------------------------------

### `ConceptSetManifest$queryConceptSetsByIds()`

#### Usage

    ConceptSetManifest$queryConceptSetsByIds(
      ids,
      tags_format = c("nested", "json", "wide")
    )

#### Arguments

- `ids`:

  Integer vector. One or more concept set IDs.

- `tags_format`:

  Character. One of "nested", "json", or "wide".

  - "nested" (default): Tags as nested tibble with tag_name/tag_value
    columns

  - "json": Tags as raw JSON string

  - "wide": Tags expanded into individual columns

#### Returns

Tibble with matching concept sets. Tag columns depend on `tags_format`.
Returns NULL if no matches are found. Query concept sets by tag

------------------------------------------------------------------------

### `ConceptSetManifest$queryConceptSetsByTag()`

#### Usage

    ConceptSetManifest$queryConceptSetsByTag(
      tagStrings,
      match = c("any", "all"),
      tags_format = c("nested", "json", "wide")
    )

#### Arguments

- `tagStrings`:

  Character vector. One or more tags in the format "name: value" (e.g.,
  "category: primary"). When multiple tags are supplied, the `match`
  argument controls whether a concept set must satisfy any or all of
  them.

- `match`:

  Character. "any" (default) returns concept sets matching at least one
  tag; "all" returns only concept sets matching every tag.

- `tags_format`:

  Character. One of "nested", "json", or "wide".

  - "nested" (default): Tags as nested tibble with tag_name/tag_value
    columns

  - "json": Tags as raw JSON string

  - "wide": Tags expanded into individual columns

#### Returns

Tibble with matching concept sets. Tag columns depend on `tags_format`.
Returns NULL if no matches are found. Query concept sets by category

------------------------------------------------------------------------

### `ConceptSetManifest$queryConceptSetsByCategory()`

#### Usage

    ConceptSetManifest$queryConceptSetsByCategory(
      category,
      matchType = c("exact", "pattern"),
      tags_format = c("nested", "json", "wide")
    )

#### Arguments

- `category`:

  Character vector. One or more category to search for. A concept set is
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

Tibble with matching concept sets. Tag columns depend on `tags_format`.
Returns NULL if no matches are found. Query concept sets by tag name

------------------------------------------------------------------------

### `ConceptSetManifest$queryConceptSetsByTagName()`

#### Usage

    ConceptSetManifest$queryConceptSetsByTagName(
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

Tibble with matching concept sets. Tag columns depend on `tags_format`.
Returns NULL if no matches are found.

------------------------------------------------------------------------

### `ConceptSetManifest$queryConceptSetsMissingTag()`

Query concept sets missing a specific tag

#### Usage

    ConceptSetManifest$queryConceptSetsMissingTag(
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

Tibble with matching concept sets. Tag columns depend on `tags_format`.
Returns NULL if all concept sets have the tag.

------------------------------------------------------------------------

### `ConceptSetManifest$queryConceptSetsWithTagValues()`

Query concept sets by tag value mapping

#### Usage

    ConceptSetManifest$queryConceptSetsWithTagValues(
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

Tibble with matching concept sets. Tag columns depend on `tags_format`.
Returns NULL if no concept sets match all tag conditions.

------------------------------------------------------------------------

### `ConceptSetManifest$getTagValuesSummary()`

Get a summary of all unique values for a specific tag

#### Usage

    ConceptSetManifest$getTagValuesSummary(tagName)

#### Arguments

- `tagName`:

  Character. The name of the tag to summarize.

#### Returns

Tibble with columns: value, count, concept_sets (comma-separated IDs).
Returns NULL if no concept sets have the tag. Query concept sets by
label

------------------------------------------------------------------------

### `ConceptSetManifest$queryConceptSetsByLabel()`

#### Usage

    ConceptSetManifest$queryConceptSetsByLabel(
      labels,
      matchType = c("exact", "pattern"),
      tags_format = c("nested", "json", "wide")
    )

#### Arguments

- `labels`:

  Character vector. One or more labels to search for. A concept set is
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

Tibble with matching concept sets. Tag columns depend on `tags_format`.
Returns NULL if no matches are found.

------------------------------------------------------------------------

### `ConceptSetManifest$nConceptSets()`

Get number of concept sets in manifest

#### Usage

    ConceptSetManifest$nConceptSets()

#### Returns

Integer. The number of concept sets. Get a specific concept set by ID

------------------------------------------------------------------------

### `ConceptSetManifest$getConceptSetById()`

#### Usage

    ConceptSetManifest$getConceptSetById(id)

#### Arguments

- `id`:

  Integer. The concept set ID.

#### Returns

ConceptSetDef. The ConceptSetDef object with matching ID, or NULL if not
found. Get concept sets by tag

------------------------------------------------------------------------

### `ConceptSetManifest$getConceptSetsByTag()`

#### Usage

    ConceptSetManifest$getConceptSetsByTag(tagStrings, match = c("any", "all"))

#### Arguments

- `tagStrings`:

  Character vector. One or more tags in the format "name: value" (e.g.,
  "category: primary"). When multiple tags are supplied, the `match`
  argument controls whether a concept set must satisfy any or all of
  them.

- `match`:

  Character. "any" (default) returns concept sets matching at least one
  tag; "all" returns only concept sets matching every tag.

#### Returns

List. A list of ConceptSetDef objects with matching tags, or NULL if
none found. Get concept sets by label

------------------------------------------------------------------------

### `ConceptSetManifest$getConceptSetsByLabel()`

#### Usage

    ConceptSetManifest$getConceptSetsByLabel(
      labels,
      matchType = c("exact", "pattern")
    )

#### Arguments

- `labels`:

  Character vector. One or more labels to search for. A concept set is
  included when it matches at least one of the supplied labels (OR
  logic).

- `matchType`:

  Character. Either "exact" for exact match or "pattern" for pattern
  matching. Defaults to "exact".

#### Returns

List. A list of ConceptSetDef objects with matching labels, or NULL if
none found.

------------------------------------------------------------------------

### `ConceptSetManifest$validateManifest()`

Validate manifest and return status of all concept sets

#### Usage

    ConceptSetManifest$validateManifest()

#### Returns

A tibble with columns: id, label, status (active/missing/deleted),
deleted_at, file_exists

------------------------------------------------------------------------

### `ConceptSetManifest$getManifestStatus()`

Get summary status of manifest

#### Usage

    ConceptSetManifest$getManifestStatus()

#### Returns

List with elements: active_count, missing_count, deleted_count,
next_available_id

------------------------------------------------------------------------

### `ConceptSetManifest$deleteConceptSet()`

Soft delete a concept set (mark as deleted, preserve record)

#### Usage

    ConceptSetManifest$deleteConceptSet(id, confirm = FALSE)

#### Arguments

- `id`:

  Integer. The concept set ID to delete.

- `confirm`:

  Logical. If FALSE (default), prompts for interactive confirmation.
  Pass TRUE to skip the prompt (suitable for scripts).

#### Returns

Invisibly returns TRUE if successful, FALSE otherwise.

------------------------------------------------------------------------

### `ConceptSetManifest$combineConceptSets()`

Combine multiple concept sets into a single unified concept set

Loads multiple concept sets from the manifest as Capr objects, merges
them into a unified concept set using set logic (include,
include+descendants, exclude, exclude+descendants), exports the result
as JSON, and registers it in the manifest.

#### Usage

    ConceptSetManifest$combineConceptSets(
      conceptSetIds,
      combinedLabel,
      combinedCategory = "combined",
      combinedTags = list(),
      stopIfExists = TRUE
    )

#### Arguments

- `conceptSetIds`:

  Integer vector. IDs of concept sets to combine (minimum 2).

- `combinedLabel`:

  Character. Display name for the combined concept set.

- `combinedCategory`:

  Character. Category for the combined concept set. Defaults to
  `"combined"`.

- `combinedTags`:

  Named list. Optional metadata tags for the combined set. Defaults to
  [`list()`](https://rdrr.io/r/base/list.html). A tag
  `sourceConceptSetIds` is automatically added with comma-separated
  source IDs.

- `stopIfExists`:

  Logical. If TRUE (default), raises an error when an active concept set
  with `combinedLabel` is already registered. If FALSE, updates the
  existing concept set in place via `addCaprConceptSet()`'s upsert path
  — it keeps its ID and file path, and `combinedCategory`/
  `combinedTags` replace the registered metadata. Default: TRUE
  (fail-safe).

#### Returns

Invisible integer. The ID of the newly created (or updated) combined
concept set.

------------------------------------------------------------------------

### `ConceptSetManifest$updateConceptSetLabel()`

Update a concept set label

#### Usage

    ConceptSetManifest$updateConceptSetLabel(conceptSetId, newLabel)

#### Arguments

- `conceptSetId`:

  Integer. The concept set ID to update.

- `newLabel`:

  Character. The new label for the concept set.

#### Returns

Invisible NULL.

------------------------------------------------------------------------

### `ConceptSetManifest$updateConceptSetCategory()`

Update a concept set category

#### Usage

    ConceptSetManifest$updateConceptSetCategory(conceptSetId, newCategory)

#### Arguments

- `conceptSetId`:

  Integer. The concept set ID to update.

- `newCategory`:

  Character. The new category for the concept set.

#### Returns

Invisible NULL.

------------------------------------------------------------------------

### `ConceptSetManifest$updateConceptSetTags()`

Update concept set tags

#### Usage

    ConceptSetManifest$updateConceptSetTags(conceptSetId, newTags)

#### Arguments

- `conceptSetId`:

  Integer. The concept set ID to update.

- `newTags`:

  Named list. The new tags for the concept set.

#### Returns

Invisible NULL.

------------------------------------------------------------------------

### `ConceptSetManifest$removeConceptSetTag()`

Remove a specific tag from a concept set

#### Usage

    ConceptSetManifest$removeConceptSetTag(conceptSetId, tagName)

#### Arguments

- `conceptSetId`:

  Integer. The concept set ID to update.

- `tagName`:

  Character. The name of the tag to remove.

#### Returns

Invisible NULL. Emits success message if tag was removed, warning if tag
was not found.

------------------------------------------------------------------------

### `ConceptSetManifest$modifyConceptSetTagValue()`

Modify the value of an existing tag

#### Usage

    ConceptSetManifest$modifyConceptSetTagValue(conceptSetId, tagName, newValue)

#### Arguments

- `conceptSetId`:

  Integer. The concept set ID to update.

- `tagName`:

  Character. The name of the tag to modify.

- `newValue`:

  Character. The new value for the tag.

#### Returns

Invisible NULL. Emits success message if tag was modified, error if tag
does not exist.

------------------------------------------------------------------------

### `ConceptSetManifest$addConceptSetTag()`

Add a single tag to a concept set (non-destructive)

#### Usage

    ConceptSetManifest$addConceptSetTag(conceptSetId, tagName, tagValue)

#### Arguments

- `conceptSetId`:

  Integer. The concept set ID to update.

- `tagName`:

  Character. The name of the tag to add.

- `tagValue`:

  Character. The value for the new tag.

#### Returns

Invisible NULL. Emits success message if tag was added.

------------------------------------------------------------------------

### `ConceptSetManifest$getConceptSetTags()`

Get all tags for a specific concept set

#### Usage

    ConceptSetManifest$getConceptSetTags(conceptSetId)

#### Arguments

- `conceptSetId`:

  Integer. The concept set ID to query.

#### Returns

Named list of tags, or NULL if concept set not found.

------------------------------------------------------------------------

### `ConceptSetManifest$mergeTagsIntoConceptSet()`

Merge multiple tags into a concept set (non-destructive, additive)

#### Usage

    ConceptSetManifest$mergeTagsIntoConceptSet(conceptSetId, newTags)

#### Arguments

- `conceptSetId`:

  Integer. The concept set ID to update.

- `newTags`:

  Named list. The tags to add/merge (overwrites existing keys with same
  name).

#### Returns

Invisible NULL. Emits success message.

------------------------------------------------------------------------

### `ConceptSetManifest$listAllUniqueTags()`

Get all unique tag names used across the concept set manifest

#### Usage

    ConceptSetManifest$listAllUniqueTags()

#### Returns

Character vector of unique tag names, sorted alphabetically.

------------------------------------------------------------------------

### `ConceptSetManifest$getTagValue()`

Get value of a single tag for a concept set

#### Usage

    ConceptSetManifest$getTagValue(conceptSetId, tagName)

#### Arguments

- `conceptSetId`:

  Integer. The concept set ID to query.

- `tagName`:

  Character. The name of the tag to retrieve.

#### Returns

Character. The tag value, or NULL if tag or concept set not found.

------------------------------------------------------------------------

### `ConceptSetManifest$renameTagKey()`

Rename a tag key across specified concept sets (or all concept sets)

#### Usage

    ConceptSetManifest$renameTagKey(oldTagName, newTagName, conceptSetIds = NULL)

#### Arguments

- `oldTagName`:

  Character. The current tag name to rename.

- `newTagName`:

  Character. The new tag name.

- `conceptSetIds`:

  Integer vector or NULL. If NULL, renames across all concept sets that
  have this tag.

#### Returns

Invisible tibble with id, old_value showing what was renamed.

------------------------------------------------------------------------

### `ConceptSetManifest$bulkModifyTagValue()`

Bulk modify a tag value across concept sets matching an old value

#### Usage

    ConceptSetManifest$bulkModifyTagValue(tagName, oldValue, newValue)

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

### `ConceptSetManifest$checkAtlasConceptSets()`

Auto-detect changes to ATLAS concept sets in remote repository

Queries the manifest for all active ATLAS concept sets (identified by
`atlasId` in tags), fetches their current definitions from ATLAS,
computes hashes, and compares against the stored local hash. Provides a
read-only summary of which concept sets have changed in ATLAS since
import. No modifications are made.

#### Usage

    ConceptSetManifest$checkAtlasConceptSets(
      atlasConnection = NULL,
      stopOnError = TRUE
    )

#### Arguments

- `atlasConnection`:

  An ATLAS connection object with a method
  `getConceptSetDefinition(conceptSetId)` that returns a list with an
  `expression` element (the CIRCE JSON as a string). If `NULL`
  (default), uses the connection stored via `$setAtlasConnection()`. If
  no connection is available, raises an error.

- `stopOnError`:

  Logical. If TRUE (default), a failed ATLAS fetch aborts the sync. If
  FALSE, the concept set is skipped with a warning and the remaining
  concept sets are still synced.

#### Returns

Invisible tibble with columns:

- `id`: Concept set ID in the local manifest

- `label`: Concept set label

- `atlasId`: ATLAS concept set ID

- `filePath`: Local path to the JSON file

- `hasChanged`: Logical, TRUE if remote definition differs from local
  hash

- `localHash`: Hash of the stored JSON file

- `remoteHash`: Hash of the current ATLAS definition

------------------------------------------------------------------------

### `ConceptSetManifest$updateAtlasConceptSets()`

Update ATLAS concept sets with remote definitions

Fetches current definitions from ATLAS for concept sets that have
changed and updates the stored JSON files and manifest entries. This is
the modification phase that applies changes detected by
checkAtlasConceptSets().

#### Usage

    ConceptSetManifest$updateAtlasConceptSets(
      atlasConnection = NULL,
      stopOnError = TRUE
    )

#### Arguments

- `atlasConnection`:

  An ATLAS connection object with a method
  `getConceptSetDefinition(conceptSetId)`. If `NULL` (default), uses the
  connection stored via `$setAtlasConnection()`.

- `stopOnError`:

  Logical. If TRUE (default), a failed ATLAS fetch aborts the sync. If
  FALSE, the concept set is skipped with a warning and the remaining
  concept sets are still synced.

#### Returns

Invisible tibble of concept sets that were updated, with columns: id,
label, atlasId, filePath, hasChanged, localHash, remoteHash

------------------------------------------------------------------------

### `ConceptSetManifest$cleanupMissing()`

Clean up missing concept sets from manifest

#### Usage

    ConceptSetManifest$cleanupMissing(keep_trace = TRUE)

#### Arguments

- `keep_trace`:

  Logical. If TRUE, marks missing as deleted with timestamp (soft
  delete). If FALSE, permanently removes from database (hard delete).
  Defaults to TRUE.

#### Returns

Invisibly returns NULL. Displays summary of cleanup actions. Sync the
manifest against concept set files on disk

------------------------------------------------------------------------

### `ConceptSetManifest$syncManifest()`

Scans the `json/` subdirectory of the concept sets folder, reconciles it
against the SQLite manifest, and updates both the database and the
in-memory list:

- Active manifest records whose file no longer exists are soft-deleted.

- Existing files whose JSON hash has changed are updated in the
  manifest.

- Orphaned files on disk not in manifest are automatically deleted.

Stored file paths are resolved against the study repository root before
any disk comparison, and hashes are computed from file contents only, so
a row is reported as `"hash_updated"` only when the file's contents
actually changed — never because its stored path used an older
convention. To rewrite legacy stored paths to the current
repo-root-relative form, run
[`normalizeConceptSetManifestPaths()`](https://ohdsi.github.io/Picard/reference/normalizeConceptSetManifestPaths.md)
once.

#### Usage

    ConceptSetManifest$syncManifest(strict_mode = TRUE)

#### Arguments

- `strict_mode`:

  Logical. If TRUE (default), automatically removes orphaned files found
  on disk. If FALSE, only warns about them without deletion. Default:
  TRUE.

#### Returns

Data frame with columns: id, label, action (`"hash_updated"`,
`"missing_flagged"`, `"unchanged"`, or `"auto_removed_orphan"`).

------------------------------------------------------------------------

### `ConceptSetManifest$grabConceptInfoFromSet()`

Retrieve concept information for all concepts in a concept set

Fetches the standard concepts included in a concept set from the OMOP
vocabulary tables. The concept set definition (stored as CIRCE JSON) is
used to build a query that retrieves all concept IDs and names matching
the set definition. Results are returned as a tibble with concept
identifiers and display names.

#### Usage

    ConceptSetManifest$grabConceptInfoFromSet(conceptSetRef)

#### Arguments

- `conceptSetRef`:

  Integer or Character. Concept set reference in the manifest. Pass
  either the manifest ID or the exact concept set label. Use
  `tabulateManifest()` to inspect available IDs and labels.

#### Returns

Tibble with columns:

- `conceptId`: Integer, the OMOP concept identifier

- `conceptName`: Character, the concept name from the vocabulary

------------------------------------------------------------------------

### `ConceptSetManifest$extractSourceCodes()`

Finds source codes from specified vocabularies that map to each concept
set's standard concepts. Results are exported to a single xlsx file with
one sheet per concept set, saved in the inputs/conceptSets folder. The
function provides interactive vocabulary suggestions based on detected
concept set domains.

#### Usage

    ConceptSetManifest$extractSourceCodes(
      sourceVocabs = c("ICD10CM"),
      outputFolder = here::here("inputs/conceptSets")
    )

#### Arguments

- `sourceVocabs`:

  Character vector. Source vocabulary IDs to search for. Valid options:
  "ICD9CM", "ICD10CM", "HCPCS", "CPT4", "LOINC", "NDC". Defaults to
  c("ICD10CM"). The function will suggest appropriate vocabularies based
  on the domains of your concept sets and, in interactive sessions,
  prompt you to use them. Non-interactive sessions use this value
  directly.

- `outputFolder`:

  Character. Path where the xlsx file will be saved. Defaults to
  "inputs/conceptSets".

#### Returns

Invisibly returns NULL. Saves xlsx file to outputFolder and prints
status messages via cli package. Output file is ready to open in Excel
or other spreadsheet software.

Extract Included Standard Concepts for Concept Sets

Finds standard concepts that are included in (map TO) each concept set's
included concepts. Results are exported to a single xlsx file with one
sheet per concept set, saved in the inputs/conceptSets folder.

------------------------------------------------------------------------

### `ConceptSetManifest$extractIncludedCodes()`

#### Usage

    ConceptSetManifest$extractIncludedCodes(
      outputFolder = here::here("inputs/conceptSets")
    )

#### Arguments

- `outputFolder`:

  Character. Path where the xlsx file will be saved. Defaults to
  "inputs/conceptSets".

#### Returns

Invisibly returns NULL. Saves xlsx file to outputFolder and prints
status messages.

------------------------------------------------------------------------

### `ConceptSetManifest$clone()`

The objects of this class are cloneable with this method.

#### Usage

    ConceptSetManifest$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
