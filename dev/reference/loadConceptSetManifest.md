# Load Concept Set Manifest

Loads a ConceptSetManifest R6 object from an existing SQLite database.
Scans the `json/` directory for new files not yet registered in the
manifest and auto-registers them.

## Usage

``` r
loadConceptSetManifest(
  conceptSetsFolderPath = here::here("inputs/conceptSets"),
  executionSettings = NULL,
  verbose = TRUE
)
```

## Arguments

- conceptSetsFolderPath:

  Character. Path to the conceptSets folder. Defaults to
  `here::here("inputs/conceptSets")`.

- executionSettings:

  ExecutionSettings object. Optional.

- verbose:

  Logical. If TRUE (default), prints informative messages.

## Value

ConceptSetManifest object.
