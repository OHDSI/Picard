# Test a Single Study Task

Executes a single task in test mode using the "dev" pipeline version.
Checks that you're not on main branch, then runs the task with
checkStatus = TRUE. Useful for testing individual task changes before
running full pipeline.

## Usage

``` r
testStudyTask(taskFile, configBlock, env = rlang::caller_env())
```

## Arguments

- taskFile:

  Character. The name of the task file (base name only, no path).

- configBlock:

  Character. The name of the config block to use.

- env:

  The execution environment. Defaults to caller environment.

## Value

Invisibly returns the task result

## Examples

``` r
if (FALSE) { # \dontrun{
# Test a task on develop branch
testStudyTask("01_generate_cohorts.R", configBlock = "myConfig")
} # }
```
