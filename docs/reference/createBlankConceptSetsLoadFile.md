# Create Blank Concept Sets Load File

Creates a blank conceptSetsLoad.csv template file in the specified
folder.

## Usage

``` r
createBlankConceptSetsLoadFile(
  conceptSetsFolderPath = here::here("inputs/conceptSets"),
  openFile = TRUE
)
```

## Arguments

- conceptSetsFolderPath:

  Character. Path to the conceptSets folder. Defaults to
  `here::here("inputs/conceptSets")`.

- openFile:

  Logical. If TRUE, opens the created file in the editor. Defaults to
  TRUE.

## Value

Invisibly returns the file path.
