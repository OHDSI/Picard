# Import CIRCE Cohort Definitions from ATLAS

Imports CIRCE JSON cohort definitions from ATLAS and registers them in
the manifest. This is a wrapper around
[CohortManifest](https://ohdsi.github.io/Picard/reference/CohortManifest.md)`$importAtlasCohorts()`.

## Usage

``` r
importAtlasCohorts(
  atlasConnection,
  manifestPath = here::here("inputs/cohorts/cohortManifest.sqlite"),
  cohortsLoadPath = here::here("inputs/cohorts/cohortsLoad.csv")
)
```

## Arguments

- atlasConnection:

  An ATLAS connection object.

- manifestPath:

  Character. Path to the cohort manifest database.

- cohortsLoadPath:

  Character. Path to the CSV file containing cohort metadata.

## Value

Invisibly returns a tibble with import results.

## Note

Deprecated. Use
[CohortManifest](https://ohdsi.github.io/Picard/reference/CohortManifest.md)`$importAtlasCohorts()`
directly.
