# Format Float Columns

Rounds and formats numeric columns to a consistent number of decimal
places, removing trailing zeros for cleaner display.

## Usage

``` r
formatFloats(
  data,
  float_cols = NULL,
  decimal_places = 2,
  remove_trailing_zeros = TRUE
)
```

## Arguments

- data:

  Data frame or tibble

- float_cols:

  Character vector of column names to format. If NULL, formats all
  numeric columns except integers.

- decimal_places:

  Integer. Number of decimal places. Defaults to 2.

- remove_trailing_zeros:

  Logical. Remove trailing zeros. Defaults to TRUE.

## Value

Data frame with formatted float columns
