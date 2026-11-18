# Set Output Folder for Task

Create an output folder for a specific task within the results
directory, organized by database name and pipeline version.

The pipeline-version path segment is derived through
[ExecutionContext](https://ohdsi.github.io/Picard/reference/ExecutionContext.md)
so it always matches the cohort-table suffix produced by
[`createExecutionSettingsFromConfig()`](https://ohdsi.github.io/Picard/reference/createExecutionSettingsFromConfig.md):
a non-semver (test) `pipelineVersion` such as `"develop_ml"` is
normalized to lowercase snake_case, and a semantic version such as
`"1.0.2"` is used unchanged.

## Usage

``` r
setOutputFolder(
  executionSettings,
  pipelineVersion,
  taskName,
  execPath = here::here("exec/results")
)
```

## Arguments

- executionSettings:

  An ExecutionSettings object containing the databaseName attribute

- pipelineVersion:

  A character string specifying the pipeline version of the analysis: a
  test namespace (e.g. `"develop_ml"`) or a semantic version (e.g.
  `"1.0.2"`).

- taskName:

  The name of the task for which to create the output folder

- execPath:

  The base path for results (default is "exec/results" within the
  project)

## Value

The path to the created output folder
