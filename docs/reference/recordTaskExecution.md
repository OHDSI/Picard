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
  tasksFolderPath = here::here("analysis/tasks"),
  commitSha = NA_character_,
  codeState = "unrecorded",
  conceptSetManifestHash = NA_character_,
  renvLockHash = NA_character_
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

- commitSha:

  Character. HEAD commit SHA at execution time, from the pre-flight
  code-state check (optional).

- codeState:

  Character. Provenance of the working tree at execution time:
  `"clean"`, `"dirty-ignored"` (uncommitted changes were tolerated under
  configured ignore paths), `"unverified-skipped"` (the code-state check
  was skipped), `"unverified-test-mode"`, or `"unrecorded"` for calls
  outside a pipeline run. Recorded so the audit trail never implies a
  clean tree when the tree was not clean.

- conceptSetManifestHash:

  Character. Hash of concept set manifest at time of execution
  (optional)

- renvLockHash:

  Character. Hash of renv.lock at time of execution (optional)

## Value

Invisibly TRUE if successful
