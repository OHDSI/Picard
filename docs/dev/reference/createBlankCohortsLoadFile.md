# Create Blank Cohorts Load File

Creates a blank cohortsLoad.csv template file in the specified folder
with proper column structure.

## Usage

``` r
createBlankCohortsLoadFile(cohortsFolderPath = here::here("inputs/cohorts"))
```

## Arguments

- cohortsFolderPath:

  Character. Path where the blank file will be created. Defaults to
  `here::here("inputs/cohorts")`. Creates the folder if it doesn't
  exist.

## Value

Invisibly returns the file path.
