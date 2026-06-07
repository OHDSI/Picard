# Load Cohort Manifest from SQLite Database

Loads a CohortManifest R6 object from an existing
`cohortManifest.sqlite` database. This is a pure read from SQLite — it
does not scan directories or auto-add new files. If new files exist on
disk that aren't in the manifest, a warning is printed suggesting the
appropriate `$add*()` method.

## Usage

``` r
loadCohortManifest(
  cohortsFolderPath = here::here("inputs/cohorts"),
  executionSettings = NULL,
  verbose = TRUE
)
```

## Arguments

- cohortsFolderPath:

  Character. Path to the cohorts folder containing the manifest
  database. Defaults to `here::here("inputs/cohorts")`.

- executionSettings:

  An ExecutionSettings object containing database configuration for
  cohort generation. Optional; can be added later using
  `$setExecutionSettings()`.

- verbose:

  Logical. If TRUE, prints informative messages. Defaults to TRUE.

## Value

A CohortManifest R6 object.

## Details

If no SQLite database exists at the expected path, the function stops
with an error directing the user to
[`initCohortManifest()`](https://ohdsi.github.io/Picard/reference/initCohortManifest.md).

After loading, the function checks for new files in `json/`, `sql/`, and
`derived/` directories that are not tracked in the manifest. These are
reported as warnings but NOT auto-added (because `category` is required
and cannot be guessed).
