# Standardize Data Types

Standardizes data types across columns based on common patterns (e.g.,
columns ending in "\_id" become integers, columns with "date" become
dates).

## Usage

``` r
standardizeDataTypes(data, type_rules = NULL)
```

## Arguments

- data:

  Data frame or tibble

- type_rules:

  List of named character vectors defining type conversion rules. If
  NULL, applies default heuristics.

## Value

Data frame with standardized data types

## Details

Default type conversions:

- Columns named "\*\_id": convert to integer

- Columns named "\*\_date": convert to date (ISO format assumed)

- Columns named "\*\_count": convert to integer

- Columns containing "flag" or "indicator": convert to logical
