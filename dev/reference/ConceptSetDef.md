# ConceptSetDef R6 Class

ConceptSetDef R6 Class

ConceptSetDef R6 Class

## Details

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

- `tags`:

  list of the values to set the tags to. If missing, returns the current
  tags.

## Methods

### Public methods

- [`ConceptSetDef$new()`](#method-ConceptSetDef-new)

- [`ConceptSetDef$getFilePath()`](#method-ConceptSetDef-getFilePath)

- [`ConceptSetDef$getJson()`](#method-ConceptSetDef-getJson)

- [`ConceptSetDef$getHash()`](#method-ConceptSetDef-getHash)

- [`ConceptSetDef$getId()`](#method-ConceptSetDef-getId)

- [`ConceptSetDef$setId()`](#method-ConceptSetDef-setId)

- [`ConceptSetDef$formatTagsAsString()`](#method-ConceptSetDef-formatTagsAsString)

- [`ConceptSetDef$clone()`](#method-ConceptSetDef-clone)

------------------------------------------------------------------------

### Method `new()`

Initialize a new ConceptSetDef

#### Usage

    ConceptSetDef$new(label, tags = list(), filePath, domain = "init")

#### Arguments

- `label`:

  Character. The common name of the concept set.

- `tags`:

  List. A named list of tags that give metadata about the concept set.

- `filePath`:

  Character. Path to the concept set JSON file in inputs/conceptSet
  folder.

- `domain`:

  Character. The OMOP CDM clinical domain for this concept set. Valid
  values: "drug_exposure", "condition_occurrence", "measurement",
  "procedure", "observation", "device_exposure", "visit_occurrence",
  "init". Get the file path

- `sourceCode`:

  Logical. Whether the concept set uses source concepts (TRUE) or
  standard concepts (FALSE).

------------------------------------------------------------------------

### Method `getFilePath()`

#### Usage

    ConceptSetDef$getFilePath()

#### Returns

Character. Relative path to the concept set file. Get the concept set
JSON

------------------------------------------------------------------------

### Method `getJson()`

#### Usage

    ConceptSetDef$getJson()

#### Returns

Character. The JSON definition of the concept set. Get the JSON hash

------------------------------------------------------------------------

### Method `getHash()`

#### Usage

    ConceptSetDef$getHash()

#### Returns

Character. MD5 hash of the current JSON definition. Get the concept set
ID

------------------------------------------------------------------------

### Method `getId()`

#### Usage

    ConceptSetDef$getId()

#### Returns

Integer. The concept set ID, or NA_integer\_ if not set. Set the concept
set ID (internal use)

------------------------------------------------------------------------

### Method `setId()`

#### Usage

    ConceptSetDef$setId(id)

#### Arguments

- `id`:

  Integer. The concept set ID to set. Format tags as string

------------------------------------------------------------------------

### Method `formatTagsAsString()`

#### Usage

    ConceptSetDef$formatTagsAsString()

#### Returns

Character. Tags formatted as "name: value \| name: value".

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    ConceptSetDef$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
