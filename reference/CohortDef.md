# CohortDef R6 Class

CohortDef R6 Class

CohortDef R6 Class

## Details

An R6 class that stores key information about cohorts managed by the
CohortManifest. Each CohortDef is a pointer to a file on disk (JSON or
SQL) with associated metadata.

The CohortDef class manages cohort metadata and SQL generation. Upon
initialization, it loads and validates cohort definitions from either
JSON (CIRCE format) or SQL files, and creates a hash to uniquely
identify the generated SQL.

## Active bindings

- `label`:

  character to set the label to. If missing, returns the current label.

- `tags`:

  list of the values to set the tags to. If missing, returns the current
  tags.

- `category`:

  character to set the category to. If missing, returns the current
  category.

## Methods

### Public methods

- [`CohortDef$new()`](#method-CohortDef-new)

- [`CohortDef$getFilePath()`](#method-CohortDef-getFilePath)

- [`CohortDef$getSql()`](#method-CohortDef-getSql)

- [`CohortDef$getHash()`](#method-CohortDef-getHash)

- [`CohortDef$getId()`](#method-CohortDef-getId)

- [`CohortDef$setId()`](#method-CohortDef-setId)

- [`CohortDef$formatTagsAsString()`](#method-CohortDef-formatTagsAsString)

- [`CohortDef$getCohortType()`](#method-CohortDef-getCohortType)

- [`CohortDef$setCohortType()`](#method-CohortDef-setCohortType)

- [`CohortDef$getSourceType()`](#method-CohortDef-getSourceType)

- [`CohortDef$getCategory()`](#method-CohortDef-getCategory)

- [`CohortDef$setCategory()`](#method-CohortDef-setCategory)

- [`CohortDef$clone()`](#method-CohortDef-clone)

------------------------------------------------------------------------

### Method `new()`

Initialize a new CohortDef

#### Usage

    CohortDef$new(label, category, sourceType, tags = list(), filePath)

#### Arguments

- `label`:

  Character. The common name of the cohort.

- `category`:

  Character. Required classification (e.g., 'target', 'exposure',
  'outcome').

- `sourceType`:

  Character. Provenance: 'atlas', 'capr', 'sql', or 'derived'.

- `tags`:

  List. A named list of tags that give metadata about the cohort.

- `filePath`:

  Character. Path to the cohort file in inputs/cohorts folder (can be
  .json or .sql). Get the file path

------------------------------------------------------------------------

### Method `getFilePath()`

#### Usage

    CohortDef$getFilePath()

#### Returns

Character. Relative path to the cohort file. Get the generated SQL

------------------------------------------------------------------------

### Method `getSql()`

#### Usage

    CohortDef$getSql()

#### Returns

Character. The SQL definition of the cohort. Get the SQL hash

------------------------------------------------------------------------

### Method `getHash()`

#### Usage

    CohortDef$getHash()

#### Returns

Character. MD5 hash of the current SQL definition. Get the cohort ID

------------------------------------------------------------------------

### Method `getId()`

#### Usage

    CohortDef$getId()

#### Returns

Integer. The cohort ID, or NA_integer\_ if not set. Set the cohort ID
(internal use)

------------------------------------------------------------------------

### Method `setId()`

#### Usage

    CohortDef$setId(id)

#### Arguments

- `id`:

  Integer. The cohort ID to set. Format tags as string

------------------------------------------------------------------------

### Method `formatTagsAsString()`

#### Usage

    CohortDef$formatTagsAsString()

#### Returns

Character. Tags formatted as "name: value \| name: value". Get the
cohort type

------------------------------------------------------------------------

### Method `getCohortType()`

#### Usage

    CohortDef$getCohortType()

#### Returns

Character. One of 'circe', 'custom', 'subset', 'union', 'complement',
'composite'. Set the cohort type (internal use)

------------------------------------------------------------------------

### Method `setCohortType()`

#### Usage

    CohortDef$setCohortType(cohortType)

#### Arguments

- `cohortType`:

  Character. One of 'circe', 'custom', 'subset', 'union', 'complement',
  'composite'. Get the source type

------------------------------------------------------------------------

### Method `getSourceType()`

#### Usage

    CohortDef$getSourceType()

#### Returns

Character. One of 'atlas', 'capr', 'sql', 'derived'. Get the category

------------------------------------------------------------------------

### Method `getCategory()`

#### Usage

    CohortDef$getCategory()

#### Returns

Character. The cohort category (e.g., 'target', 'exposure', 'outcome').
Set the category

------------------------------------------------------------------------

### Method `setCategory()`

#### Usage

    CohortDef$setCategory(category)

#### Arguments

- `category`:

  Character. The cohort category.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    CohortDef$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
