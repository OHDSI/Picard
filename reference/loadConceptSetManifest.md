# Load Concept Set Manifest

Loads a ConceptSetManifest R6 object from an existing SQLite database.
By default, automatically syncs the manifest to ensure 1:1
correspondence between SQLite and the file system.

## Usage

``` r
loadConceptSetManifest(
  conceptSetsFolderPath = here::here("inputs/conceptSets"),
  executionSettings = NULL,
  autoSync = TRUE,
  verbose = TRUE
)
```

## Arguments

- conceptSetsFolderPath:

  Character. Path to the conceptSets folder. Defaults to
  `here::here("inputs/conceptSets")`.

- executionSettings:

  ExecutionSettings object. Optional.

- autoSync:

  Logical. If TRUE (default), syncs the manifest to reconcile files on
  disk with the SQLite database (removes orphaned files, flags missing).

- verbose:

  Logical. If TRUE (default), prints informative messages.

## Value

ConceptSetManifest object.
