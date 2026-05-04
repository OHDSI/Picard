# Reset Concept Set Manifest

Cleans up concept set manifest data at one of two scopes. All
destructive operations require the user to type `"yes"` at a
confirmation prompt (disable with `confirm = FALSE` for scripted use).

## Usage

``` r
resetConceptSetManifest(
  manifest = NULL,
  conceptSetsFolderPath = here::here("inputs/conceptSets"),
  scope = c("manifest", "full"),
  confirm = TRUE
)
```

## Arguments

- manifest:

  A `ConceptSetManifest` R6 object. Optional; when provided the folder
  path is inferred automatically.

- conceptSetsFolderPath:

  Character. Path to the conceptSets folder. Inferred from `manifest`
  when provided; otherwise defaults to
  `here::here("inputs/conceptSets")`.

- scope:

  Character. One of `"manifest"` (default) or `"full"`.

- confirm:

  Logical. If `TRUE` (default), the user must type `"yes"` to proceed.
  Set to `FALSE` for non-interactive use.

## Value

Invisibly returns NULL.

## Details

Unlike cohort manifests, all concept set JSON files are user-owned
sources (nothing is auto-generated), so there is no "derived" tier.

## Scope options

- `"manifest"` (default):

  Deletes only the SQLite database. JSON files in `json/` are preserved.
  On the next call to
  [`loadConceptSetManifest()`](https://ohdsi.github.io/Picard/reference/loadConceptSetManifest.md),
  those files are automatically re-registered — no manual `$add*()`
  calls required.

- `"full"`:

  Deletes the SQLite database, the `json/` folder, and
  `conceptSetsLoad.csv`. Complete wipe.
