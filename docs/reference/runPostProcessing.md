# Run Post-Processing Pipeline with Merging and QC

Runs complete post-processing workflow: merges results across all tasks
for a specified pipeline version, generates reference files
(cohortManifestSnapshot, databaseInfo, schema_review), runs QC
validation on cohort completeness, and generates execution metadata.

## Usage

``` r
runPostProcessing(
  pipelineVersion,
  dbIds,
  resultsPath = here::here("exec/results"),
  exportPath = here::here("dissemination/export/merge"),
  cohortsFolderPath = here::here("inputs/cohorts"),
  testMode = NULL,
  compress = FALSE
)
```

## Arguments

- pipelineVersion:

  Character. Pipeline version (e.g., "1.0.0")

- dbIds:

  Character vector of database configuration IDs from config.yml

- resultsPath:

  Character. Path to results root folder. Defaults to "exec/results"

- exportPath:

  Character. Path where combined results will be saved. Defaults to
  "dissemination/export/merge"

- cohortsFolderPath:

  Character. Path to cohorts folder for the CohortManifest. Defaults to
  "inputs/cohorts". If the path exists and contains a cohort manifest,
  generates a cohortManifestSnapshot.csv reference file.

- testMode:

  Logical or NULL. When TRUE, QC checks are non-fatal (errors become
  warnings) and qcStatus is set to "DevMode". When NULL (default),
  testMode is automatically set to TRUE for non-semver pipeline versions
  (e.g. "dev", "test") and FALSE for semantic versions (e.g. "1.0.0").

- compress:

  Logical. If TRUE, merged per-task result files are written as
  gzip-compressed `.csv.gz` instead of plain `.csv` (passed through to
  [`importAndBind`](https://ohdsi.github.io/Picard/reference/importAndBind.md)).
  Reference/QC files (databaseInfo.csv, cohortManifestSnapshot.csv,
  schema_review.csv, qc\_\*.csv) are always plain `.csv` regardless of
  this setting, since only merged results tend to get large.
  [`readr::read_csv()`](https://readr.tidyverse.org/reference/read_delim.html)/`spec_csv()`
  read `.csv.gz` files transparently, so downstream code only needs to
  know a file may end in `.gz` when `compress = TRUE` was used to
  produce it. Default: FALSE.

## Value

Data frame summarizing all merged tasks with columns:

- taskName: Name of the task

- fileCount: Number of result files found for that task

- totalRows: Total rows across all result files

- filesExported: Comma-separated list of exported file names

## Details

The function runs the complete post-processing workflow:

1.  Captures git commit SHA for reproducibility tracking

2.  Snapshots environment (renv.lock) for non-dev versions

3.  Discovers tasks for the specified pipeline version

4.  Merges results across all databases for each task via
    importAndBind()

5.  Generates reference files: cohortManifestSnapshot.csv,
    databaseInfo.csv

6.  Reviews schema of exported files (schema_review.csv)

7.  Validates cohort completeness (qc_cohortValidation.csv)

8.  Generates execution metadata (qc_processMeta.csv)

Output files created in version export folder:

- Merged result CSVs (per task)

- cohortManifestSnapshot.csv: Active cohort manifest at export time (id,
  label, filePath, hash, cohortType, timestamp)

- databaseInfo.csv: Databases included in merge operation

- schema_review.csv: Column-level inspection of all files

- qc_cohortValidation.csv: Cohort completeness validation results

- qc_processMeta.csv: Execution metadata (executionTimestamp,
  pipelineVersion, codeCommitSha, lockfileHash, databasesIncluded,
  qcStatus)

Expected folder structure:

    exec/results/
      normalized_database_name1/
        version/
          task1/
            results.csv
          task2/
            results.csv
      normalized_database_name2/
        version/
          task1/
            results.csv
          task2/
            results.csv
