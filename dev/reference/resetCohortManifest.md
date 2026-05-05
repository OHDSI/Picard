# Reset Cohort Manifest

Cleans up cohort manifest data at one of three scopes. All destructive
operations require the user to type `"yes"` at a confirmation prompt
(disable with `confirm = FALSE` for scripted use).

## Usage

``` r
resetCohortManifest(
  manifest = NULL,
  cohortsFolderPath = here::here("inputs/cohorts"),
  scope = c("derived", "manifest", "full"),
  executionSettings = NULL,
  confirm = TRUE
)
```

## Arguments

- manifest:

  A `CohortManifest` R6 object. Required for `scope = "derived"`;
  optional for other scopes (extracts path and settings automatically
  when provided).

- cohortsFolderPath:

  Character. Path to the cohorts folder. Inferred from `manifest` when
  provided; otherwise defaults to `here::here("inputs/cohorts")`.

- scope:

  Character. One of `"derived"`, `"manifest"`, or `"full"`. Defaults to
  `"derived"`.

- executionSettings:

  An `ExecutionSettings` object. Required for `scope = "full"` to drop
  OMOP cohort tables. If `manifest` is provided and already has settings
  attached, those are used automatically; this argument overrides them.

- confirm:

  Logical. If `TRUE` (default), the user must type `"yes"` to proceed.
  Set to `FALSE` for non-interactive use.

## Value

Invisibly returns NULL.

## Scope options

- `"derived"`:

  Removes all derived cohort rows from the SQLite database (union,
  subset, complement, composite) and deletes the `derived/` folder. Base
  cohorts (circe, custom) and their files are untouched. Use when
  rebuilding the derived pipeline with new parameters. Requires a live
  `manifest` object.

- `"manifest"`:

  Deletes the SQLite database and the `derived/` folder. Source files in
  `json/` and `sql/` are preserved and can be re-registered after
  [`initCohortManifest()`](https://ohdsi.github.io/Picard/dev/reference/initCohortManifest.md).

- `"full"`:

  Deletes the SQLite database, `derived/`, `json/`, `sql/`, and
  `cohortsLoad.csv`. Also drops OMOP cohort tables from the database
  (requires `executionSettings`).
