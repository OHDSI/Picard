# Launch Interactive Concept Set Load Editor

Opens an interactive Shiny application for creating, viewing and editing
the concept sets load metadata file (conceptSetsLoad.csv). This allows
you to add, remove, and modify concept set metadata including labels,
tags, domain, and ATLAS IDs without manually editing the CSV file.

## Usage

``` r
launchConceptSetsLoadEditor(
  conceptSetsFolderPath = here::here("inputs/conceptSets")
)
```

## Arguments

- conceptSetsFolderPath:

  Character. Path to conceptSets folder where conceptSetsLoad.csv will
  be saved. Defaults to "inputs/conceptSets".

## Value

Invisibly launches a Shiny app. Saves conceptSetsLoad.csv when the user
user clicks "Save".

## Details

**Features:**

- View existing concept sets in a data table

- Edit cells directly in the table

- Add new concept sets rows with form inputs

- Delete selected rows

- Save to conceptSetsLoad.csv

- Input validation for required fields

**Table Columns:**

- `atlasId`: ATLAS cohort definition ID (numeric)

- `label`: Cohort name/label (character) - editing updates file_name
  automatically

- `category`: Broad category (character)

- `subCategory`: Sub-category (character)

- `sourceCode`: Whether this concept set represents source codes
  (TRUE/FALSE)

- `domain`: OMOP domain (drug_exposure, condition_occurrence,
  measurement, procedure)

- `file_name`: Auto-generated as `json/{label}.json` (read-only)

**Workflow:**

1.  Call this function to launch the editor app

2.  Add/edit concept sets as needed

3.  Click "Save Concept Set Load File" to save to
    inputs/conceptSets/conceptSetsLoad.csv

4.  Use
    [`importAtlasConceptSets()`](https://ohdsi.github.io/Picard/reference/importAtlasConceptSets.md)
    to import conceptSets from ATLAS

5.  Use
    [`loadConceptSetManifest()`](https://ohdsi.github.io/Picard/reference/loadConceptSetManifest.md)
    to load the imported conceptSets

## Examples

``` r
if (FALSE) {
  # Launch the concept set load editor
  launchConceptSetsLoadEditor()
}
```
