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

- [`ConceptSetManifest$queryConceptSetsByLabel()`](#method-ConceptSetManifest-queryConceptSetsByLabel)

- [`ConceptSetManifest$nConceptSets()`](#method-ConceptSetManifest-nConceptSets)

- [`ConceptSetManifest$getConceptSetById()`](#method-ConceptSetManifest-getConceptSetById)

- [`ConceptSetManifest$getConceptSetsByTag()`](#method-ConceptSetManifest-getConceptSetsByTag)

- [`ConceptSetManifest$getConceptSetsByLabel()`](#method-ConceptSetManifest-getConceptSetsByLabel)

- [`ConceptSetManifest$validateManifest()`](#method-ConceptSetManifest-validateManifest)

- [`ConceptSetManifest$getManifestStatus()`](#method-ConceptSetManifest-getManifestStatus)

- [`ConceptSetManifest$deleteConceptSet()`](#method-ConceptSetManifest-deleteConceptSet)

- [`ConceptSetManifest$permanentlyDeleteConceptSet()`](#method-ConceptSetManifest-permanentlyDeleteConceptSet)

- [`ConceptSetManifest$cleanupMissing()`](#method-ConceptSetManifest-cleanupMissing)

- [`ConceptSetManifest$syncManifest()`](#method-ConceptSetManifest-syncManifest)

- [`ConceptSetManifest$extractSourceCodes()`](#method-ConceptSetManifest-extractSourceCodes)

- [`ConceptSetManifest$extractIncludedCodes()`](#method-ConceptSetManifest-extractIncludedCodes)

- [`ConceptSetManifest$clone()`](#method-ConceptSetManifest-clone)

------------------------------------------------------------------------

### Method `new()`

Initialize a new ConceptSetManifest

#### Usage

    ConceptSetManifest$new(
      dbPath = "inputs/conceptSets/conceptSetManifest.sqlite",
      executionSettings = NULL
    )

#### Arguments

- `dbPath`:

  Character. Path to the SQLite database. Defaults to
  "inputs/conceptSets/conceptSetManifest.sqlite". The directory is
  created automatically if it does not exist.

- `executionSettings`:

  ExecutionSettings object. (Optional) Execution settings for accessing
  the vocabulary database. Defaults to NULL. Only required for
  operations like extractSourceCodes(). Get the manifest as a list of
  ConceptSetDef objects

------------------------------------------------------------------------

### Method `getManifest()`

#### Usage

    ConceptSetManifest$getManifest()

#### Returns

List. A list of ConceptSetDef objects in the manifest. Tabulate the
manifest as a data frame

------------------------------------------------------------------------

### Method `tabulateManifest()`

#### Usage

    ConceptSetManifest$tabulateManifest()

#### Returns

Data frame. Manifest data with columns: id, label, tags, filePath, hash,
timestamp Get the manifest path

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

### Method [`getAtlasConnection()`](https://ohdsi.github.io/Picard/dev/reference/getAtlasConnection.md)

#### Usage

    ConceptSetManifest$getAtlasConnection()

#### Returns

The ATLAS connection object, or NULL if not set. Set an ATLAS connection
for use by add/import methods

Stores a connection so it does not need to be passed to
`addAtlasConceptSet()` or
[`importAtlasConceptSets()`](https://ohdsi.github.io/Picard/dev/reference/importAtlasConceptSets.md)
on every call.

------------------------------------------------------------------------

### Method [`setAtlasConnection()`](https://ohdsi.github.io/Picard/dev/reference/setAtlasConnection.md)

#### Usage

    ConceptSetManifest$setAtlasConnection(atlasConnection)

#### Arguments

- `atlasConnection`:

  An ATLAS connection object (from
  [`getAtlasConnection()`](https://ohdsi.github.io/Picard/dev/reference/getAtlasConnection.md)).

#### Returns

Invisible self for method chaining.

------------------------------------------------------------------------

### Method `addConceptSetFile()`

Register a local CIRCE JSON file in the manifest

#### Usage

    ConceptSetManifest$addConceptSetFile(
      filePath,
      label,
      domain = "init",
      tags = list()
    )

#### Arguments

- `filePath`:

  Character. Absolute or relative path to a valid CIRCE JSON file.

- `label`:

  Character. Display name for the concept set.

- `domain`:

  Character. OMOP CDM domain. One of `"drug_exposure"`,
  `"condition_occurrence"`, `"measurement"`, `"procedure"`,
  `"observation"`, `"device_exposure"`, `"visit_occurrence"`, `"init"`.
  Defaults to `"init"`.

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
      domain = "init",
      tags = list(),
      atlasConnection = NULL
    )

#### Arguments

- `atlasId`:

  Integer. The ATLAS concept set definition ID.

- `label`:

  Character. Display name for the concept set.

- `domain`:

  Character. OMOP CDM domain. Defaults to `"init"`.

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
      domain = "init",
      tags = list()
    )

#### Arguments

- `caprConceptSet`:

  A Capr `ConceptSet` object.

- `label`:

  Character. Display name for the concept set.

- `domain`:

  Character. OMOP CDM domain. Defaults to `"init"`.

- `tags`:

  Named list. Optional extra metadata tags. Defaults to
  [`list()`](https://rdrr.io/r/base/list.html).

#### Returns

Invisible integer. The assigned concept set ID.

------------------------------------------------------------------------

### Method [`importAtlasConceptSets()`](https://ohdsi.github.io/Picard/dev/reference/importAtlasConceptSets.md)

Batch-import concept sets from ATLAS via a conceptSetsLoad CSV

Reads a CSV with columns `atlasId`, `label`, `domain` (required) plus
any additional columns treated as tag key-value pairs. Calls
`addAtlasConceptSet()` for each row inside a `tryCatch` so a single
failure does not abort the entire batch.

#### Usage

    ConceptSetManifest$importAtlasConceptSets(
      atlasConnection = NULL,
      conceptSetsLoadPath = here::here("inputs/conceptSets/conceptSetsLoad.csv")
    )

#### Arguments

- `atlasConnection`:

  An ATLAS connection object with a
  `getConceptSetDefinition(conceptSetId)` method. If `NULL`, falls back
  to the connection stored via `$setAtlasConnection()`.

- `conceptSetsLoadPath`:

  Character. Path to the CSV file. Defaults to
  `here::here("inputs/conceptSets/conceptSetsLoad.csv")`.

#### Returns

Invisible tibble with columns `id`, `label`, `status`. Query concept
sets by IDs

------------------------------------------------------------------------

### Method `queryConceptSetsByIds()`

#### Usage

    ConceptSetManifest$queryConceptSetsByIds(ids)

#### Arguments

- `ids`:

  Integer vector. One or more concept set IDs.

#### Returns

Data frame. A subset of the manifest with columns id, label, tags,
filePath, hash, timestamp for matching concept sets, or NULL if none
found. Query concept sets by tag

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

Data frame. A subset of the manifest with columns id, label, tags,
filePath, hash, timestamp for matching concept sets, or NULL if none
found. Query concept sets by label

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

Data frame. A subset of the manifest with columns id, label, tags,
filePath, hash, timestamp for matching concept sets, or NULL if none
found.

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

    ConceptSetManifest$deleteConceptSet(id, reason = NULL)

#### Arguments

- `id`:

  Integer. The concept set ID to delete.

- `reason`:

  Character. Optional reason for deletion.

#### Returns

Invisibly returns TRUE if successful, FALSE otherwise.

------------------------------------------------------------------------

### Method `permanentlyDeleteConceptSet()`

Permanently delete a concept set (removes the record from database,
irreversible)

#### Usage

    ConceptSetManifest$permanentlyDeleteConceptSet(id, confirm = FALSE)

#### Arguments

- `id`:

  Integer. The concept set ID to permanently remove.

- `confirm`:

  Logical. Must be TRUE to proceed; prevents accidental deletion.
  Defaults to FALSE.

#### Returns

Invisibly returns TRUE if successful, FALSE otherwise.

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

    ConceptSetManifest$syncManifest()

#### Returns

Data frame with columns: id, label, action (`"added"`, `"hash_updated"`,
`"missing_flagged"`, or `"unchanged"`). Extract Source Codes for Concept
Sets

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
