# Create Blank Cohorts Load File

Creates a blank cohortsLoad.csv template file in the specified folder
with proper column structure.

## Usage

``` r
createBlankCohortsLoadFile(
  cohortsFolderPath = here::here("inputs/cohorts"),
  openFile = TRUE
)
```

## Arguments

- cohortsFolderPath:

  Character. Path where the blank file will be created. Defaults to
  `here::here("inputs/cohorts")`. Creates the folder if it doesn't
  exist.

- openFile:

  Logical. If TRUE, opens the created file in the editor. Defaults to
  TRUE.

## Value

Invisibly returns the file path.
