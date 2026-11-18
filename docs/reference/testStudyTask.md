# Test a Single Study Task

Executes a single task in test mode using the supplied `pipelineVersion`
as its test namespace. Checks that you are not on the main branch, then
runs the task with `checkStatus = TRUE`. Useful for testing individual
task changes before running the full pipeline.

## Usage

``` r
testStudyTask(
  taskFile,
  configBlock,
  pipelineVersion = "dev",
  env = rlang::caller_env(),
  forceRerun = FALSE
)
```

## Arguments

- taskFile:

  Character. The name of the task file (base name only, no path).

- configBlock:

  Character. The name of the config block to use.

- pipelineVersion:

  Character. Test namespace for this run — drives the cohort table
  suffix, the `exec/results/` folder, and the task-history namespace.
  Defaults to `"dev"`. Normalized to lowercase snake_case; an over-long
  namespace is rejected rather than truncated. Use the same value here
  and in
  [`testStudyPipeline()`](https://ohdsi.github.io/Picard/reference/testStudyPipeline.md).

- env:

  The execution environment. Defaults to caller environment.

- forceRerun:

  Logical. If `TRUE`, runs the task even when
  [`shouldRerunTask()`](https://ohdsi.github.io/Picard/reference/shouldRerunTask.md)
  finds nothing has changed. Default: `FALSE`

## Value

Invisibly returns the task result

## Examples

``` r
if (FALSE) { # \dontrun{
# Test a task on develop branch
testStudyTask("01_generate_cohorts.R", configBlock = "myConfig")
} # }
```
