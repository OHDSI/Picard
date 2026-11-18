# Function to execute a study task in Ulysses

Function to execute a study task in Ulysses

## Usage

``` r
execStudyTask(
  taskFile,
  configBlock,
  pipelineVersion = "dev",
  checkStatus = FALSE,
  env = rlang::caller_env()
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
