# Update the Label and/or Tags of an Existing Manifest Cohort

Updates `label`, `tags`, or both on any cohort present in the manifest.
Changes are applied to both the in-memory object and the SQLite
database.

## Usage

``` r
updateCohortMetadata(manifest, cohortId, label = NULL, tags = NULL)
```

## Arguments

- manifest:

  A `CohortManifest` object.

- cohortId:

  Integer. The ID of the cohort to update.

- label:

  Character or `NULL`. New label. If `NULL`, the existing label is kept.

- tags:

  Named list or `NULL`. New tags. If `NULL`, the existing tags are kept.

## Value

Invisibly returns `NULL`.
