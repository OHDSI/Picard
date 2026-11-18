# Validate Cohort Results Completeness

Validates that all cohorts in the cohort key have results and checks for
non-enumeration. Compares expected cohorts from
cohortManifestSnapshot.csv against actual results to identify missing or
zero-count cohorts.

## Usage

``` r
validateCohortResults(
  exportPath = here::here("dissemination/export/merge"),
  resultsFileName = NULL
)
```

## Arguments

- exportPath:

  Character. Path to export folder containing results. Defaults to
  "dissemination/export/merge"

- resultsFileName:

  Character. Name of the results file to validate (e.g.,
  "cohortCounts.csv"). If NULL, searches for a file with cohort_id,
  cohort_entries, and cohort_subjects columns.

## Value

Data frame with columns:

- cohortId: The cohort ID

- label: Cohort label from cohortKey

- validationStatus: "OK", "ZeroCount", or "Missing"

- details: Additional information about the validation result

## Details

The function identifies three validation statuses:

- **OK**: Cohort exists in results with non-zero counts

- **ZeroCount**: Cohort exists but has zero entries or subjects

- **Missing**: Cohort in cohortKey but not found in results
  (non-enumerated)
