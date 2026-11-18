# Launch Interactive Cohort Load File Editor

Opens an interactive Shiny application for creating, viewing and editing
the cohort load metadata file (cohortsLoad.csv). This allows you to add,
remove, and modify cohort metadata including labels, tags, and ATLAS IDs
without manually editing the CSV file.

## Usage

``` r
launchCohortsLoadEditor(cohortsFolderPath = here::here("inputs/cohorts"))
```

## Arguments

- cohortsFolderPath:

  Character. Path to the cohorts folder where cohortsLoad.csv will be
  saved. Defaults to "inputs/cohorts".

## Value

Invisibly launches a Shiny app. Saves cohortsLoad.csv when the user user
clicks "Save".

## Details

**Features:**

- View existing cohorts in a data table

- Edit cells directly in the table

- Add new cohort rows with form inputs

- Delete selected rows

- Save to cohortsLoad.csv

- Input validation for required fields

**Table Columns:**

- `atlasId`: ATLAS cohort definition ID (numeric)

- `label`: Cohort name/label (character) - editing updates file_name
  automatically

- `category`: Broad category (character)

- `subCategory`: Sub-category (character)

- `file_name`: Auto-generated as `json/{label}.json` (read-only)

**Workflow:**

1.  Call this function to launch the editor app

2.  Add/edit cohorts as needed

3.  Click "Save Cohort Load File" to save to
    inputs/cohorts/cohortsLoad.csv

4.  Use
    [`importAtlasCohorts()`](https://ohdsi.github.io/Picard/reference/importAtlasCohorts.md)
    to import cohorts from ATLAS

5.  Use
    [`loadCohortManifest()`](https://ohdsi.github.io/Picard/reference/loadCohortManifest.md)
    to load the imported cohorts

## Examples

``` r
if (FALSE) {
  # Launch the editor app
  launchCohortsLoadEditor()
}
```
