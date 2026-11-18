# Prepare Dissemination Data with Chained Transformations

Convenience function that chains common data preparation steps for
dissemination: cleaning names, formatting numbers, standardizing types.

## Usage

``` r
prepareDisseminationData(
  data,
  clean_names = TRUE,
  format_percentages = TRUE,
  format_floats = TRUE,
  standardize_types = TRUE,
  percent_decimal_places = 1,
  float_decimal_places = 2
)
```

## Arguments

- data:

  Data frame or tibble to prepare

- clean_names:

  Logical. Apply cleanColumnNames(). Defaults to TRUE.

- format_percentages:

  Logical. Apply formatPercentages(). Defaults to TRUE.

- format_floats:

  Logical. Apply formatFloats(). Defaults to TRUE.

- standardize_types:

  Logical. Apply standardizeDataTypes(). Defaults to TRUE.

- percent_decimal_places:

  Integer. Decimal places for percentages. Defaults to 1.

- float_decimal_places:

  Integer. Decimal places for floats. Defaults to 2.

## Value

Data frame prepared for dissemination

## Details

This function applies transformations in sequence:

1.  Clean column names to snake_case

2.  Format percentage columns

3.  Format float columns

4.  Standardize data types

Each step is optional and can be controlled individually.
