# Import and Bind Results by Version and Task

Combines result files across multiple database runs for a specific
version and task. Finds all CSV files in the task folder for each
database and combines them into named results, then saves them to the
export folder.

## Usage

``` r
importAndBind(
  version,
  taskName,
  dbIds,
  resultsPath = here::here("exec/results"),
  exportPath = here::here("dissemination/export/merge"),
  compress = FALSE
)
```

## Arguments

- version:

  Character. Pipeline version (e.g., "1.0.0")

- taskName:

  Character. Name of the task (e.g., "cohortCounts", "characterization")

- dbIds:

  Character vector of database configuration IDs from config.yml

- resultsPath:

  Character. Path to results root folder. Defaults to "exec/results"

- exportPath:

  Character. Path where combined results will be saved. Defaults to
  "dissemination/export/merge"

- compress:

  Logical. If TRUE, writes merged files as gzip-compressed CSV
  (`.csv.gz`) instead of plain `.csv`. Merged results can get large once
  every database's rows for a task are combined;
  [`readr::write_csv()`](https://readr.tidyverse.org/reference/write_delim.html)
  gzips automatically when the filename ends in `.csv.gz`, and
  [`readr::read_csv()`](https://readr.tidyverse.org/reference/read_delim.html)
  (and `spec_csv()`) decompress `.gz` files transparently on read — no
  special handling needed to consume them. Reference/QC files written by
  [`runPostProcessing`](https://ohdsi.github.io/Picard/reference/runPostProcessing.md)
  (databaseInfo.csv, schema_review.csv, etc.) are always plain `.csv`,
  since only the merged per-task results tend to be large. Default:
  FALSE.

## Value

Invisibly returns data frame of export summary with columns: fileName,
rowCount, databaseCount

## Details

Folder structure expected:

    exec/results/
      normalized_database_name1/
        version/
          taskName/
            file1.csv
            file2.csv
      normalized_database_name2/
        version/
          taskName/
            file1.csv
            file2.csv

All files with the same name from each database are combined with
databaseId added and saved to exportPath. Exported filenames are
prefixed with the task sequence from `taskName` (e.g., `01_results.csv`)
to avoid collisions across tasks.
