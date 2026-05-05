# Pivot Data Wide for Comparison

Pivots data from long to wide format for cross-database or cross-group
comparison. Common use case: compare cohort counts across databases.

## Usage

``` r
pivotForComparison(
  data,
  id_cols,
  names_from,
  values_from,
  names_prefix = "",
  values_fill = NA
)
```

## Arguments

- data:

  Data frame in long format

- id_cols:

  Character vector of column(s) identifying rows

- names_from:

  Character. Column to pivot into new column names

- values_from:

  Character. Column(s) to pivot into values

- names_prefix:

  Character. Prefix to add to new column names. Defaults to "".

- values_fill:

  Value to fill missing combinations. Defaults to NA.

## Value

Data frame in wide format, suitable for side-by-side comparison

## Details

This is a convenience wrapper around tidyr::pivot_wider() with sensible
defaults for comparison outputs. Common use:

    cohort_counts <- pivotForComparison(
      data = merged_counts,
      id_cols = "cohortId",
      names_from = "databaseId",
      values_from = "count",
      names_prefix = "count_"
    )
