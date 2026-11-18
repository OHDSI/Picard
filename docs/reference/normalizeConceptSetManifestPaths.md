# Normalize Legacy Concept Set Manifest File Paths

The concept-set counterpart of
[`normalizeCohortManifestPaths()`](https://ohdsi.github.io/Picard/reference/normalizeCohortManifestPaths.md).
Rewrites the `file_path` of every active row in
`conceptSetManifest.sqlite` so it is stored relative to the study
repository root. Only `file_path` changes — hashes, `status` and
timestamps are untouched, so this never registers as a definition
change.

## Usage

``` r
normalizeConceptSetManifestPaths(
  conceptSetsFolderPath = here::here("inputs/conceptSets"),
  dryRun = FALSE
)
```

## Arguments

- conceptSetsFolderPath:

  Character. Path to the conceptSets folder (or anywhere inside the
  study repository). Defaults to `here::here("inputs/conceptSets")`.

- dryRun:

  Logical. When `TRUE`, report what would change without writing.
  Defaults to `FALSE`.

## Value

Invisibly, a tibble with columns `id`, `old_path`, `new_path`, `status`
(one of `"rewritten"`, `"would_rewrite"`, `"unchanged"`, `"broken"`,
`"no_path"`).

## See also

[`findStudyProjectRoot()`](https://ohdsi.github.io/Picard/reference/findStudyProjectRoot.md),
[`loadConceptSetManifest()`](https://ohdsi.github.io/Picard/reference/loadConceptSetManifest.md)
