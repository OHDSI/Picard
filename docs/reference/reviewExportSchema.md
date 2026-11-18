# Review Export File Schema

Examines all CSV files in the export folder and extracts schema
information (column names and data types). Useful for identifying ETL
requirements before dissemination.

## Usage

``` r
reviewExportSchema(exportPath = here::here("dissemination/export/merge"))
```

## Arguments

- exportPath:

  Character. Path to the export folder containing merged results.
  Defaults to "dissemination/export/merge"

## Value

Data frame with columns:

- fileName: Name of the CSV file

- columnName: Name of the column

- dataType: R data type as detected by readr (character, numeric,
  logical, etc.)

- rowCount: Number of rows in the file

## Details

This function helps identify:

- Column naming inconsistencies across files

- Unexpected data types that may need transformation

- Columns that should be renamed or restructured

- Data quality issues (e.g., columns with mostly NAs)

The data frame can be sorted/filtered to understand transformation
requirements.

## Examples

``` r
if (FALSE) { # \dontrun{
  schema <- reviewExportSchema()
  
  # View all columns and types
  print(schema)
  
  # Check for character columns that should be numeric
  schema[schema$dataType == "character", ]
  
  # Get distinct data types per file
  schema |>
    dplyr::group_by(fileName) |>
    dplyr::summarise(colCount = dplyr::n(), .groups = "drop")
} # }
```
