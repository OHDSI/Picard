# ConceptSetManifest R6 Class

ConceptSetManifest R6 Class

ConceptSetManifest R6 Class

## Details

An R6 class that manages a collection of ConceptSetDef objects and
maintains metadata in a SQLite database.

The ConceptSetManifest class manages multiple concept set definitions
and stores their metadata in a SQLite database located at
inputs/conceptSets/conceptSetManifest.sqlite. Each ConceptSetDef is
assigned a sequential ID based on its position in the manifest.

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

1.  Retrieves the concept set definition (CIRCE JSON) by ID

2.  Builds SQL query using
    [`CirceR::buildConceptSetQuery()`](https://ohdsi.github.io/CirceR/reference/buildConceptSetQuery.html)

3.  Executes query against the OMOP vocabulary schema

4.  Returns results with concept_id and concept_name columns

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

4.  Prompts user to accept or override suggested vocabularies

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

- [`ConceptSetManifest$new()`](#method-ConceptSetManifest-new)

- [`ConceptSetManifest$getManifest()`](#method-ConceptSetManifest-getManifest)

- [`ConceptSetManifest$tabulateManifest()`](#method-ConceptSetManifest-tabulateManifest)

- [`ConceptSetManifest$getDbPath()`](#method-ConceptSetManifest-getDbPath)

- [`ConceptSetManifest$getExecutionSettings()`](#method-ConceptSetManifest-getExecutionSettings)

- [`ConceptSetManifest$setExecutionSettings()`](#method-ConceptSetManifest-setExecutionSettings)

- [`ConceptSetManifest$getAtlasConnection()`](#method-ConceptSetManifest-getAtlasConnection)

- [`ConceptSetManifest$setAtlasConnection()`](#method-ConceptSetManifest-setAtlasConnection)

- [`ConceptSetManifest$addConceptSetFile()`](#method-ConceptSetManifest-addConceptSetFile)

- [`ConceptSetManifest$addAtlasConceptSet()`](#method-ConceptSetManifest-addAtlasConceptSet)

- [`ConceptSetManifest$addCaprConceptSet()`](#method-ConceptSetManifest-addCaprConceptSet)

- [`ConceptSetManifest$importAtlasConceptSets()`](#method-ConceptSetManifest-importAtlasConceptSets)

- [`ConceptSetManifest$queryConceptSetsByIds()`](#method-ConceptSetManifest-queryConceptSetsByIds)

- [`ConceptSetManifest$queryConceptSetsByTag()`](#method-ConceptSetManifest-queryConceptSetsByTag)

- [`ConceptSetManifest$queryConceptSetsByTagName()`](#method-ConceptSetManifest-queryConceptSetsByTagName)

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

- [`ConceptSetManifest$checkAtlasConceptSets()`](#method-ConceptSetManifest-checkAtlasConceptSets)

- [`ConceptSetManifest$updateAtlasConceptSets()`](#method-ConceptSetManifest-updateAtlasConceptSets)

- [`ConceptSetManifest$cleanupMissing()`](#method-ConceptSetManifest-cleanupMissing)

- [`ConceptSetManifest$syncManifest()`](#method-ConceptSetManifest-syncManifest)

- [`ConceptSetManifest$grabConceptInfoFromSet()`](#method-ConceptSetManifest-grabConceptInfoFromSet)

- [`ConceptSetManifest$extractSourceCodes()`](#method-ConceptSetManifest-extractSourceCodes)

- [`ConceptSetManifest$extractIncludedCodes()`](#method-ConceptSetManifest-extractIncludedCodes)

- [`ConceptSetManifest$clone()`](#method-ConceptSetManifest-clone)

------------------------------------------------------------------------

### Method `new()`

Initialize a new ConceptSetManifest

#### Usage

    ConceptSetManifest$new(dbPath = "inputs/conceptSets/conceptSetManifest.sqlite")

#### Arguments

- `dbPath`:

  Character. Path to the SQLite database. Defaults to
  "inputs/conceptSets/conceptSetManifest.sqlite". The directory is
  created automatically if it does not exist. Get the manifest as a list
  of ConceptSetDef objects

------------------------------------------------------------------------

### Method `getManifest()`

#### Usage

    ConceptSetManifest$getManifest()

#### Returns

List. A list of ConceptSetDef objects in the manifest.

------------------------------------------------------------------------

### Method `tabulateManifest()`

Tabulate the manifest as a tibble

#### Usage

    ConceptSetManifest$tabulateManifest(filter = c("active", "deleted", "all"))

#### Arguments

- `filter`:

  Character. Controls which rows are returned. One of `"active"`
  (default), `"deleted"`, or `"all"`.

#### Returns

A tibble with columns: id, label, category, tags, file_path, hash,
source_type, cohort_type, status, created_at, deleted_at Get the
manifest path

------------------------------------------------------------------------

### Method `getDbPath()`

#### Usage

    ConceptSetManifest$getDbPath()

#### Returns

Character. The path to the SQLite database. Get the execution settings

------------------------------------------------------------------------

### Method `getExecutionSettings()`

#### Usage

    ConceptSetManifest$getExecutionSettings()

#### Returns

Object. The execution settings object for vocabulary access, or NULL if
not set. Set or update execution settings

------------------------------------------------------------------------

### Method `setExecutionSettings()`

#### Usage

    ConceptSetManifest$setExecutionSettings(executionSettings)

#### Arguments

- `executionSettings`:

  ExecutionSettings object for database access.

#### Returns

Invisibly returns self for method chaining. Get the stored ATLAS
connection

------------------------------------------------------------------------

### Method [`getAtlasConnection()`](https://ohdsi.github.io/Picard/reference/getAtlasConnection.md)

#### Usage

    ConceptSetManifest$getAtlasConnection()

#### Returns

The ATLAS connection object, or NULL if not set. Set an ATLAS connection
for use by add/import methods

Stores a connection so it does not need to be passed to
`addAtlasConceptSet()` or
[`importAtlasConceptSets()`](https://ohdsi.github.io/Picard/reference/importAtlasConceptSets.md)
on every call.

------------------------------------------------------------------------

### Method `setAtlasConnection()`

#### Usage

    ConceptSetManifest$setAtlasConnection(atlasConnection)

#### Arguments

- `atlasConnection`:

  An ATLAS connection object (from
  [`getAtlasConnection()`](https://ohdsi.github.io/Picard/reference/getAtlasConnection.md)).

#### Returns

Invisible self for method chaining.

------------------------------------------------------------------------

### Method `addConceptSetFile()`

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

### Method `addAtlasConceptSet()`

Fetch a single concept set from ATLAS and register it in the manifest

#### Usage

    ConceptSetManifest$addAtlasConceptSet(
      atlasId,
      label,
      category = "init",
      tags = list(),
      atlasConnection = NULL
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

#### Returns

Invisible integer. The assigned concept set ID.

------------------------------------------------------------------------

### Method `addCaprConceptSet()`

Export a Capr ConceptSet to JSON and register it in the manifest

#### Usage

    ConceptSetManifest$addCaprConceptSet(
      caprConceptSet,
      label,
      category = "init",
      tags = list()
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

#### Returns

Invisible integer. The assigned concept set ID.

------------------------------------------------------------------------

### Method [`importAtlasConceptSets()`](https://ohdsi.github.io/Picard/reference/importAtlasConceptSets.md)

Batch-import concept sets from ATLAS via a conceptSetsLoad dataframe

Either create a dataframe or read in a csv file with columns `atlasId`,
`label`, `category` (required) plus any additional columns treated as
tag key-value pairs for tags. Calls `addAtlasConceptSet()` for each row
inside a `tryCatch` so a single failure does not abort the entire batch.

#### Usage

    ConceptSetManifest$importAtlasConceptSets(
      conceptSetsLoad,
      atlasConnection = NULL
    )

#### Arguments

- `conceptSetsLoad`:

  a data frame requiring the columns atlasId, label and category used to
  bulk add cohorts to the manifest

- `atlasConnection`:

  An ATLAS connection object with a
  `getConceptSetDefinition(conceptSetId)` method. If `NULL`, falls back
  to the connection stored via `$setAtlasConnection()`.

#### Returns

Invisible tibble imported concept sets. Query concept sets by IDs

------------------------------------------------------------------------

### Method `queryConceptSetsByIds()`

#### Usage

    ConceptSetManifest$queryConceptSetsByIds(ids)

#### Arguments

- `ids`:

  Integer vector. One or more concept set IDs.

#### Returns

Tibble with columns: id, label, category, tags, file_path, hash,
created_at. Query concept sets by tag

------------------------------------------------------------------------

### Method `queryConceptSetsByTag()`

#### Usage

    ConceptSetManifest$queryConceptSetsByTag(tagStrings, match = c("any", "all"))

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

Tibble with columns: id, label, category, tags, file_path, hash,
created_at. Query cohorts by category

------------------------------------------------------------------------

### Method `queryConceptSetsByTagName()`

#### Usage

    ConceptSetManifest$queryConceptSetsByTagName(tagName)

#### Arguments

- `tagName`:

  Character vector. The name of tags to query

#### Returns

Tibble with columns: id, label, category, tags, file_path, hash,
source_type, created_at. Query concept sets by label

------------------------------------------------------------------------

### Method `queryConceptSetsByLabel()`

#### Usage

    ConceptSetManifest$queryConceptSetsByLabel(
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

Tibble with columns: id, label, category, tags, file_path, hash,
created_at.

------------------------------------------------------------------------

### Method `nConceptSets()`

Get number of concept sets in manifest

#### Usage

    ConceptSetManifest$nConceptSets()

#### Returns

Integer. The number of concept sets. Get a specific concept set by ID

------------------------------------------------------------------------

### Method `getConceptSetById()`

#### Usage

    ConceptSetManifest$getConceptSetById(id)

#### Arguments

- `id`:

  Integer. The concept set ID.

#### Returns

ConceptSetDef. The ConceptSetDef object with matching ID, or NULL if not
found. Get concept sets by tag

------------------------------------------------------------------------

### Method `getConceptSetsByTag()`

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

### Method `getConceptSetsByLabel()`

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

### Method `validateManifest()`

Validate manifest and return status of all concept sets

#### Usage

    ConceptSetManifest$validateManifest()

#### Returns

A tibble with columns: id, label, status (active/missing/deleted),
deleted_at, file_exists

------------------------------------------------------------------------

### Method `getManifestStatus()`

Get summary status of manifest

#### Usage

    ConceptSetManifest$getManifestStatus()

#### Returns

List with elements: active_count, missing_count, deleted_count,
next_available_id

------------------------------------------------------------------------

### Method `deleteConceptSet()`

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

### Method `combineConceptSets()`

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
      combinedTags = list()
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

#### Returns

Invisible integer. The ID of the newly created combined concept set.

------------------------------------------------------------------------

### Method `updateConceptSetLabel()`

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

### Method `updateConceptSetCategory()`

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

### Method `updateConceptSetTags()`

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

### Method `checkAtlasConceptSets()`

Auto-detect changes to ATLAS concept sets in remote repository

Queries the manifest for all active ATLAS concept sets (identified by
`atlasId` in tags), fetches their current definitions from ATLAS,
computes hashes, and compares against the stored local hash. Provides a
read-only summary of which concept sets have changed in ATLAS since
import. No modifications are made.

#### Usage

    ConceptSetManifest$checkAtlasConceptSets(atlasConnection = NULL)

#### Arguments

- `atlasConnection`:

  An ATLAS connection object with a method
  `getConceptSetDefinition(conceptSetId)` that returns a list with an
  `expression` element (the CIRCE JSON as a string). If `NULL`
  (default), uses the connection stored via `$setAtlasConnection()`. If
  no connection is available, raises an error.

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

### Method `updateAtlasConceptSets()`

Update ATLAS concept sets with remote definitions

Fetches current definitions from ATLAS for concept sets that have
changed and updates the stored JSON files and manifest entries. This is
the modification phase that applies changes detected by
checkAtlasConceptSets().

#### Usage

    ConceptSetManifest$updateAtlasConceptSets(atlasConnection = NULL)

#### Arguments

- `atlasConnection`:

  An ATLAS connection object with a method
  `getConceptSetDefinition(conceptSetId)`. If `NULL` (default), uses the
  connection stored via `$setAtlasConnection()`.

#### Returns

Invisible tibble of concept sets that were updated, with columns: id,
label, atlasId, filePath, hasChanged, localHash, remoteHash

------------------------------------------------------------------------

### Method `cleanupMissing()`

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

### Method `syncManifest()`

Scans the `json/` subdirectory of the concept sets folder, reconciles it
against the SQLite manifest, and updates both the database and the
in-memory list:

- New files found on disk are added (new ConceptSetDef + manifest
  entry).

- Active manifest records whose file no longer exists are soft-deleted.

- Existing files whose JSON hash has changed are updated in the
  manifest.

#### Usage

    ConceptSetManifest$syncManifest(strict_mode = TRUE)

#### Arguments

- `strict_mode`:

  Logical. If TRUE (default), automatically removes orphaned files found
  on disk. If FALSE, only warns about them without deletion. Default:
  TRUE.

#### Returns

Data frame with columns: id, label, action (`"added"`, `"hash_updated"`,
`"missing_flagged"`, or `"unchanged"`).

------------------------------------------------------------------------

### Method `grabConceptInfoFromSet()`

Retrieve concept information for all concepts in a concept set

Fetches the standard concepts included in a concept set from the OMOP
vocabulary tables. The concept set definition (stored as CIRCE JSON) is
used to build a query that retrieves all concept IDs and names matching
the set definition. Results are returned as a tibble with concept
identifiers and display names.

#### Usage

    ConceptSetManifest$grabConceptInfoFromSet(conceptSetId)

#### Arguments

- `conceptSetId`:

  Integer. The concept set ID in the manifest.

#### Returns

Tibble with columns:

- `conceptId`: Integer, the OMOP concept identifier

- `conceptName`: Character, the concept name from the vocabulary

------------------------------------------------------------------------

### Method `extractSourceCodes()`

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
  on the domains of your concept sets and prompt you to use them.

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

### Method `extractIncludedCodes()`

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

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    ConceptSetManifest$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
