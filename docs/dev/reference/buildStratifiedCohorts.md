# Split a Base Cohort into Multiple Stratified Sub-Cohorts

Splits a single base cohort into N named stratum cohorts plus an
automatic **Unclassified** cohort containing subjects that match none of
the named strata. Each stratum is registered as a separate entry in the
manifest with an auto-assigned ID and `cohortType = "subset"`. A single
SQL file is written per stratum so
[`generateCohorts()`](https://ohdsi.github.io/Picard/dev/reference/generateCohorts.md)
processes them independently.

## Usage

``` r
buildStratifiedCohorts(baseCohortId, strata, labelPrefix = NULL, manifest)
```

## Arguments

- baseCohortId:

  Integer. The cohort definition ID to split.

- strata:

  Named list. Each element is either a named list of demographic filters
  or a character string SQL WHERE condition. Names become cohort labels
  (optionally prefixed by `labelPrefix`).

- labelPrefix:

  Character or `NULL`. If provided, prepended to each stratum name with
  a `-` separator (e.g. `"CKD"` + `"Male"` → `"CKD - Male"`).

- manifest:

  A `CohortManifest` object. Required. Cohort IDs are auto-assigned from
  the next available manifest ID — never supply them manually.

## Value

Invisibly returns a named list of cohort IDs, keyed by the full cohort
label.

## Details

Strata can be defined in two ways and may be mixed in the same call:

**Demographic (named list):**

    list(
      "Male"   = list(genderConceptIds = 8507),
      "Female" = list(genderConceptIds = 8532),
      "65+"    = list(minAge = 65)
    )

Supported keys: `genderConceptIds`, `raceConceptIds`,
`ethnicityConceptIds`, `minAge`, `maxAge`. Multiple keys within one
stratum are `AND`-ed.

**Custom SQL WHERE clause (character string):**

    list(
      "West"  = "p.location_id IN (1, 4, 5, 6, 12)",
      "South" = "p.location_id IN (2, 3, 8, 9, 10)"
    )

The expression may reference `bc` (cohort table alias) and `p` (person
table alias).

An **Unclassified** stratum is always appended automatically. Its WHERE
condition is the logical negation of every named stratum combined with
`AND NOT (...)`, ensuring every subject in the base cohort appears in
exactly one output cohort.
