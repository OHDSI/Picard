# Clean Column Names to Standard Format

Standardizes column names to snake_case format, making them consistent
across datasets for easier dissemination and reporting.

## Usage

``` r
cleanColumnNames(data, to_lower = TRUE)
```

## Arguments

- data:

  Data frame or tibble to clean

- to_lower:

  Logical. Convert to lowercase. Defaults to TRUE.

## Value

Data frame with standardized column names in snake_case

## Details

Converts column names to snake_case by:

- Converting spaces to underscores

- Converting periods to underscores

- Converting CamelCase to snake_case

- Converting to lowercase (optional)
