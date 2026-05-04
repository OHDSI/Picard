# Validate Required Columns in Results

Checks that a results data frame has the required columns: databaseId,
cohortId, cohortLabel

## Usage

``` r
validateResultsColumns(resultsData, stepName)
```

## Arguments

- resultsData:

  Data frame to validate

- stepName:

  Character. Name of the post-processing step (for error messages)

## Value

Logical. TRUE if valid, stops with error if not
