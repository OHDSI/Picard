# Run Pre-flight Checks

Runs all pre-execution validation checks and displays a consolidated
pass/warn/fail/skip checklist before the pipeline starts. All checks are
run regardless of individual outcomes; the pipeline stops only after the
full checklist has been displayed — replacing the previous pattern of
scattered inline validators that stopped on first failure.

## Usage

``` r
runPreflightChecks(
  configBlock,
  pipelineVersion,
  testMode = FALSE,
  skipRenv = FALSE,
  skipConnectivityCheck = TRUE,
  resultsPath = here::here("exec/results"),
  tasksFolderPath = here::here("analysis/tasks")
)
```

## Arguments

- configBlock:

  Character vector. Config block names.

- pipelineVersion:

  Character. The prospective pipeline version string.

- testMode:

  Logical. If TRUE, code-state, renv, results-folder, connectivity, and
  branch-sync checks are skipped.

- skipRenv:

  Logical. If TRUE, renv environment check is skipped.

- skipConnectivityCheck:

  Logical. If TRUE (default), database connectivity check is skipped.

- resultsPath:

  Character. Path to the results root folder for collision check.

- tasksFolderPath:

  Character. Path to the tasks folder.

## Value

Invisibly returns a list with `lockfileHash` and `taskFilesToRun` for
downstream use in
[`execute_pipeline()`](https://ohdsi.github.io/Picard/dev/reference/execute_pipeline.md).
