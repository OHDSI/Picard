# Format Percentage Columns

Formats percentage columns to a consistent decimal places with optional
percent symbol. Useful for preparing results for publication.

## Usage

``` r
formatPercentages(
  data,
  percent_cols = NULL,
  decimal_places = 1,
  add_symbol = TRUE
)
```

## Arguments

- data:

  Data frame or tibble

- percent_cols:

  Character vector of column names to format as percentages. If NULL,
  attempts to detect columns with "percent", "pct", or "prop" in name.

- decimal_places:

  Integer. Number of decimal places. Defaults to 1.

- add_symbol:

  Logical. Add "%" symbol to values. Defaults to TRUE.

## Value

Data frame with formatted percentage columns (as character)

## Details

This function:

- Multiplies values by 100 if they are between 0 and 1 (proportions)

- Rounds to specified decimal places

- Optionally adds a percent symbol

- Converts to character for consistent display
