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
  This affects file/row reconciliation only — it is not related to path
  resolution, and FALSE is not a workaround for a manifest that fails to
  load.

- verbose:

  Logical. If TRUE (default), prints informative messages.

## Value

ConceptSetManifest object.

## Details

Concept-set file paths are stored **relative to the study repository
root**, so a manifest loads identically on any machine and from any
working directory. Manifests created before this convention may hold
working-directory-relative, manifest-folder-relative, or absolute paths;
those still resolve through a compatibility fallback, and
[`normalizeConceptSetManifestPaths()`](https://ohdsi.github.io/Picard/reference/normalizeConceptSetManifestPaths.md)
rewrites them to the current convention in one explicit pass. Ordinary
loads never modify the SQLite file.

## See also

[`normalizeConceptSetManifestPaths()`](https://ohdsi.github.io/Picard/reference/normalizeConceptSetManifestPaths.md),
[`findStudyProjectRoot()`](https://ohdsi.github.io/Picard/reference/findStudyProjectRoot.md)
