# Expand JSON Tags to Columns

Takes a manifest dataframe (from `tabulateManifest()`,
`queryConceptSetsByTag()`, etc.) and pivots the JSON tags column into
separate columns. Each tag key becomes a column name, and the values
populate the rows.

## Usage

``` r
expandManifestTags(df, dropTagsCol = TRUE)
```

## Arguments

- df:

  Data frame. A manifest output dataframe with a `tags` column
  containing JSON strings (e.g., from
  `ConceptSetManifest$tabulateManifest()` or
  `ConceptSetManifest$queryConceptSetsByTag()`).

- dropTagsCol:

  Logical. If TRUE, drops the original `tags` column after expansion.
  Defaults to TRUE.

## Value

Data frame. The input dataframe with JSON tags expanded into separate
columns. Rows with NA tags are preserved with NA values in the new
columns.

## Details

This function:

1.  Parses each JSON string in the tags column using
    [`jsonlite::fromJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html)

2.  Extracts all unique keys across all JSON objects

3.  Creates new columns for each key

4.  Populates values, with NA for missing keys in any row

5.  Optionally drops the original JSON tags column

**Example:** Input dataframe:

    id | label | tags
    1  | CS1   | {"category":"drug","subCategory":"steroid","domain":"drug_exposure"}
    2  | CS2   | {"category":"covariate","domain":"condition_occurrence"}

Output dataframe:

    id | label | category  | subCategory | domain
    1  | CS1   | drug      | steroid     | drug_exposure
    2  | CS2   | covariate | NA          | condition_occurrence
