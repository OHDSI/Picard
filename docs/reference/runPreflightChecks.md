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
  ignoreUncommittedPaths = NULL,
  skipCodeStateCheck = FALSE,
  skipInputBuilders = TRUE,
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

- ignoreUncommittedPaths:

  Character vector or NULL. Repo-relative paths whose uncommitted
  changes should not fail the code-state check. When NULL (default) the
  list is read from `ignoreUncommittedPaths` in the `default:` block of
  config.yml, which itself defaults to ignoring nothing. Pass
  `character(0)` to force strict checking.

- skipCodeStateCheck:

  Logical. If TRUE, the code-state check is skipped entirely — a last
  resort. The run is still allowed, but the checklist and the run
  history record that the working tree was never verified.

- skipInputBuilders:

  Logical. If FALSE, the pipeline sources the input builder scripts,
  which create the cohort manifest, so a missing manifest is only a
  warning. If TRUE (default), a missing manifest fails.

- resultsPath:

  Character. Path to the results root folder for collision check.

- tasksFolderPath:

  Character. Path to the tasks folder.

## Value

Invisibly returns a list with `lockfileHash`, `taskFilesToRun` and
`codeState` for downstream use in
[`execute_pipeline()`](https://ohdsi.github.io/Picard/reference/execute_pipeline.md).
`codeState` is a list with `sha`, `status`, `ignoredFiles` and
`ignorePaths` and is written into `exec/logs/task_run_history.csv` so
the audit trail never claims a clean tree when the tree was not clean.
