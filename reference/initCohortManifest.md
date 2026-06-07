# Initialize a New Cohort Manifest

Creates a blank `cohortManifest.sqlite` database with the new schema.
Directory creation (`json/`, `sql/`, `derived/`) is handled by the study
repo initialization (see `listDefaultFolders()` in `R/Ulysses.R`).

## Usage

``` r
initCohortManifest(path = "inputs/cohorts")
```

## Arguments

- path:

  Character. Path to the cohorts folder where the SQLite file will be
  created. Defaults to `"inputs/cohorts"`.

## Value

A `CohortManifest` R6 object (empty, ready for `$add*()` calls).
