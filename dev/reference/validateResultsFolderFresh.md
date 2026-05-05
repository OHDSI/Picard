# Validate Results Folder is Fresh

Checks that the versioned results folder does not already contain output
files. An existing but empty folder is allowed; a folder with files
indicates a version collision and will block execution.

## Usage

``` r
validateResultsFolderFresh(
  pipelineVersion,
  resultsPath = here::here("exec/results")
)
```

## Arguments

- pipelineVersion:

  Character. The pipeline version string (e.g., "1.2.3").

- resultsPath:

  Character. Path to the results root folder. Defaults to "exec/results"
  relative to the project root.

## Value

Logical TRUE invisibly if check passes. Stops with error if collision
detected.
