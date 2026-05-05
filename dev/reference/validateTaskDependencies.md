# Validate Task File Dependencies

Scans all task files in the tasks folder for static `source("...")`
calls and checks that each referenced path exists on disk. Only plain
string arguments are detected; dynamic
[`source()`](https://rdrr.io/r/base/source.html) calls are not
evaluated.

## Usage

``` r
validateTaskDependencies(tasksFolderPath = here::here("analysis/tasks"))
```

## Arguments

- tasksFolderPath:

  Character. Path to the analysis/tasks folder. Defaults to
  "analysis/tasks" relative to the project root.

## Value

Invisibly returns a list with `missing` (character vector of missing
paths) and `total` (integer count of all source paths found).
