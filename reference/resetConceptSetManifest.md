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
  archive = TRUE,
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

- archive:

  Logical. For `scope = "manifest"`, if `TRUE` (default), archives JSON
  files in `json/` to a timestamped directory instead of deleting them.
  Set to `FALSE` to delete without archiving.

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

  Deletes only the SQLite database. JSON files in `json/` are archived
  to a timestamped directory (unless `archive = FALSE`) and can be
  restored after
  [`initConceptSetManifest()`](https://ohdsi.github.io/Picard/reference/initConceptSetManifest.md)
  using `$addConceptSetFile()`.

- `"full"`:

  Deletes the SQLite database, the `json/` folder, and
  `conceptSetsLoad.csv`. Complete wipe.
