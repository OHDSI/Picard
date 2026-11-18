# Update the Label, Category, and/or Tags of an Existing Cohort Manifest

Updates `label`, `category`, `tags`, or any combination on any cohort
present in the manifest. Changes are applied to both the in-memory
object and the SQLite database.

## Usage

``` r
updateCohortManifest(
  manifest,
  cohortId,
  label = NULL,
  category = NULL,
  tags = NULL
)
```

## Arguments

- manifest:

  A `CohortManifest` object.

- cohortId:

  Integer. The ID of the cohort to update.

- label:

  Character or `NULL`. New label. If `NULL`, the existing label is kept.

- category:

  Character or `NULL`. New category (e.g., 'target', 'outcome',
  'exposure'). If `NULL`, the existing category is kept.

- tags:

  Named list or `NULL`. New tags. If `NULL`, the existing tags are kept.

## Value

Invisibly returns `NULL`.
