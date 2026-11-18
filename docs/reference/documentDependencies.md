# Document Dependencies

Generates human-readable dependency report. Useful for manuscripts,
methods sections, or audit trails.

## Usage

``` r
documentDependencies(outputPath = NULL)
```

## Arguments

- outputPath:

  Character. Optional path to save report as CSV. If NULL, returns
  tibble silently.

## Value

Tibble with columns: package, version, type(direct/indirect)

## Details

Returns data frame with:

- package: Package name

- version: Installed version

- source: CRAN / GitHub / local
