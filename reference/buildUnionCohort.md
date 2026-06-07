# Build a Union Cohort Definition

Creates a SQL file and metadata for a union cohort that combines
multiple input cohorts using a gaps-and-islands collapse algorithm.
Overlapping or adjacent eras are merged into continuous periods. Returns
a CohortDef object ready to add to a CohortManifest.

## Usage

``` r
buildUnionCohort(
  label,
  cohortIds,
  gapDays = 0L,
  eraPadDays = 0L,
  minEraDays = 0L,
  minCohorts = 1L,
  washoutDays = 0L,
  firstEraOnly = FALSE,
  manifest
)
```

## Arguments

- label:

  Character. User-friendly name for the union (e.g., "Chronic Kidney
  Disease Phenotypes")

- cohortIds:

  Numeric vector (minimum 2). Cohort IDs to union.

- gapDays:

  Integer. Bridge eras separated by up to this many days. Default: 0
  (only overlapping periods collapse).

- eraPadDays:

  Integer. Expand each source period by this many days on each end
  before collapsing. Applied to individual periods, not the collapsed
  result. Default: 0.

- minEraDays:

  Integer. Drop collapsed eras shorter than this many days. Default: 0
  (keep all eras).

- minCohorts:

  Integer. Only include subjects appearing in at least this many
  distinct source cohorts. Default: 1 (any subject from any cohort).

- washoutDays:

  Integer. Require a clean period of at least this many days before a
  new era can open. Subjects must have no source cohort membership for
  this period. Default: 0.

- firstEraOnly:

  Logical. Return only the first collapsed era per subject. Default:
  FALSE.

- manifest:

  CohortManifest object. Required. Validates that all input cohorts
  exist.

## Value

A CohortDef object with cohortType='union' and dependencies set.

## Details

Creates two files:

- SQL file:
  `inputs/cohorts/derived/union/union_cohorts_{cohort_id_list}.sql`

- Metadata JSON: Same path with `.json` extension
