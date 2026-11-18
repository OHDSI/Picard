# Define (Enrich) a Custom SQL Cohort (Deprecated)

**Deprecated.** Use
[CohortManifest](https://ohdsi.github.io/Picard/reference/CohortManifest.md)`$addSqlCohort()`
instead, which registers a custom SQL cohort with the correct label,
category, and tags in a single step.

## Usage

``` r
defineCustomCohort(
  manifest,
  label,
  tags = list(),
  cohortId = NULL,
  sqlFilePath = NULL
)
```

## Arguments

- manifest:

  A
  [CohortManifest](https://ohdsi.github.io/Picard/reference/CohortManifest.md)
  R6 object.

- label:

  Character. The user-friendly display name.

- tags:

  Named list. Optional metadata tags. Defaults to
  [`list()`](https://rdrr.io/r/base/list.html).

- cohortId:

  Integer. The cohort ID in the manifest.

- sqlFilePath:

  Character. Path to the SQL file.

## Value

Invisibly returns `NULL`.
