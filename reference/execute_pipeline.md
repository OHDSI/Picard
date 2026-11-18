# Core Pipeline Execution Logic

Internal function containing all pipeline execution logic. Called by
both testStudyPipeline and execStudyPipeline with different parameters.

## Usage

``` r
execute_pipeline(
  configBlock,
  updateType = NULL,
  testMode = FALSE,
  skipRenv = FALSE,
  skipConnectivityCheck = TRUE,
  ignoreUncommittedPaths = NULL,
  skipCodeStateCheck = FALSE,
  env = rlang::caller_env(),
  pipelineVersionOverride = NULL,
  forceRerun = FALSE,
  skipInputBuilders = TRUE
)
```

## Arguments

- configBlock:

  name of one or multiple configBlock to use in the execution

- updateType:

  the type of version increment: 'major', 'minor', or 'patch'. Only used
  when testMode = FALSE.

- testMode:

  Logical. If TRUE, uses test namespace/version handling and skips
  production version management. Public test entry points still apply
  the main-branch guard. If FALSE, enforces production version
  management. Default: FALSE

- skipRenv:

  Logical. If TRUE, skips renv validation. Default: FALSE

- skipConnectivityCheck:

  Logical. If TRUE (default), skips the optional database connectivity
  pre-flight check. Set to FALSE to attempt a test connection to each
  config block before execution begins.

- ignoreUncommittedPaths:

  Character vector or NULL. Repo-relative paths whose uncommitted
  changes do not fail the code-state check. NULL (default) reads the
  list from config.yml, which itself defaults to ignoring nothing.

- skipCodeStateCheck:

  Logical. If TRUE, skips the code-state check entirely. Default: FALSE

- env:

  the execution environment

- pipelineVersionOverride:

  Character. Optional test-mode override for the pipeline version (the
  test namespace). Drives the cohort-table suffix, the results folder,
  and the task-history namespace via the run's `ExecutionContext`.

- forceRerun:

  Logical or character. `TRUE` reruns every task, bypassing change
  detection
  ([`shouldRerunTask()`](https://ohdsi.github.io/Picard/reference/shouldRerunTask.md));
  a character vector of task file names (e.g.
  `"05_baseline_medicines.R"`) reruns only those. Forced runs are still
  recorded in `exec/logs/task_run_history.csv`. Default: `FALSE`

- skipInputBuilders:

  Logical. If TRUE (default), the input builder scripts are not sourced;
  call
  [`sourceInputBuilderScripts()`](https://ohdsi.github.io/Picard/reference/sourceInputBuilderScripts.md)
  before the pipeline instead. If FALSE, they are sourced for each
  config block before that block's cohorts are generated.

## Value

Invisibly returns task results list
