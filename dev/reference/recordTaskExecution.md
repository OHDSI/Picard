# Record Task Execution Status

Updates the task_run_history.csv file with execution results.

## Usage

``` r
recordTaskExecution(
  taskFile,
  configBlock,
  pipelineVersion,
  status,
  cohortManifestHash = NA_character_,
  errorMessage = NA_character_,
  tasksFolderPath = here::here("analysis/tasks")
)
```

## Arguments

- taskFile:

  Character. Name of the task file

- configBlock:

  Character. Config block name

- pipelineVersion:

  Character. Pipeline version

- status:

  Character. Execution status ("success", "failed", "skipped")

- cohortManifestHash:

  Character. Hash of cohort manifest at time of execution (optional)

- errorMessage:

  Character. Error message if status is "failed" (optional)

- tasksFolderPath:

  Character. Path to tasks folder (optional)

## Value

Invisibly TRUE if successful
