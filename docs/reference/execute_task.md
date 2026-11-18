# Function to execute a study task in Ulysses

Function to execute a study task in Ulysses

## Usage

``` r
execute_task(
  taskFile,
  configBlock,
  pipelineVersion = "dev",
  checkStatus = FALSE,
  env = rlang::caller_env(),
  codeState = NULL,
  logFilePath = NULL,
  cohortManifestHash = NULL,
  conceptSetManifestHash = NULL,
  renvLockHash = NULL,
  executionContext = NULL
)
```

## Arguments

- taskFile:

  the name of the taskFile. Only use the base name

- configBlock:

  the name of the configBlock to use in the execution

- pipelineVersion:

  the version of the pipeline to use in the execution. This is used to
  set the output folder for the task results. the default is "dev" which
  will place results in a dev folder. This allows users to run and test
  tasks without impacting the main results folders organized by pipeline
  version.

- checkStatus:

  Logical. If TRUE, checks if task needs to be rerun based on file
  changes, dependencies, cohort changes, and previous errors.
  Automatically builds execution settings from configBlock. Default:
  FALSE

- env:

  the execution environment

- codeState:

  List or NULL. Working-tree provenance from
  [`runPreflightChecks()`](https://ohdsi.github.io/Picard/reference/runPreflightChecks.md)
  (`sha` and `status`). Recorded in `exec/logs/task_run_history.csv`
  alongside each run. NULL — the default, used when a task is run
  outside the pipeline — records the code state as `"unrecorded"` rather
  than implying a clean tree.

- logFilePath:

  Character or NULL. Path to the pipeline log file for recording
  high-level milestones and full error detail. NULL (default) when run
  outside a pipeline (e.g. via
  [`testStudyTask()`](https://ohdsi.github.io/Picard/reference/testStudyTask.md))
  — no file is written.

- cohortManifestHash:

  Character or NULL. Pre-computed cohort manifest hash (see
  [`.getCohortManifestHash()`](https://ohdsi.github.io/Picard/reference/dot-getCohortManifestHash.md)).
  NULL (default) computes it once here;
  [`execute_pipeline()`](https://ohdsi.github.io/Picard/reference/execute_pipeline.md)
  computes it once and passes it in so the manifest is not re-loaded for
  every task. Recorded with the run and used for the rerun check.

- conceptSetManifestHash:

  Character or NULL. Pre-computed concept set manifest hash (see
  [`.getConceptSetManifestHash()`](https://ohdsi.github.io/Picard/reference/dot-getConceptSetManifestHash.md)).
  Handled the same way as `cohortManifestHash`.

- renvLockHash:

  Character or NULL. Pre-computed renv lockfile hash (see
  [`.getRenvLockHash()`](https://ohdsi.github.io/Picard/reference/dot-getRenvLockHash.md)).
  Handled the same way as `cohortManifestHash`.

- executionContext:

  An optional `ExecutionContext` for the current run. When supplied it
  owns namespace derivation (cohort-table suffix, results folder) and
  `pipelineVersion` is taken from it.
