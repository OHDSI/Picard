# Read Task Run History

Reads task_run_history.csv as all-character columns. Every column is
read permissively so that history files written by older picard versions
— which lack the `commit_sha` and `code_state` provenance columns —
still load; missing columns are back-filled by
[`.ensureHistoryColumns()`](https://ohdsi.github.io/Picard/reference/dot-ensureHistoryColumns.md).

## Usage

``` r
.readTaskHistory(historyFile)
```

## Arguments

- historyFile:

  Character. Path to history file

## Value

Data frame with history records
