# Build a Demographic Subset Cohort

**\[deprecated\]** Use `manifest$buildDemographicCohort()` instead.

## Usage

``` r
buildSubsetCohortDemographic(
  label,
  baseCohortId,
  minAge = NULL,
  maxAge = NULL,
  genderConceptIds = NULL,
  raceConceptIds = NULL,
  ethnicityConceptIds = NULL,
  manifest
)
```

## Arguments

- label:

  Character. User-friendly name for the subset (e.g., "CKD - Males
  40-75")

- baseCohortId:

  Integer. The cohort ID to subset.

- minAge:

  Integer. Minimum age at cohort start. NULL = no minimum. Default: NULL

- maxAge:

  Integer. Maximum age at cohort start. NULL = no maximum. Default: NULL

- genderConceptIds:

  Numeric vector. Gender concept IDs to include. NULL = all. Default:
  NULL

- raceConceptIds:

  Numeric vector. Race concept IDs to include. NULL = all. Default: NULL

- ethnicityConceptIds:

  Numeric vector. Ethnicity concept IDs to include. NULL = all. Default:
  NULL

- manifest:

  CohortManifest object. Required.

## Value

Invisible integer. The assigned cohort ID.
