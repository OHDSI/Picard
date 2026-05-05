# Set Output Folder for Task

Create an output folder for a specific task within the results
directory, organized by database name and pipelineVersion.

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

  A character string specifying the pipelineVersion of the analysis
  (e.g., "0.0.1", "1.0.2")

- taskName:

  The name of the task for which to create the output folder

- execPath:

  The base path for results (default is "exec/results" within the
  project)

## Value

The path to the created output folder
