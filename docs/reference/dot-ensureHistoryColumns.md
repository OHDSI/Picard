# Back-fill Task History Columns

Adds any columns missing from a history data frame and orders them to
match
[`.createEmptyHistory()`](https://ohdsi.github.io/Picard/reference/dot-createEmptyHistory.md).
Rows written before the provenance columns existed are marked
`"unrecorded"` rather than `"clean"`, so an old row is never mistaken
for a verified-clean run.

## Usage

``` r
.ensureHistoryColumns(historyDf)
```

## Arguments

- historyDf:

  Data frame of history records

## Value

Data frame with the full column set
