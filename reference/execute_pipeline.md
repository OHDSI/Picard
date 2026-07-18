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
  env = rlang::caller_env(),
  pipelineVersionOverride = NULL,
  cohortTableSuffix = NULL
)
```

## Arguments

- configBlock:

  name of one or multiple configBlock to use in the execution

- updateType:

  the type of version increment: 'major', 'minor', or 'patch'. Only used
  when testMode = FALSE.

- testMode:

  Logical. If TRUE, skips all validations and uses "dev" version. If
  FALSE, enforces code validation and version management. Default: FALSE

- skipRenv:

  Logical. If TRUE, skips renv validation. Default: FALSE

- skipConnectivityCheck:

  Logical. If TRUE (default), skips the optional database connectivity
  pre-flight check. Set to FALSE to attempt a test connection to each
  config block before execution begins.

- env:

  the execution environment

- pipelineVersionOverride:

  Character. Optional test-mode override for the pipeline version folder
  label.

- cohortTableSuffix:

  Character. Optional test-mode suffix used for cohort table names.

## Value

Invisibly returns task results list
