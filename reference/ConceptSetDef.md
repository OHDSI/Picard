# ConceptSetDef R6 Class

An R6 class that stores key information about OHDSI CIRCE concept sets
that need to be managed in a study.

The ConceptSetDef class manages concept set metadata, JSON definitions,
and domain information. Upon initialization, it loads and validates
concept set definitions from CIRCE JSON files, creates a hash to
uniquely identify the generated JSON, and stores domain and source
concept information.

## Active bindings

- `label`:

  character to set the label to. If missing, returns the current label.

- `category`:

  character to set the category to. If missing, returns the current
  category.

- `tags`:

  list of the values to set the tags to. If missing, returns the current
  tags.

## Methods

### Public methods

- [`ConceptSetDef$new()`](#method-ConceptSetDef-initialize)

- [`ConceptSetDef$getFilePath()`](#method-ConceptSetDef-getFilePath)

- [`ConceptSetDef$getDisplayPath()`](#method-ConceptSetDef-getDisplayPath)

- [`ConceptSetDef$getJson()`](#method-ConceptSetDef-getJson)

- [`ConceptSetDef$getHash()`](#method-ConceptSetDef-getHash)

- [`ConceptSetDef$getId()`](#method-ConceptSetDef-getId)

- [`ConceptSetDef$setId()`](#method-ConceptSetDef-setId)

- [`ConceptSetDef$formatTagsAsString()`](#method-ConceptSetDef-formatTagsAsString)

- [`ConceptSetDef$clone()`](#method-ConceptSetDef-clone)

------------------------------------------------------------------------

### `ConceptSetDef$new()`

Initialize a new ConceptSetDef

#### Usage

    ConceptSetDef$new(label, category = "init", tags = list(), filePath)

#### Arguments

- `label`:

  Character. The common name of the concept set.

- `category`:

  Character. The category for this concept set.

- `tags`:

  List. A named list of tags that give metadata about the concept set.

- `filePath`:

  Character. Path to the concept set JSON file in inputs/conceptSet
  folder. Get the file path

------------------------------------------------------------------------

### `ConceptSetDef$getFilePath()`

#### Usage

    ConceptSetDef$getFilePath()

#### Returns

Character. Absolute path to the concept set file — safe to read
regardless of the current working directory. Get the file path for
display

------------------------------------------------------------------------

### `ConceptSetDef$getDisplayPath()`

#### Usage

    ConceptSetDef$getDisplayPath(root = NULL)

#### Arguments

- `root`:

  Character or NULL. Study repository root. When supplied, the path is
  returned relative to it (the form stored in the manifest); otherwise
  the absolute path is returned.

#### Returns

Character. A human-facing path. Get the concept set JSON

------------------------------------------------------------------------

### `ConceptSetDef$getJson()`

#### Usage

    ConceptSetDef$getJson()

#### Returns

Character. The JSON definition of the concept set. Get the JSON hash

------------------------------------------------------------------------

### `ConceptSetDef$getHash()`

#### Usage

    ConceptSetDef$getHash()

#### Returns

Character. MD5 hash of the current JSON definition. Get the concept set
ID

------------------------------------------------------------------------

### `ConceptSetDef$getId()`

#### Usage

    ConceptSetDef$getId()

#### Returns

Integer. The concept set ID, or NA_integer\_ if not set. Set the concept
set ID (internal use)

------------------------------------------------------------------------

### `ConceptSetDef$setId()`

#### Usage

    ConceptSetDef$setId(id)

#### Arguments

- `id`:

  Integer. The concept set ID to set. Format tags as string

------------------------------------------------------------------------

### `ConceptSetDef$formatTagsAsString()`

#### Usage

    ConceptSetDef$formatTagsAsString()

#### Returns

Character. Tags formatted as "name: value \| name: value".

------------------------------------------------------------------------

### `ConceptSetDef$clone()`

The objects of this class are cloneable with this method.

#### Usage

    ConceptSetDef$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
