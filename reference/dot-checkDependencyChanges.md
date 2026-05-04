# Check for Dependency File Changes

Extracts source() calls from task file and checks if dependencies
changed.

## Usage

``` r
.checkDependencyChanges(taskFile, lastRunInfo)
```

## Arguments

- taskFile:

  Character. Path to task file

- lastRunInfo:

  Data frame row. Previous run record

## Value

Character vector of changed dependency files
