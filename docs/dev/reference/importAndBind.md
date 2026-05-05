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
  exportPath = here::here("dissemination/export/merge")
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

## Value

Invisibly returns data frame of export summary with columns: fileName,
rowCount, databaseCount

## Details

Folder structure expected:

    exec/results/
      databaseName1/
        version/
          taskName/
            file1.csv
            file2.csv
      databaseName2/
        version/
          taskName/
            file1.csv
            file2.csv

All files with the same name from each database are combined with
databaseId added and saved to exportPath.
